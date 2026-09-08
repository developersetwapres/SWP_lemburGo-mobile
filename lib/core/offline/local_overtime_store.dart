import 'dart:math';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../features/calendar/data/models/calendar_overtime.dart';
import '../../features/history/data/models/overtime_history.dart';
import '../../features/overtime/data/models/draft_overtime.dart';
import '../../features/overtime/data/models/year_overtime_summary.dart';
import 'sync_models.dart';

/// Query and mutation boundary for the local source of truth. Every change to
/// an overtime record and its sync operation is written in one transaction.
class LocalOvertimeStore {
  LocalOvertimeStore(this._database, {String Function()? idFactory})
    : _idFactory = idFactory ?? const Uuid().v7;

  final Database _database;
  final String Function() _idFactory;

  String newIdentifier() => _idFactory();

  Future<List<DraftOvertime>> drafts(String ownerId) async {
    final rows = await _database.query(
      'overtimes',
      where:
          "owner_id = ? AND is_deleted = 0 "
          "AND LOWER(TRIM(server_status)) = 'draft'",
      whereArgs: [ownerId],
      orderBy: 'activity_date DESC, updated_at DESC',
    );
    return rows.map(_recordFromRow).toList();
  }

  Future<OvertimeHistory> history(String ownerId, int month) async {
    final year = DateTime.now().year;
    final first = DateTime(year, month).toIso8601String().substring(0, 10);
    final last = DateTime(year, month + 1).toIso8601String().substring(0, 10);
    final rows = await _database.query(
      'overtimes',
      where:
          'owner_id = ? AND is_deleted = 0 '
          "AND LOWER(TRIM(server_status)) != 'draft' "
          'AND activity_date >= ? AND activity_date < ?',
      whereArgs: [ownerId, first, last],
      orderBy: 'activity_date DESC, updated_at DESC',
    );
    final summaryRows = await _database.query(
      'monthly_summaries',
      where: 'owner_id = ? AND year = ? AND month = ?',
      whereArgs: [ownerId, year, month],
      limit: 1,
    );
    final summary = summaryRows.isEmpty ? null : summaryRows.first;
    final records = rows.map(_recordFromRow).toList();
    return OvertimeHistory(
      records: records,
      month: month,
      // Upah is never invented locally. Zero means there is no server cache
      // yet, not that the user has earned zero overtime pay.
      totalUpah: _number(summary?['total_upah']),
      totalOvertime: records.length,
      workdayOvertime: _int(summary?['lembur_hari_kerja']),
      holidayOvertime: _int(summary?['lembur_hari_libur']),
      isServerSummaryStale: summary == null,
      serverSummaryUpdatedAt: _date(summary?['updated_at']),
    );
  }

  Future<List<CalendarOvertime>> calendar(String ownerId) async {
    final rows = await _database.query(
      'overtimes',
      where:
          "owner_id = ? AND is_deleted = 0 "
          "AND LOWER(TRIM(server_status)) != 'draft'",
      whereArgs: [ownerId],
    );
    final entries = <String, CalendarOvertime>{
      for (final row in rows)
        CalendarOvertime.dateKeyFor(
          CalendarOvertime.parseDateOnly(row['activity_date'] as String?),
        ): CalendarOvertime(
          date: CalendarOvertime.parseDateOnly(row['activity_date'] as String?),
          overtimeId: int.tryParse((row['server_id'] ?? '0').toString()) ?? 0,
          uuid: (row['server_uuid'] ?? '').toString(),
          status: row['server_status']?.toString() ?? 'draft',
          localId: row['local_id']?.toString(),
        ),
    };
    final remoteRows = await _database.query(
      'calendar_entries',
      where: "owner_id = ? AND LOWER(TRIM(server_status)) != 'draft'",
      whereArgs: [ownerId],
    );
    for (final row in remoteRows) {
      final date = CalendarOvertime.parseDateOnly(
        row['activity_date'] as String?,
      );
      entries.putIfAbsent(
        CalendarOvertime.dateKeyFor(date),
        () => CalendarOvertime(
          date: date,
          overtimeId: _int(row['server_id']),
          uuid: row['server_uuid']?.toString() ?? '',
          status: row['server_status']?.toString() ?? 'draft',
        ),
      );
    }
    return entries.values.toList();
  }

