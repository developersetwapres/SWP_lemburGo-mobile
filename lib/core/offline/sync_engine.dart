import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../features/overtime/data/remote_overtime_api.dart';
import '../api/api_exception.dart';
import 'local_overtime_store.dart';
import 'sync_models.dart';
import 'sync_status.dart';

typedef UnauthenticatedHandler = Future<void> Function();

/// Serialises durable mutations and refreshes local snapshots only after queued
/// writes have settled. A second call while work is in progress coalesces with
/// the existing run instead of submitting the same operation twice.
class SyncEngine {
  factory SyncEngine({
    required LocalOvertimeStore localStore,
    required OvertimeRemoteGateway remoteApi,
    required SyncStatus status,
    required UnauthenticatedHandler onUnauthenticated,
    Connectivity? connectivity,
    Future<List<ConnectivityResult>> Function()? connectivityCheck,
    Stream<List<ConnectivityResult>>? connectivityChanges,
  }) => SyncEngine._(
    localStore,
    remoteApi,
    status,
    onUnauthenticated,
    connectivity: connectivity,
    connectivityCheck: connectivityCheck,
    connectivityChanges: connectivityChanges,
  );

  SyncEngine._(
    this._localStore,
    this._remoteApi,
    this._status,
    this._onUnauthenticated, {
    Connectivity? connectivity,
    Future<List<ConnectivityResult>> Function()? connectivityCheck,
    Stream<List<ConnectivityResult>>? connectivityChanges,
  }) {
    final source = connectivity ?? Connectivity();
    _connectivityCheck = connectivityCheck ?? source.checkConnectivity;
    _connectivityChanges = connectivityChanges ?? source.onConnectivityChanged;
  }

  final LocalOvertimeStore _localStore;
  final OvertimeRemoteGateway _remoteApi;
  final SyncStatus _status;
  final UnauthenticatedHandler _onUnauthenticated;
  late final Future<List<ConnectivityResult>> Function() _connectivityCheck;
  late final Stream<List<ConnectivityResult>> _connectivityChanges;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _retryTimer;
  String? _ownerId;
  Future<void>? _activeRun;
  bool _followUpRequested = false;
  bool _followUpRefresh = false;
  int? _followUpHistoryMonth;
  bool _disposed = false;

  Future<void> activate(String ownerId) async {
    _ownerId = ownerId;
    await _localStore.recoverInterruptedOperations(ownerId);
    await _updatePendingCount();
    try {
      final connectivity = await _connectivityCheck();
      _status.update(hasNetworkTransport: _hasTransport(connectivity));
    } catch (_) {
      _status.update(hasNetworkTransport: false, apiReachable: false);
    }
    _connectivitySubscription ??= _connectivityChanges.listen((result) {
      final hasTransport = _hasTransport(result);
      _status.update(hasNetworkTransport: hasTransport);
      if (hasTransport) unawaited(syncNow(includeRemoteRefresh: true));
    });
    await _scheduleRetry();
    unawaited(syncNow(includeRemoteRefresh: true));
  }

  Future<void> deactivate() async {
    _ownerId = null;
    _followUpRequested = false;
    _followUpRefresh = false;
    _followUpHistoryMonth = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _status.update(
      isSyncing: false,
      pendingCount: 0,
      apiReachable: false,
      clearError: true,
    );
  }

  Future<void> syncNow({bool includeRemoteRefresh = false, int? historyMonth}) {
    final active = _activeRun;
    if (active != null) {
      // Calls made while a previous owner/run is still winding down must not
      // disappear. This is especially important for logout → login on the
      // same device and rapid pull-to-refresh gestures.
      _followUpRequested = true;
      _followUpRefresh = _followUpRefresh || includeRemoteRefresh;
      _followUpHistoryMonth ??= historyMonth;
      return active;
    }
    return _startRun(
      includeRemoteRefresh: includeRemoteRefresh,
      historyMonth: historyMonth,
    );
  }

  Future<void> _startRun({
    required bool includeRemoteRefresh,
    required int? historyMonth,
  }) {
    final run = _sync(
      includeRemoteRefresh: includeRemoteRefresh,
      historyMonth: historyMonth,
    );
    _activeRun = run;
    unawaited(
      run.then<void>((_) => _finishRun(run), onError: (_) => _finishRun(run)),
    );
    return run;
  }

