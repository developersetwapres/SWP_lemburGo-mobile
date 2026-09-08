import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:kmz_lemburgo_mobile/core/api/api_exception.dart';
import 'package:kmz_lemburgo_mobile/core/offline/local_overtime_store.dart';
import 'package:kmz_lemburgo_mobile/core/offline/local_photo_store.dart';
import 'package:kmz_lemburgo_mobile/core/offline/offline_database.dart';
import 'package:kmz_lemburgo_mobile/core/offline/sync_engine.dart';
import 'package:kmz_lemburgo_mobile/core/offline/sync_models.dart';
import 'package:kmz_lemburgo_mobile/core/offline/sync_status.dart';
import 'package:kmz_lemburgo_mobile/features/calendar/data/models/calendar_overtime.dart';
import 'package:kmz_lemburgo_mobile/features/history/data/models/overtime_history.dart';
import 'package:kmz_lemburgo_mobile/features/overtime/data/models/draft_overtime.dart';
import 'package:kmz_lemburgo_mobile/features/overtime/data/models/year_overtime_summary.dart';
import 'package:kmz_lemburgo_mobile/features/overtime/data/remote_overtime_api.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('compact create response exposes its UUID', () {
    final record = DraftOvertime.fromJson(const {
      'uuid': 'a073fd2b-b98f-4419-8aaa-ebf0872dc59a',
    });

    expect(record.uuid, 'a073fd2b-b98f-4419-8aaa-ebf0872dc59a');
  });

  test('draft status is shown only on Home, not History or Calendar', () async {
    final fixture = await _StoreFixture.open();
    addTearDown(fixture.close);
    final now = DateTime.now();
    final draftDate = DateTime(now.year, now.month, 5);
    final completedDate = DateTime(now.year, now.month, 6);
    await fixture.store.createLocal(
      ownerId: 'pegawai-a',
      localId: 'local-draft',
      clientRequestId: 'request-draft',
      date: draftDate,
      activityName: 'Lokal draft',
      location: 'Jakarta',
    );
    await fixture.store.upsertRemoteRecords(
      ownerId: 'pegawai-a',
      records: [
        _serverRecord(
          uuid: 'server-draft',
          status: 'draft',
          activityDate: draftDate,
        ),
        _serverRecord(
          uuid: 'server-complete',
          status: 'complete',
          activityDate: completedDate,
        ),
      ],
    );
    await fixture.store.replaceCalendarEntries(
      ownerId: 'pegawai-a',
      entries: [
        CalendarOvertime(
          date: draftDate,
          overtimeId: 1,
          uuid: 'calendar-draft',
          status: 'draft',
        ),
        CalendarOvertime(
          date: completedDate,
          overtimeId: 2,
          uuid: 'calendar-complete',
          status: 'complete',
        ),
      ],
    );

    final drafts = await fixture.store.drafts('pegawai-a');
    final history = await fixture.store.history('pegawai-a', now.month);
    final calendar = await fixture.store.calendar('pegawai-a');

    expect(
      drafts.map((record) => record.uuid),
      unorderedEquals(['', 'server-draft']),
    );
    expect(history.records.map((record) => record.uuid), ['server-complete']);
    expect(calendar.map((entry) => entry.uuid), ['server-complete']);
  });

  test('create and update offline are local, durable, and coalesced', () async {
    final fixture = await _StoreFixture.open();
    addTearDown(fixture.close);

    final created = await fixture.store.createLocal(
      ownerId: 'pegawai-a',
      localId: 'local-1',
      clientRequestId: 'request-1',
      date: DateTime(2026, 9, 6),
      activityName: 'Monitoring jaringan',
      location: 'Ruang server',
    );
    expect((await fixture.store.drafts('pegawai-a')).single.localId, 'local-1');
    expect(
      (await fixture.store.readyOperations('pegawai-a')).single.type,
      SyncOperationType.create,
    );

    final updated = await fixture.store.updateLocal(
      ownerId: 'pegawai-a',
      current: created,
      date: DateTime(2026, 9, 6),
      activityName: 'Monitoring jaringan malam',
      location: 'Ruang server',
    );
    final operations = await fixture.store.readyOperations('pegawai-a');
    expect(operations, hasLength(1));
    expect(operations.single.type, SyncOperationType.create);
    expect(operations.single.revision, 2);
    expect(updated.activityName, 'Monitoring jaringan malam');

    final removedOnlyLocal = await fixture.store.deleteLocal(
      ownerId: 'pegawai-a',
      record: updated,
    );
    expect(removedOnlyLocal, isTrue);
    expect(await fixture.store.drafts('pegawai-a'), isEmpty);
    expect(await fixture.store.readyOperations('pegawai-a'), isEmpty);
  });

  test(
    'successful create links local ID to server UUID exactly once',
    () async {
      final fixture = await _StoreFixture.open();
      addTearDown(fixture.close);
      final created = await fixture.store.createLocal(
        ownerId: 'pegawai-a',
        localId: 'local-1',
        clientRequestId: 'request-1',
        date: DateTime(2026, 9, 6),
        activityName: 'Audit',
        location: 'Jakarta',
      );
      final operation = (await fixture.store.readyOperations('pegawai-a'))
          .single;
      await fixture.store.markSyncing(operation);
      await fixture.store.markOperationSucceeded(
        operation,
        createdServerRecord: _serverRecord(uuid: 'server-uuid-1'),
      );

      final linked = await fixture.store.byLocalId(
        'pegawai-a',
        created.localId!,
      );
      expect(linked!.localId, 'local-1');
      expect(linked.uuid, 'server-uuid-1');
      expect(linked.localSyncState, LocalSyncState.synced);
      expect(await fixture.store.readyOperations('pegawai-a'), isEmpty);
    },
  );

  test(
    'edit after a create response uses UPDATE even with a stale screen copy',
    () async {
      final fixture = await _StoreFixture.open();
      addTearDown(fixture.close);
      final staleScreenCopy = await fixture.store.createLocal(
        ownerId: 'pegawai-a',
        localId: 'local-1',
        clientRequestId: 'request-1',
        date: DateTime(2026, 9, 6),
        activityName: 'Audit',
        location: 'Jakarta',
      );
      final create = (await fixture.store.readyOperations('pegawai-a')).single;
      await fixture.store.markOperationSucceeded(
        create,
        createdServerRecord: _serverRecord(uuid: 'server-uuid-1'),
      );

      await fixture.store.updateLocal(
        ownerId: 'pegawai-a',
        current: staleScreenCopy,
        date: DateTime(2026, 9, 6),
        activityName: 'Audit lanjutan',
        location: 'Jakarta',
      );

      expect(
        (await fixture.store.readyOperations('pegawai-a')).single.type,
        SyncOperationType.update,
      );
    },
  );

  test(
    'interrupted syncing operation is restored and retried after restart',
    () async {
      final fixture = await _StoreFixture.open();
      addTearDown(fixture.close);
      await fixture.store.createLocal(
        ownerId: 'pegawai-a',
        localId: 'local-1',
        clientRequestId: 'request-1',
        date: DateTime(2026, 9, 6),
        activityName: 'Audit',
        location: 'Jakarta',
      );
      final operation = (await fixture.store.readyOperations('pegawai-a'))
          .single;
      await fixture.store.markSyncing(operation);
      await fixture.store.recoverInterruptedOperations('pegawai-a');
      expect(
        (await fixture.store.readyOperations('pegawai-a')).single.state,
        SyncOperationState.pending,
      );
    },
  );

  test(
    'sync engine uploads one queued create and does not duplicate it',
    () async {
      final fixture = await _StoreFixture.open();
      addTearDown(fixture.close);
      await fixture.store.createLocal(
        ownerId: 'pegawai-a',
        localId: 'local-1',
        clientRequestId: 'request-1',
        date: DateTime(2026, 9, 6),
        activityName: 'Audit',
        location: 'Jakarta',
      );
      final remote = _FakeRemote();
      final engine = SyncEngine(
        localStore: fixture.store,
        remoteApi: remote,
        status: SyncStatus(),
        onUnauthenticated: () async {},
        connectivityCheck: () async => [ConnectivityResult.wifi],
        connectivityChanges: const Stream.empty(),
      );
      addTearDown(engine.dispose);

      await engine.activate('pegawai-a');
      await engine.syncNow();
      await engine.syncNow();

      expect(remote.createCalls, 1);
      expect(
        (await fixture.store.byLocalId('pegawai-a', 'local-1'))!.uuid,
        'server-uuid-1',
      );
    },
  );

  test(
    'offline delete hides a server record and queues a durable delete',
    () async {
      final fixture = await _StoreFixture.open();
      addTearDown(fixture.close);
      final local = await fixture.store.createLocal(
        ownerId: 'pegawai-a',
        localId: 'local-1',
        clientRequestId: 'request-1',
        date: DateTime(2026, 9, 6),
        activityName: 'Audit',
        location: 'Jakarta',
      );
      final create = (await fixture.store.readyOperations('pegawai-a')).single;
      await fixture.store.markOperationSucceeded(
        create,
        createdServerRecord: _serverRecord(uuid: 'server-uuid-1'),
      );
      final linked = await fixture.store.byLocalId('pegawai-a', local.localId!);
      final removedOnlyLocal = await fixture.store.deleteLocal(
        ownerId: 'pegawai-a',
        record: linked!,
      );

      expect(removedOnlyLocal, isFalse);
      expect(await fixture.store.drafts('pegawai-a'), isEmpty);
      final delete = (await fixture.store.readyOperations('pegawai-a')).single;
      expect(delete.type, SyncOperationType.delete);
      await fixture.store.markOperationSucceeded(delete);
      expect(await fixture.store.byLocalId('pegawai-a', 'local-1'), isNull);
    },
  );

  test(
    'validation failure remains visible and can be discarded locally',
    () async {
      final fixture = await _StoreFixture.open();
      addTearDown(fixture.close);
      await fixture.store.createLocal(
        ownerId: 'pegawai-a',
        localId: 'local-1',
        clientRequestId: 'request-1',
        date: DateTime(2026, 9, 6),
        activityName: 'Audit',
        location: 'Jakarta',
      );
      final remote = _FakeRemote(
        createError: const ApiException(
          message: 'Tanggal lembur sudah memiliki laporan.',
          statusCode: 422,
        ),
      );
      final status = SyncStatus();
      final engine = SyncEngine(
        localStore: fixture.store,
        remoteApi: remote,
        status: status,
        onUnauthenticated: () async {},
        connectivityCheck: () async => [ConnectivityResult.wifi],
        connectivityChanges: const Stream.empty(),
      );
      addTearDown(engine.dispose);

      await engine.activate('pegawai-a');
      await engine.syncNow();

      final record = await fixture.store.byLocalId('pegawai-a', 'local-1');
      expect(record!.localSyncState, LocalSyncState.blocked);
      expect(await fixture.store.readyOperations('pegawai-a'), isEmpty);
      expect(status.apiReachable, isTrue);
      expect(status.lastError, 'Tanggal lembur sudah memiliki laporan.');

      final removedOnlyLocal = await fixture.store.deleteLocal(
        ownerId: 'pegawai-a',
        record: record,
      );
      expect(removedOnlyLocal, isTrue);
      expect(await fixture.store.byLocalId('pegawai-a', 'local-1'), isNull);
      expect(await fixture.store.pendingOperationCount('pegawai-a'), 0);
    },
  );

  test(
    'pending photo is copied outside temporary storage and can be cleaned',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'lemburnakit-photo-test',
      );
      addTearDown(() => root.delete(recursive: true));
      final source = File('${root.path}${Platform.pathSeparator}temporary.jpg');
      await source.writeAsBytes([1, 2, 3, 4]);
      final store = LocalPhotoStore(documentsDirectory: () async => root);

      final persisted = await store.persist(
        ownerId: 'pegawai-a',
        localOvertimeId: 'local-1',
        bytes: await source.readAsBytes(),
        fileName: source.path.split(Platform.pathSeparator).last,
        slot: 'activity',
      );
      expect(File(persisted).existsSync(), isTrue);
      expect(persisted, isNot(source.path));
      await store.removeOvertime(
        ownerId: 'pegawai-a',
        localOvertimeId: 'local-1',
      );
      expect(File(persisted).existsSync(), isFalse);
    },
  );

  test(
    'a failed photo upload keeps its durable local evidence for retry',
    () async {
      final fixture = await _StoreFixture.open();
      addTearDown(fixture.close);
      final root = await Directory.systemTemp.createTemp('lemburnakit-upload');
      addTearDown(() => root.delete(recursive: true));
      final temporary = File('${root.path}${Platform.pathSeparator}source.jpg');
      await temporary.writeAsBytes([1, 2, 3, 4]);
      final photoStore = LocalPhotoStore(documentsDirectory: () async => root);
      final permanent = await photoStore.persist(
        ownerId: 'pegawai-a',
        localOvertimeId: 'local-photo',
        bytes: await temporary.readAsBytes(),
        fileName: temporary.path.split(Platform.pathSeparator).last,
        slot: 'activity',
      );
      await fixture.store.createLocal(
        ownerId: 'pegawai-a',
        localId: 'local-photo',
        clientRequestId: 'request-photo',
        date: DateTime(2026, 9, 6),
        activityName: 'Audit',
        location: 'Jakarta',
        activityPhotoPath: permanent,
        activityPhotoAt: DateTime(2026, 9, 6, 20),
      );
      final engine = SyncEngine(
        localStore: fixture.store,
        remoteApi: _FakeRemote(
          createError: const ApiException(
            message: 'Upload gagal',
            statusCode: 500,
          ),
        ),
        status: SyncStatus(),
        onUnauthenticated: () async {},
        connectivityCheck: () async => [ConnectivityResult.wifi],
        connectivityChanges: const Stream.empty(),
      );
      addTearDown(engine.dispose);

      await engine.activate('pegawai-a');
      await engine.syncNow();

      final record = await fixture.store.byLocalId('pegawai-a', 'local-photo');
      expect(record!.activityPhotoPendingUpload, isTrue);
      expect(File(record.activityPhotoLocalPath!).existsSync(), isTrue);
      expect(record.localSyncState, LocalSyncState.retryWaiting);
    },
  );

  test('5xx is retried and 401 retains data while requesting login', () async {
    final retryFixture = await _StoreFixture.open();
    addTearDown(retryFixture.close);
    await retryFixture.store.createLocal(
      ownerId: 'pegawai-a',
      localId: 'local-retry',
      clientRequestId: 'request-retry',
      date: DateTime(2026, 9, 6),
      activityName: 'Audit',
      location: 'Jakarta',
    );
    final retryEngine = SyncEngine(
      localStore: retryFixture.store,
      remoteApi: _FakeRemote(
        createError: const ApiException(
          message: 'Server bermasalah',
          statusCode: 500,
        ),
      ),
      status: SyncStatus(),
      onUnauthenticated: () async {},
      connectivityCheck: () async => [ConnectivityResult.wifi],
      connectivityChanges: const Stream.empty(),
    );
    addTearDown(retryEngine.dispose);
    await retryEngine.activate('pegawai-a');
    await retryEngine.syncNow();
    expect(
      (await retryFixture.store.byLocalId(
        'pegawai-a',
        'local-retry',
      ))!.localSyncState,
      LocalSyncState.retryWaiting,
    );
    expect(await retryFixture.store.nextRetryAt('pegawai-a'), isNotNull);

    final authFixture = await _StoreFixture.open();
    addTearDown(authFixture.close);
    await authFixture.store.createLocal(
      ownerId: 'pegawai-a',
      localId: 'local-auth',
      clientRequestId: 'request-auth',
      date: DateTime(2026, 9, 6),
      activityName: 'Audit',
      location: 'Jakarta',
    );
    var loginRequired = false;
    final authEngine = SyncEngine(
      localStore: authFixture.store,
      remoteApi: _FakeRemote(
        createError: const ApiException(
          message: 'Sesi berakhir',
          statusCode: 401,
        ),
      ),
      status: SyncStatus(),
      onUnauthenticated: () async => loginRequired = true,
      connectivityCheck: () async => [ConnectivityResult.wifi],
      connectivityChanges: const Stream.empty(),
    );
    addTearDown(authEngine.dispose);
    await authEngine.activate('pegawai-a');
    await authEngine.syncNow();
    expect(loginRequired, isTrue);
    expect(
      (await authFixture.store.byLocalId(
        'pegawai-a',
        'local-auth',
      ))!.localSyncState,
      LocalSyncState.awaitingAuthentication,
    );
    await authFixture.store.recoverInterruptedOperations('pegawai-a');
    expect(
      (await authFixture.store.readyOperations('pegawai-a')).single.state,
      SyncOperationState.pending,
    );
  });

  test(
    'missing create identity stays blocked instead of being blindly retried',
    () async {
      final fixture = await _StoreFixture.open();
      addTearDown(fixture.close);
      await fixture.store.createLocal(
        ownerId: 'pegawai-a',
        localId: 'local-identity',
        clientRequestId: 'request-identity',
        date: DateTime(2026, 9, 6),
        activityName: 'Audit',
        location: 'Jakarta',
      );
      final remote = _FakeRemote(
        createError: const MissingCreateIdentityException(),
      );
      final engine = SyncEngine(
        localStore: fixture.store,
        remoteApi: remote,
        status: SyncStatus(),
        onUnauthenticated: () async {},
        connectivityCheck: () async => [ConnectivityResult.wifi],
        connectivityChanges: const Stream.empty(),
      );
      addTearDown(engine.dispose);

      await engine.activate('pegawai-a');
      await engine.syncNow();
      await engine.retryBlocked();

      expect(remote.createCalls, 1);
      expect(await fixture.store.readyOperations('pegawai-a'), isEmpty);
      expect(
        (await fixture.store.byLocalId(
          'pegawai-a',
          'local-identity',
        ))!.localSyncState,
        LocalSyncState.blocked,
      );
    },
  );
}