  Future<YearOvertimeSummary> yearSummary(String ownerId) async {
    final year = DateTime.now().year;
    final rows = await _database.query(
      'yearly_summaries',
      where: 'owner_id = ? AND year = ?',
      whereArgs: [ownerId, year],
      limit: 1,
    );
    if (rows.isEmpty) return const YearOvertimeSummary.empty();
    final row = rows.first;
    return YearOvertimeSummary(
      workdayOvertime: _int(row['lembur_hari_kerja']),
      holidayOvertime: _int(row['lembur_hari_libur']),
      totalOvertime: _int(row['total_lembur']),
      totalPay: _number(row['total_upah']),
      isServerSummaryStale: false,
      serverSummaryUpdatedAt: _date(row['updated_at']),
    );
  }

  Future<DraftOvertime?> byLocalId(String ownerId, String localId) =>
      _one(ownerId, 'local_id = ?', [localId]);

  Future<DraftOvertime?> byServerUuid(String ownerId, String uuid) =>
      _one(ownerId, 'server_uuid = ?', [uuid]);

  Future<DraftOvertime?> _one(
    String ownerId,
    String predicate,
    List<Object?> arguments,
  ) async {
    final rows = await _database.query(
      'overtimes',
      where: 'owner_id = ? AND $predicate',
      whereArgs: [ownerId, ...arguments],
      limit: 1,
    );
    return rows.isEmpty ? null : _recordFromRow(rows.first);
  }

  Future<DraftOvertime> createLocal({
    required String ownerId,
    required DateTime date,
    required String activityName,
    required String location,
    String? activityPhotoPath,
    DateTime? activityPhotoAt,
    String? checkoutPhotoPath,
    DateTime? checkoutPhotoAt,
    String? localId,
    String? clientRequestId,
  }) async {
    final generatedLocalId = localId ?? _idFactory();
    final requestId = clientRequestId ?? _idFactory();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((transaction) async {
      await transaction.insert('overtimes', {
        'local_id': generatedLocalId,
        'owner_id': ownerId,
        'client_request_id': requestId,
        'activity_date': _dateOnly(date),
        'activity_name': activityName,
        'location': location,
        'server_status': 'draft',
        'activity_photo_local_path': activityPhotoPath,
        'activity_photo_at': _dateText(activityPhotoAt),
        'activity_photo_pending_upload': activityPhotoPath == null ? 0 : 1,
        'checkout_photo_local_path': checkoutPhotoPath,
        'checkout_photo_at': _dateText(checkoutPhotoAt),
        'checkout_photo_pending_upload': checkoutPhotoPath == null ? 0 : 1,
        'is_draft': 1,
        'local_revision': 1,
        'sync_state': 'pending',
        'created_at': now,
        'updated_at': now,
      });
      await _insertOperation(
        transaction,
        ownerId: ownerId,
        localId: generatedLocalId,
        type: SyncOperationType.create,
        revision: 1,
      );
    });
    return (await byLocalId(ownerId, generatedLocalId))!;
  }

