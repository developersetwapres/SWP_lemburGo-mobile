import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// This factory runs SQLite WASM in the browser and persists the database in
/// IndexedDB. It is not a native/FFI database path.
Future<DatabaseFactory> databaseFactory() async => databaseFactoryFfiWeb;

Future<String> defaultDatabasePath() async => 'lemburnakit_offline.db';
