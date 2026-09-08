import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/offline/local_overtime_store.dart';
import '../../../core/offline/local_photo_store.dart';
import '../../../core/offline/offline_database.dart';
import '../../../core/offline/sync_engine.dart';
import '../../../core/offline/sync_status.dart';
import '../../calendar/data/models/calendar_overtime.dart';
import '../../history/data/models/overtime_history.dart';
import 'models/draft_overtime.dart';
import 'models/photo_stamp.dart';
import 'models/year_overtime_summary.dart';
import 'remote_overtime_api.dart';

/// Local-first facade used by every screen. Reads always come from SQLite and
/// writes commit locally before the sync engine is asked to contact Laravel.
class OvertimeRepository extends ChangeNotifier {
  OvertimeRepository._(this._localStore, this._photoStore, this._remoteApi) {
    _syncEngine = SyncEngine(
      localStore: _localStore,
      remoteApi: _remoteApi,
      status: syncStatus,
      onUnauthenticated: _handleUnauthenticated,
    );
    syncStatus.addListener(notifyListeners);
  }

  static Future<OvertimeRepository> create(Dio dio, ApiClient apiClient) async {
    final database = await OfflineDatabase.open();
    return OvertimeRepository._(
      LocalOvertimeStore(database),
      LocalPhotoStore(),
      RemoteOvertimeApi(dio, apiClient),
    );
  }

  final LocalOvertimeStore _localStore;
  final LocalPhotoStore _photoStore;
  final OvertimeRemoteGateway _remoteApi;
  final SyncStatus syncStatus = SyncStatus();
  late final SyncEngine _syncEngine;

  String? _ownerId;
  Future<void> Function()? _sessionExpiredHandler;

  void setSessionExpiredHandler(Future<void> Function() handler) {
    _sessionExpiredHandler = handler;
  }

  Future<void> activateUser(String ownerId) async {
    if (_ownerId == ownerId) return;
    _ownerId = ownerId;
    await _syncEngine.activate(ownerId);
    notifyListeners();
  }

  Future<void> deactivateUser() async {
    _ownerId = null;
    await _syncEngine.deactivate();
    notifyListeners();
  }

  Future<void> _handleUnauthenticated() async {
    // Local rows remain owner-scoped and untouched. The app returns to login,
    // then the same user can continue syncing after authenticating again.
    await _sessionExpiredHandler?.call();
  }

  Future<List<DraftOvertime>> fetchDrafts() =>
      _localStore.drafts(_requireOwner());

  Future<DraftOvertime> fetchDetail(String uuid) async {
    final ownerId = _requireOwner();
    final local = await _localStore.byServerUuid(ownerId, uuid);
    if (local != null) return local;
    // A calendar snapshot can know a UUID before its full detail has ever been
    // read. Fetching it is an online enhancement; normal UI reads are local.
    final remote = await _remoteApi.fetchDetail(uuid);
    await _localStore.upsertRemoteRecords(ownerId: ownerId, records: [remote]);
    notifyListeners();
    return (await _localStore.byServerUuid(ownerId, uuid)) ?? remote;
  }

  Future<DraftOvertime?> fetchLocalDetail(String localId) =>
      _localStore.byLocalId(_requireOwner(), localId);

  /// A list item already carries a durable local ID, including records that
  /// have not received a Laravel UUID yet. Detail navigation must use it
  /// first; otherwise an offline-created draft would incorrectly request
  /// `/lemburs/detail/` with an empty UUID.
  Future<DraftOvertime> fetchRecordDetail(DraftOvertime record) async {
    final localId = record.localId;
    if (localId?.isNotEmpty == true) {
      final local = await fetchLocalDetail(localId!);
      if (local != null) return local;
    }
    if (record.uuid.trim().isEmpty) {
      throw StateError('Detail laporan lokal tidak ditemukan.');
    }
    return fetchDetail(record.uuid);
  }

  Future<OvertimeHistory> fetchHistory({int? month}) =>
      _localStore.history(_requireOwner(), month ?? DateTime.now().month);

  Future<List<CalendarOvertime>> fetchCalendarEntries() =>
      _localStore.calendar(_requireOwner());

  Future<YearOvertimeSummary> fetchYearOvertimeSummary() =>
      _localStore.yearSummary(_requireOwner());

  /// Requests the server-generated PDF. The server enforces both the logged-in
  /// user scope and the requirement that records are complete with both photos.
  Future<OvertimePdfExport> exportPdf({required String month}) {
    _requireOwner();
    return _remoteApi.exportPdf(month: month);
  }

  /// Begins a best-effort remote pass. It never rolls back local changes when
  /// Laravel cannot be reached.
  Future<void> syncNow({int? historyMonth, bool refreshSnapshots = true}) =>
      _syncEngine.syncNow(
        historyMonth: historyMonth,
        includeRemoteRefresh: refreshSnapshots,
      );

  Future<void> retryBlockedSync() => _syncEngine.retryBlocked();