  Future<DraftOvertime> updateLocal({
    required String ownerId,
    required DraftOvertime current,
    required DateTime date,
    required String activityName,
    required String location,
    String? newActivityPhotoPath,
    DateTime? newActivityPhotoAt,
    String? newCheckoutPhotoPath,
    DateTime? newCheckoutPhotoAt,
  }) async {
    final localId = await _resolveLocalId(ownerId, current);
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((transaction) async {
      final row = await transaction.query(
        'overtimes',
        where: 'owner_id = ? AND local_id = ?',
        whereArgs: [ownerId, localId],
        limit: 1,
      );
      if (row.isEmpty) throw StateError('Laporan lokal tidak ditemukan.');
      final revision = _int(row.first['local_revision']) + 1;
      final changes = <String, Object?>{
        'activity_date': _dateOnly(date),
        'activity_name': activityName,
        'location': location,
        'is_draft': 1,
        'local_revision': revision,
        'sync_state': 'pending',
        'sync_error': null,
        'updated_at': now,
      };
      if (newActivityPhotoPath != null) {
        changes.addAll({
          'activity_photo_local_path': newActivityPhotoPath,
          'activity_photo_at': _dateText(newActivityPhotoAt),
          'activity_photo_pending_upload': 1,
        });
      }
      if (newCheckoutPhotoPath != null) {
        changes.addAll({
          'checkout_photo_local_path': newCheckoutPhotoPath,
          'checkout_photo_at': _dateText(newCheckoutPhotoAt),
          'checkout_photo_pending_upload': 1,
        });
      }
      await transaction.update(
        'overtimes',
        changes,
        where: 'owner_id = ? AND local_id = ?',
        whereArgs: [ownerId, localId],
      );
      await _upsertMutationOperation(
        transaction,
        ownerId: ownerId,
        localId: localId,
        // `current` can be a screen snapshot from just before an in-flight
        // create receives its UUID. The database row is the source of truth:
        // using the stale UI value here could incorrectly enqueue another
        // CREATE instead of the required UPDATE.
        type: row.first['server_uuid']?.toString().trim().isEmpty ?? true
            ? SyncOperationType.create
            : SyncOperationType.update,
        revision: revision,
      );
    });
    return (await byLocalId(ownerId, localId))!;
  }