  void _finishRun(Future<void> completedRun) {
    if (!identical(_activeRun, completedRun)) return;
    _activeRun = null;
    if (!_followUpRequested || _disposed || _ownerId == null) return;
    final refresh = _followUpRefresh;
    final historyMonth = _followUpHistoryMonth;
    _followUpRequested = false;
    _followUpRefresh = false;
    _followUpHistoryMonth = null;
    unawaited(
      syncNow(includeRemoteRefresh: refresh, historyMonth: historyMonth),
    );
  }

  Future<void> _sync({
    required bool includeRemoteRefresh,
    required int? historyMonth,
  }) async {
    final ownerId = _ownerId;
    if (ownerId == null || _disposed) return;
    try {
      final connectivity = await _connectivityCheck();
      if (!_hasTransport(connectivity)) {
        _status.update(hasNetworkTransport: false, apiReachable: false);
        return;
      }
      _status.update(hasNetworkTransport: true, isSyncing: true);
      var blockedByAuthentication = false;
      while (!_disposed && _ownerId == ownerId) {
        final operations = await _localStore.readyOperations(ownerId);
        if (operations.isEmpty) break;
        final operation = operations.first;
        final outcome = await _syncOperation(operation);
        await _updatePendingCount();
        if (outcome == _SyncOutcome.unauthenticated) {
          blockedByAuthentication = true;
          break;
        }
        // A transport/server failure has scheduled a delayed retry. Do not
        // repeatedly hammer the internal API in a tight loop.
        if (outcome == _SyncOutcome.retryLater) break;
      }
      if (!blockedByAuthentication &&
          includeRemoteRefresh &&
          _ownerId == ownerId) {
        await _refreshSnapshots(ownerId, historyMonth: historyMonth);
      }
    } catch (_) {
      // Connectivity is only a hint and its platform call may itself fail.
      // Treat that exactly like an unreachable API; pending local work stays
      // durable and a persisted backoff/timer will retry it later.
      _status.update(
        hasNetworkTransport: false,
        apiReachable: false,
        lastError:
            'Sinkronisasi belum dapat dilakukan. Data tetap aman di perangkat.',
      );
    } finally {
      await _updatePendingCount();
      await _scheduleRetry();
      _status.update(isSyncing: false);
    }
  }

  Future<_SyncOutcome> _syncOperation(PendingSyncOperation operation) async {
    final record = await _localStore.byLocalId(
      operation.ownerId,
      operation.localId,
    );
    if (record == null) {
      await _localStore.markOperationSucceeded(operation);
      return _SyncOutcome.success;
    }
    await _localStore.markSyncing(operation);
    try {
      switch (operation.type) {
        case SyncOperationType.create:
          final created = await _remoteApi.create(record);
          await _localStore.markOperationSucceeded(
            operation,
            createdServerRecord: created,
          );
        case SyncOperationType.update:
          await _remoteApi.update(record);
          await _localStore.markOperationSucceeded(operation);
        case SyncOperationType.delete:
          if (record.uuid.trim().isNotEmpty) {
            await _remoteApi.delete(record.uuid);
          }
          await _localStore.markOperationSucceeded(operation);
      }
      _status.update(
        apiReachable: true,
        clearError: true,
        lastSuccessfulSyncAt: DateTime.now(),
      );
      return _SyncOutcome.success;
    } on MissingCreateIdentityException catch (error) {
      await _localStore.failOperation(
        operation,
        message: error.toString(),
        // Retrying a POST whose server result did not include a UUID is not
        // safe until Laravel implements the idempotency contract. Keep the
        // original request durable but never submit it again automatically.
        state: SyncOperationState.blockedIdentity,
      );
      _status.update(lastError: error.toString());
      return _SyncOutcome.blocked;
    } on ApiException catch (error) {
      if (error.isUnauthenticated) {
        await _localStore.failOperation(
          operation,
          message: error.message,
          state: SyncOperationState.awaitingAuthentication,
        );
        _status.update(apiReachable: true, lastError: error.message);
        await _onUnauthenticated();
        return _SyncOutcome.unauthenticated;
      }
      final isValidationOrConflict =
          error.statusCode == 422 || error.statusCode == 409;
      await _localStore.failOperation(
        operation,
        message: error.message,
        state: isValidationOrConflict
            ? SyncOperationState.blockedValidation
            : SyncOperationState.retryWaiting,
      );
      _status.update(
        apiReachable: error.statusCode != null,
        lastError: error.message,
      );
      return isValidationOrConflict
          ? _SyncOutcome.blocked
          : _SyncOutcome.retryLater;
    } on StateError catch (error) {
      await _localStore.failOperation(
        operation,
        message: error.message,
        state: SyncOperationState.blockedValidation,
      );
      _status.update(lastError: error.message);
      return _SyncOutcome.blocked;
    } catch (_) {
      const message =
          'Sinkronisasi belum dapat dilakukan. Data tetap aman di perangkat.';
      await _localStore.failOperation(
        operation,
        message: message,
        state: SyncOperationState.retryWaiting,
      );
      _status.update(apiReachable: false, lastError: message);
      return _SyncOutcome.retryLater;
    }
  }