class _StoreFixture {
  _StoreFixture(this.database, this.store);

  final Database database;
  final LocalOvertimeStore store;

  static Future<_StoreFixture> open() async {
    final database = await OfflineDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    return _StoreFixture(database, LocalOvertimeStore(database));
  }

  Future<void> close() => database.close();
}

class _FakeRemote implements OvertimeRemoteGateway {
  _FakeRemote({this.createError});

  final Object? createError;
  int createCalls = 0;

  @override
  Future<DraftOvertime> create(DraftOvertime record) async {
    createCalls += 1;
    if (createError != null) throw createError!;
    return _serverRecord(uuid: 'server-uuid-1');
  }

  @override
  Future<void> delete(String uuid) async {}

  @override
  Future<List<CalendarOvertime>> fetchCalendarEntries() async => const [];

  @override
  Future<DraftOvertime> fetchDetail(String uuid) async =>
      _serverRecord(uuid: uuid);

  @override
  Future<List<DraftOvertime>> fetchDrafts() async => const [];

  @override
  Future<OvertimeHistory> fetchHistory({int? month}) async => OvertimeHistory(
    records: const [],
    month: month ?? DateTime.now().month,
    totalUpah: 0,
    totalOvertime: 0,
    workdayOvertime: 0,
    holidayOvertime: 0,
  );

  @override
  Future<YearOvertimeSummary> fetchYearOvertimeSummary() async =>
      const YearOvertimeSummary.empty();

  @override
  Future<OvertimePdfExport> exportPdf({required String month}) async =>
      OvertimePdfExport(month: month, bytes: const [37, 80, 68, 70]);

  @override
  Future<void> update(DraftOvertime record) async {}
}

DraftOvertime _serverRecord({
  required String uuid,
  String status = 'draft',
  DateTime? activityDate,
}) => DraftOvertime(
  id: '21',
  uuid: uuid,
  activityDate: activityDate ?? DateTime(2026, 9, 6),
  activityName: 'Audit',
  location: 'Jakarta',
  status: status,
);