  /// Returns true when the record was only local and has been removed without
  /// a server request. Synced records become hidden tombstones until DELETE is
  /// acknowledged, allowing a retry after an interrupted app session.
  Future<bool> deleteLocal({
    required String ownerId,
    required DraftOvertime record,
  }) async {
    final localId = await _resolveLocalId(ownerId, record);
    var removedOnlyLocal = false;
    await _database.transaction((transaction) async {
      final rows = await transaction.query(
        'overtimes',
        where: 'owner_id = ? AND local_id = ?',
        whereArgs: [ownerId, localId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.first;
      final isOnlyLocal =
          (row['server_uuid']?.toString().trim().isEmpty ?? true);
      if (isOnlyLocal) {
        removedOnlyLocal = true;
        await transaction.delete(
          'sync_operations',
          where: 'owner_id = ? AND local_id = ?',
          whereArgs: [ownerId, localId],
        );
        await transaction.delete(
          'overtimes',
          where: 'owner_id = ? AND local_id = ?',
          whereArgs: [ownerId, localId],
        );
        return;
      }
      final revision = _int(row['local_revision']) + 1;
      await transaction.update(
        'overtimes',
        {
          'is_deleted': 1,
          'local_revision': revision,
          'sync_state': 'pending',
          'sync_error': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'owner_id = ? AND local_id = ?',
        whereArgs: [ownerId, localId],
      );
      await _upsertMutationOperation(
        transaction,
        ownerId: ownerId,
        localId: localId,
        type: SyncOperationType.delete,
        revision: revision,
      );
    });
    return removedOnlyLocal;
  }

  Future<List<PendingSyncOperation>> readyOperations(String ownerId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _database.query(
      'sync_operations',
      where:
          'owner_id = ? AND operation_state IN (?, ?) AND '
          '(next_attempt_at IS NULL OR next_attempt_at <= ?)',
      whereArgs: [
        ownerId,
        _operationStateText(SyncOperationState.pending),
        _operationStateText(SyncOperationState.retryWaiting),
        now,
      ],
      orderBy: 'created_at ASC',
    );
    return rows.map(_operationFromRow).toList();
  }

  Future<int> pendingOperationCount(String ownerId) async {
    final result = await _database.rawQuery(
      'SELECT COUNT(*) AS count FROM sync_operations '
      'WHERE owner_id = ? AND operation_state != ?',
      [ownerId, _operationStateText(SyncOperationState.syncing)],
    );
    return _int(result.first['count']);
  }

  /// The earliest delayed retry, if a temporary server/transport failure has
  /// placed work in backoff. The sync engine owns the timer; persisting the
  /// deadline here makes the delay survive an app restart.
  Future<DateTime?> nextRetryAt(String ownerId) async {
    final rows = await _database.rawQuery(
      'SELECT MIN(next_attempt_at) AS next_attempt_at FROM sync_operations '
      'WHERE owner_id = ? AND operation_state = ? '
      'AND next_attempt_at IS NOT NULL',
      [ownerId, _operationStateText(SyncOperationState.retryWaiting)],
    );
    if (rows.isEmpty) return null;
    return _date(rows.first['next_attempt_at']);
  }

  /// An app can be terminated between marking an operation syncing and receiving
  /// its response. Requeue it on the next launch; create safety comes from the
  /// stable client_request_id/idempotency key sent by the transport.
  Future<void> recoverInterruptedOperations(String ownerId) async {
    await _database.transaction((transaction) async {
      await transaction.update(
        'sync_operations',
        {
          'operation_state': 'pending',
          'next_attempt_at': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'owner_id = ? AND operation_state = ?',
        whereArgs: [ownerId, 'syncing'],
      );
      // A user who logs in again has supplied fresh credentials. Resume only
      // work that was paused for that reason; validation and create-identity
      // blocks must remain visible until their underlying cause is resolved.
      await transaction.update(
        'sync_operations',
        {
          'operation_state': 'pending',
          'next_attempt_at': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'owner_id = ? AND operation_state = ?',
        whereArgs: [ownerId, 'awaitingAuthentication'],
      );
      await transaction.update(
        'overtimes',
        {'sync_state': 'pending', 'sync_error': null},
        where: 'owner_id = ? AND sync_state IN (?, ?)',
        whereArgs: [ownerId, 'syncing', 'awaitingAuthentication'],
      );
    });
  }

  Future<void> markSyncing(PendingSyncOperation operation) =>
      _setOperationState(operation, SyncOperationState.syncing);

  Future<void> failOperation(
    PendingSyncOperation operation, {
    required String message,
    required SyncOperationState state,
  }) async {
    final attempt = operation.attemptCount + 1;
    final next = state == SyncOperationState.retryWaiting
        ? DateTime.now()
              .toUtc()
              .add(Duration(seconds: min(1800, 5 * (1 << min(attempt, 8)))))
              .toIso8601String()
        : null;
    await _database.transaction((transaction) async {
      await transaction.update(
        'sync_operations',
        {
          'operation_state': _operationStateText(state),
          'attempt_count': attempt,
          'last_error': message,
          'next_attempt_at': next,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [operation.id],
      );
      await transaction.update(
        'overtimes',
        {
          'sync_state': _localStateText(_localStateForOperation(state)),
          'sync_error': message,
        },
        where: 'owner_id = ? AND local_id = ?',
        whereArgs: [operation.ownerId, operation.localId],
      );
    });
  }

  Future<void> markOperationSucceeded(
    PendingSyncOperation operation, {
    DraftOvertime? createdServerRecord,
  }) async {
    await _database.transaction((transaction) async {
      final rows = await transaction.query(
        'overtimes',
        where: 'owner_id = ? AND local_id = ?',
        whereArgs: [operation.ownerId, operation.localId],
        limit: 1,
      );
      if (rows.isEmpty) {
        await transaction.delete(
          'sync_operations',
          where: 'id = ?',
          whereArgs: [operation.id],
        );
        return;
      }
      final row = rows.first;
      final currentRevision = _int(row['local_revision']);
      if (operation.type == SyncOperationType.delete) {
        await transaction.delete(
          'sync_operations',
          where: 'id = ?',
          whereArgs: [operation.id],
        );
        await transaction.delete(
          'overtimes',
          where: 'owner_id = ? AND local_id = ?',
          whereArgs: [operation.ownerId, operation.localId],
        );
        return;
      }
      final values = <String, Object?>{
        'sync_state': currentRevision > operation.revision
            ? 'pending'
            : 'synced',
        'sync_error': null,
        'last_synced_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (createdServerRecord != null) {
        values['server_id'] = createdServerRecord.id;
        values['server_uuid'] = createdServerRecord.uuid;
        values['server_status'] = createdServerRecord.status;
        values['activity_photo_remote_url'] =
            createdServerRecord.activityPhotoUrl;
        values['checkout_photo_remote_url'] =
            createdServerRecord.checkoutPhotoUrl;
        values['checkout_time'] = _dateText(createdServerRecord.checkoutTime);
      }
      if (currentRevision <= operation.revision) {
        values['activity_photo_pending_upload'] = 0;
        values['checkout_photo_pending_upload'] = 0;
      }
      await transaction.update(
        'overtimes',
        values,
        where: 'owner_id = ? AND local_id = ?',
        whereArgs: [operation.ownerId, operation.localId],
      );
      await transaction.delete(
        'sync_operations',
        where: 'id = ?',
        whereArgs: [operation.id],
      );
      if (currentRevision > operation.revision) {
        await _insertOperation(
          transaction,
          ownerId: operation.ownerId,
          localId: operation.localId,
          type:
              createdServerRecord?.uuid.trim().isNotEmpty == true ||
                  row['server_uuid']?.toString().trim().isNotEmpty == true
              ? SyncOperationType.update
              : SyncOperationType.create,
          revision: currentRevision,
        );
      }
    });
  }

  Future<void> upsertRemoteRecords({
    required String ownerId,
    required List<DraftOvertime> records,
    bool replaceDraftSnapshot = false,
  }) async {
    await _database.transaction((transaction) async {
      if (replaceDraftSnapshot) {
        await transaction.rawUpdate(
          "UPDATE overtimes SET is_draft = 0 WHERE owner_id = ? "
          "AND is_deleted = 0 AND sync_state = 'synced'",
          [ownerId],
        );
      }
      for (final record in records) {
        if (record.uuid.trim().isEmpty) continue;
        final existing = await transaction.query(
          'overtimes',
          where: 'owner_id = ? AND server_uuid = ?',
          whereArgs: [ownerId, record.uuid],
          limit: 1,
        );
        final now = DateTime.now().toUtc().toIso8601String();
        if (existing.isEmpty) {
          await transaction.insert('overtimes', {
            'local_id': _idFactory(),
            'owner_id': ownerId,
            'server_id': record.id,
            'server_uuid': record.uuid,
            'client_request_id': _idFactory(),
            'activity_date': _dateOnly(record.activityDate),
            'activity_name': record.activityName,
            'location': record.location,
            'server_status': record.status,
            'activity_photo_remote_url': record.activityPhotoUrl,
            'activity_photo_at': _dateText(record.activityPhotoAt),
            'checkout_photo_remote_url': record.checkoutPhotoUrl,
            'checkout_photo_at': _dateText(record.checkoutPhotoAt),
            'checkout_time': _dateText(record.checkoutTime),
            'is_draft': replaceDraftSnapshot ? 1 : 0,
            'sync_state': 'synced',
            'created_at': now,
            'updated_at': now,
            'last_synced_at': now,
          });
          continue;
        }
        final row = existing.first;
        if (row['sync_state']?.toString() != 'synced' ||
            _int(row['is_deleted']) == 1) {
          continue;
        }
        await transaction.update(
          'overtimes',
          {
            'server_id': record.id,
            'activity_date': _dateOnly(record.activityDate),
            'activity_name': record.activityName,
            'location': record.location,
            'server_status': record.status,
            'activity_photo_remote_url': record.activityPhotoUrl,
            'activity_photo_at': _dateText(record.activityPhotoAt),
            'checkout_photo_remote_url': record.checkoutPhotoUrl,
            'checkout_photo_at': _dateText(record.checkoutPhotoAt),
            'checkout_time': _dateText(record.checkoutTime),
            if (replaceDraftSnapshot) 'is_draft': 1,
            'last_synced_at': now,
            'updated_at': now,
          },
          where: 'local_id = ?',
          whereArgs: [row['local_id']],
        );
      }
    });
  }

  Future<void> saveMonthlySummary({
    required String ownerId,
    required OvertimeHistory history,
  }) => _database.insert('monthly_summaries', {
    'owner_id': ownerId,
    'year': DateTime.now().year,
    'month': history.month,
    'total_upah': history.totalUpah,
    'total_lembur': history.totalOvertime,
    'lembur_hari_kerja': history.workdayOvertime,
    'lembur_hari_libur': history.holidayOvertime,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveYearSummary({
    required String ownerId,
    required YearOvertimeSummary summary,
  }) => _database.insert('yearly_summaries', {
    'owner_id': ownerId,
    'year': DateTime.now().year,
    'total_upah': summary.totalPay,
    'total_lembur': summary.totalOvertime,
    'lembur_hari_kerja': summary.workdayOvertime,
    'lembur_hari_libur': summary.holidayOvertime,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> replaceCalendarEntries({
    required String ownerId,
    required List<CalendarOvertime> entries,
  }) async {
    await _database.transaction((transaction) async {
      await transaction.delete(
        'calendar_entries',
        where: 'owner_id = ?',
        whereArgs: [ownerId],
      );
      final batch = transaction.batch();
      for (final entry in entries) {
        batch.insert('calendar_entries', {
          'owner_id': ownerId,
          'activity_date': CalendarOvertime.dateKeyFor(entry.date),
          'server_id': entry.overtimeId,
          'server_uuid': entry.uuid,
          'server_status': entry.status,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> reactivateBlockedOperations(String ownerId) async {
    await _database.transaction((transaction) async {
      await transaction.update(
        'sync_operations',
        {
          'operation_state': 'pending',
          'last_error': null,
          'next_attempt_at': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'owner_id = ? AND operation_state IN (?, ?)',
        whereArgs: [ownerId, 'blockedValidation', 'awaitingAuthentication'],
      );
      await transaction.update(
        'overtimes',
        {'sync_state': 'pending', 'sync_error': null},
        // Do not revive a `blockedIdentity` record merely because another
        // blocked operation belongs to the same owner. Only records whose
        // queue item was actually moved to pending may change local state.
        where:
            'owner_id = ? AND sync_state IN (?, ?) AND local_id IN ('
            'SELECT local_id FROM sync_operations '
            'WHERE owner_id = ? AND operation_state = ?)',
        whereArgs: [
          ownerId,
          'blocked',
          'awaitingAuthentication',
          ownerId,
          'pending',
        ],
      );
    });
  }

  Future<String> _resolveLocalId(String ownerId, DraftOvertime record) async {
    if (record.localId?.trim().isNotEmpty == true) {
      return record.localId!;
    }
    final resolved = await byServerUuid(ownerId, record.uuid);
    if (resolved?.localId == null) {
      throw StateError('Laporan lokal tidak ditemukan.');
    }
    return resolved!.localId!;
  }

  Future<void> _setOperationState(
    PendingSyncOperation operation,
    SyncOperationState state,
  ) => _database.transaction((transaction) async {
    await transaction.update(
      'sync_operations',
      {
        'operation_state': _operationStateText(state),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [operation.id],
    );
    await transaction.update(
      'overtimes',
      {'sync_state': _localStateText(_localStateForOperation(state))},
      where: 'owner_id = ? AND local_id = ?',
      whereArgs: [operation.ownerId, operation.localId],
    );
  });

  Future<void> _upsertMutationOperation(
    Transaction transaction, {
    required String ownerId,
    required String localId,
    required SyncOperationType type,
    required int revision,
  }) async {
    final existing = await transaction.query(
      'sync_operations',
      where: 'owner_id = ? AND local_id = ?',
      whereArgs: [ownerId, localId],
      limit: 1,
    );
    if (existing.isEmpty) {
      await _insertOperation(
        transaction,
        ownerId: ownerId,
        localId: localId,
        type: type,
        revision: revision,
      );
      return;
    }
    final old = _operationType(existing.first['operation_type']?.toString());
    final effective =
        old == SyncOperationType.create && type != SyncOperationType.delete
        ? SyncOperationType.create
        : type;
    await transaction.update(
      'sync_operations',
      {
        'operation_type': _operationTypeText(effective),
        'operation_state': 'pending',
        'revision': revision,
        'last_error': null,
        'next_attempt_at': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [existing.first['id']],
    );
  }

  Future<void> _insertOperation(
    Transaction transaction, {
    required String ownerId,
    required String localId,
    required SyncOperationType type,
    required int revision,
  }) => transaction.insert('sync_operations', {
    'id': _idFactory(),
    'owner_id': ownerId,
    'local_id': localId,
    'operation_type': _operationTypeText(type),
    'operation_state': 'pending',
    'revision': revision,
    'created_at': DateTime.now().toUtc().toIso8601String(),
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });

  DraftOvertime _recordFromRow(Map<String, Object?> row) => DraftOvertime(
    id: (row['server_id'] ?? row['local_id']).toString(),
    uuid: row['server_uuid']?.toString() ?? '',
    activityDate:
        DateTime.tryParse(row['activity_date']?.toString() ?? '') ??
        DateTime.now(),
    activityName: row['activity_name']?.toString() ?? '',
    location: row['location']?.toString() ?? '',
    status: row['server_status']?.toString() ?? 'draft',
    activityPhotoUrl: _nullable(row['activity_photo_remote_url']),
    activityPhotoAt: _date(row['activity_photo_at']),
    checkoutPhotoUrl: _nullable(row['checkout_photo_remote_url']),
    checkoutPhotoAt: _date(row['checkout_photo_at']),
    checkoutTime: _date(row['checkout_time']),
    localId: row['local_id']?.toString(),
    clientRequestId: row['client_request_id']?.toString(),
    activityPhotoLocalPath: _nullable(row['activity_photo_local_path']),
    checkoutPhotoLocalPath: _nullable(row['checkout_photo_local_path']),
    activityPhotoPendingUpload: _int(row['activity_photo_pending_upload']) == 1,
    checkoutPhotoPendingUpload: _int(row['checkout_photo_pending_upload']) == 1,
    localSyncState: _localState(row['sync_state']?.toString()),
    syncError: _nullable(row['sync_error']),
    localRevision: _int(row['local_revision']),
  );

  PendingSyncOperation _operationFromRow(Map<String, Object?> row) =>
      PendingSyncOperation(
        id: row['id']!.toString(),
        ownerId: row['owner_id']!.toString(),
        localId: row['local_id']!.toString(),
        type: _operationType(row['operation_type']?.toString()),
        state: _operationState(row['operation_state']?.toString()),
        revision: _int(row['revision']),
        attemptCount: _int(row['attempt_count']),
        createdAt: _date(row['created_at']) ?? DateTime.now(),
        lastError: _nullable(row['last_error']),
        nextAttemptAt: _date(row['next_attempt_at']),
      );

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  static String? _dateText(DateTime? value) => value?.toUtc().toIso8601String();
  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
  static String? _nullable(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
  static num _number(Object? value) =>
      value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0;

  static String _operationTypeText(SyncOperationType value) => value.name;
  static SyncOperationType _operationType(String? value) =>
      SyncOperationType.values.firstWhere(
        (candidate) => candidate.name == value,
        orElse: () => SyncOperationType.update,
      );
  static String _operationStateText(SyncOperationState value) => value.name;
  static SyncOperationState _operationState(String? value) =>
      SyncOperationState.values.firstWhere(
        (candidate) => candidate.name == value,
        orElse: () => SyncOperationState.pending,
      );
  static String _localStateText(LocalSyncState value) => value.name;
  static LocalSyncState _localState(String? value) =>
      LocalSyncState.values.firstWhere(
        (candidate) => candidate.name == value,
        orElse: () => LocalSyncState.synced,
      );
  static LocalSyncState _localStateForOperation(SyncOperationState value) =>
      switch (value) {
        SyncOperationState.pending => LocalSyncState.pending,
        SyncOperationState.syncing => LocalSyncState.syncing,
        SyncOperationState.retryWaiting => LocalSyncState.retryWaiting,
        SyncOperationState.blockedValidation => LocalSyncState.blocked,
        SyncOperationState.blockedIdentity => LocalSyncState.blocked,
        SyncOperationState.awaitingAuthentication =>
          LocalSyncState.awaitingAuthentication,
      };
}