  Future<void> _refreshSnapshots(String ownerId, {int? historyMonth}) async {
    try {
      final drafts = await _remoteApi.fetchDrafts();
      await _localStore.upsertRemoteRecords(
        ownerId: ownerId,
        records: drafts,
        replaceDraftSnapshot: true,
      );
      final month = historyMonth ?? DateTime.now().month;
      final history = await _remoteApi.fetchHistory(month: month);
      await _localStore.upsertRemoteRecords(
        ownerId: ownerId,
        records: history.records,
      );
      await _localStore.saveMonthlySummary(ownerId: ownerId, history: history);
      final calendar = await _remoteApi.fetchCalendarEntries();
      await _localStore.replaceCalendarEntries(
        ownerId: ownerId,
        entries: calendar,
      );
      final year = await _remoteApi.fetchYearOvertimeSummary();
      await _localStore.saveYearSummary(ownerId: ownerId, summary: year);
      // A successful snapshot refresh does not mean that an earlier queued
      // mutation succeeded. Keep its error visible until that queue is empty.
      final pendingCount = await _localStore.pendingOperationCount(ownerId);
      _status.update(
        apiReachable: true,
        clearError: pendingCount == 0,
        lastSuccessfulSyncAt: DateTime.now(),
      );
    } on ApiException catch (error) {
      if (error.isUnauthenticated) {
        _status.update(apiReachable: true, lastError: error.message);
        await _onUnauthenticated();
      } else {
        _status.update(
          apiReachable: error.statusCode != null,
          lastError: error.message,
        );
      }
    } catch (_) {
      _status.update(apiReachable: false);
    }
  }

  Future<void> retryBlocked() async {
    final ownerId = _ownerId;
    if (ownerId == null) return;
    await _localStore.reactivateBlockedOperations(ownerId);
    await _updatePendingCount();
    await syncNow(includeRemoteRefresh: true);
  }

  Future<void> _updatePendingCount() async {
    final ownerId = _ownerId;
    if (ownerId == null) return;
    _status.update(
      pendingCount: await _localStore.pendingOperationCount(ownerId),
    );
  }

  Future<void> _scheduleRetry() async {
    final ownerId = _ownerId;
    _retryTimer?.cancel();
    _retryTimer = null;
    if (ownerId == null || _disposed || !_status.hasNetworkTransport) return;
    final dueAt = await _localStore.nextRetryAt(ownerId);
    // The owner can change while SQLite is being queried.
    if (_ownerId != ownerId || _disposed || dueAt == null) return;
    final delay = dueAt.difference(DateTime.now());
    _retryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (_ownerId == ownerId && !_disposed) {
        unawaited(syncNow(includeRemoteRefresh: true));
      }
    });
  }

  bool _hasTransport(List<ConnectivityResult> results) =>
      results.isNotEmpty && !results.contains(ConnectivityResult.none);

  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    await _connectivitySubscription?.cancel();
  }
}

enum _SyncOutcome { success, retryLater, blocked, unauthenticated }
