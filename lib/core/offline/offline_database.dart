import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The on-device source of truth for all business data. SQLite is used instead
/// of a key-value cache because each local mutation and its queue entry must be
/// committed atomically.
class OfflineDatabase {
  OfflineDatabase._();

  static const schemaVersion = 1;

  static Future<Database> open({
    DatabaseFactory? factory,
    String? databasePath,
  }) async {
    final resolvedFactory = factory ?? _platformFactory();
    final resolvedPath = databasePath ?? await _defaultPath();
    return resolvedFactory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: _create,
        onUpgrade: _upgrade,
      ),
    );
  }

  static DatabaseFactory _platformFactory() {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return databaseFactory;
  }

  static Future<String> _defaultPath() async =>
      path.join(await getDatabasesPath(), 'lemburnakit_offline.db');

  static Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE overtimes (
        local_id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        server_id TEXT,
        server_uuid TEXT,
        client_request_id TEXT NOT NULL,
        activity_date TEXT NOT NULL,
        activity_name TEXT NOT NULL,
        location TEXT NOT NULL,
        server_status TEXT NOT NULL,
        activity_photo_remote_url TEXT,
        activity_photo_local_path TEXT,
        activity_photo_at TEXT,
        activity_photo_pending_upload INTEGER NOT NULL DEFAULT 0,
        checkout_photo_remote_url TEXT,
        checkout_photo_local_path TEXT,
        checkout_photo_at TEXT,
        checkout_photo_pending_upload INTEGER NOT NULL DEFAULT 0,
        checkout_time TEXT,
        is_draft INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        local_revision INTEGER NOT NULL DEFAULT 0,
        sync_state TEXT NOT NULL DEFAULT 'synced',
        sync_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_synced_at TEXT
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX overtimes_owner_server_uuid '
      'ON overtimes(owner_id, server_uuid) WHERE server_uuid IS NOT NULL',
    );
    await db.execute(
      'CREATE INDEX overtimes_owner_date '
      'ON overtimes(owner_id, is_deleted, activity_date)',
    );

    await db.execute('''
      CREATE TABLE sync_operations (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        local_id TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        operation_state TEXT NOT NULL,
        revision INTEGER NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        next_attempt_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(local_id) REFERENCES overtimes(local_id)
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX sync_operations_owner_local '
      'ON sync_operations(owner_id, local_id)',
    );
    await db.execute(
      'CREATE INDEX sync_operations_due '
      'ON sync_operations(owner_id, operation_state, next_attempt_at, created_at)',
    );

    await db.execute('''
      CREATE TABLE monthly_summaries (
        owner_id TEXT NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        total_upah REAL NOT NULL,
        total_lembur INTEGER NOT NULL,
        lembur_hari_kerja INTEGER NOT NULL,
        lembur_hari_libur INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(owner_id, year, month)
      )
    ''');
    await db.execute('''
      CREATE TABLE yearly_summaries (
        owner_id TEXT NOT NULL,
        year INTEGER NOT NULL,
        total_upah REAL NOT NULL,
        total_lembur INTEGER NOT NULL,
        lembur_hari_kerja INTEGER NOT NULL,
        lembur_hari_libur INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(owner_id, year)
      )
    ''');
    await db.execute('''
      CREATE TABLE calendar_entries (
        owner_id TEXT NOT NULL,
        activity_date TEXT NOT NULL,
        server_id INTEGER NOT NULL DEFAULT 0,
        server_uuid TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL,
        PRIMARY KEY(owner_id, activity_date)
      )
    ''');
  }

  static Future<void> _upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Version one is intentionally a fresh additive database. Session data is
    // still owned by TokenStorage, so existing installations are unaffected.
    if (oldVersion < 1) await _create(db, newVersion);
  }
}