  Future<String> submit({
    required DateTime date,
    required String activityName,
    required String location,
    StampedPhoto? activityPhoto,
    StampedPhoto? checkoutPhoto,
  }) async {
    final ownerId = _requireOwner();
    final localId = _localStore.newIdentifier();
    String? activityPath;
    String? checkoutPath;
    try {
      activityPath = await _persistPhoto(
        ownerId: ownerId,
        localId: localId,
        slot: 'activity',
        photo: activityPhoto,
      );
      checkoutPath = await _persistPhoto(
        ownerId: ownerId,
        localId: localId,
        slot: 'checkout',
        photo: checkoutPhoto,
      );
      await _localStore.createLocal(
        ownerId: ownerId,
        localId: localId,
        clientRequestId: _localStore.newIdentifier(),
        date: date,
        activityName: activityName,
        location: location,
        activityPhotoPath: activityPath,
        activityPhotoAt: activityPhoto?.timestamp,
        checkoutPhotoPath: checkoutPath,
        checkoutPhotoAt: checkoutPhoto?.timestamp,
      );
    } catch (_) {
      await _photoStore.discard(activityPath);
      await _photoStore.discard(checkoutPath);
      rethrow;
    }
    notifyListeners();
    unawaited(syncNow());
    return 'Lembur tersimpan di perangkat dan akan disinkronkan otomatis.';
  }

  Future<String> update({
    required DraftOvertime draft,
    required DateTime date,
    required String activityName,
    required String location,
    StampedPhoto? newActivityPhoto,
    StampedPhoto? newCheckoutPhoto,
  }) async {
    final ownerId = _requireOwner();
    final localId =
        draft.localId ??
        (await _localStore.byServerUuid(ownerId, draft.uuid))?.localId;
    if (localId == null) throw StateError('Laporan lokal tidak ditemukan.');
    String? activityPath;
    String? checkoutPath;
    try {
      activityPath = await _persistPhoto(
        ownerId: ownerId,
        localId: localId,
        slot: 'activity',
        photo: newActivityPhoto,
      );
      checkoutPath = await _persistPhoto(
        ownerId: ownerId,
        localId: localId,
        slot: 'checkout',
        photo: newCheckoutPhoto,
      );
      await _localStore.updateLocal(
        ownerId: ownerId,
        current: draft,
        date: date,
        activityName: activityName,
        location: location,
        newActivityPhotoPath: activityPath,
        newActivityPhotoAt: newActivityPhoto?.timestamp,
        newCheckoutPhotoPath: checkoutPath,
        newCheckoutPhotoAt: newCheckoutPhoto?.timestamp,
      );
    } catch (_) {
      await _photoStore.discard(activityPath);
      await _photoStore.discard(checkoutPath);
      rethrow;
    }
    if (activityPath != null && activityPath != draft.activityPhotoLocalPath) {
      await _photoStore.discard(draft.activityPhotoLocalPath);
    }
    if (checkoutPath != null && checkoutPath != draft.checkoutPhotoLocalPath) {
      await _photoStore.discard(draft.checkoutPhotoLocalPath);
    }
    notifyListeners();
    unawaited(syncNow());
    return 'Perubahan tersimpan di perangkat dan akan disinkronkan otomatis.';
  }

  Future<String> delete(String uuid, {DraftOvertime? record}) async {
    final ownerId = _requireOwner();
    final target = record ?? await _localStore.byServerUuid(ownerId, uuid);
    if (target == null) throw StateError('Laporan lokal tidak ditemukan.');
    final removedOnlyLocal = await _localStore.deleteLocal(
      ownerId: ownerId,
      record: target,
    );
    // A delete is intentional. Its pending photos no longer need to remain on
    // this device even if the server-side DELETE must be retried later.
    if (target.localId != null) {
      await _photoStore.removeOvertime(
        ownerId: ownerId,
        localOvertimeId: target.localId!,
      );
    }
    notifyListeners();
    unawaited(syncNow());
    return removedOnlyLocal
        ? 'Laporan lokal dihapus.'
        : 'Laporan dihapus dari tampilan dan menunggu sinkronisasi.';
  }

  Future<String?> _persistPhoto({
    required String ownerId,
    required String localId,
    required String slot,
    required StampedPhoto? photo,
  }) {
    if (photo == null) return Future.value(null);
    return _photoStore.persist(
      ownerId: ownerId,
      localOvertimeId: localId,
      bytes: photo.bytes,
      fileName: photo.fileName,
      slot: slot,
    );
  }

  String _requireOwner() {
    final owner = _ownerId;
    if (owner == null || owner.isEmpty) {
      throw StateError('Sesi pengguna lokal belum siap.');
    }
    return owner;
  }

  @override
  void dispose() {
    syncStatus.removeListener(notifyListeners);
    unawaited(_syncEngine.dispose());
    syncStatus.dispose();
    super.dispose();
  }
}
