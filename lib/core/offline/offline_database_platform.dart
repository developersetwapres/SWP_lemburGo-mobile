import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

Future<DatabaseFactory> databaseFactory() async {
  if (Platform.isWindows || Platform.isLinux) {
    ffi.sqfliteFfiInit();
    return ffi.databaseFactoryFfi;
  }
  return ffi.databaseFactory;
}

Future<String> defaultDatabasePath() async =>
    path.join(await ffi.getDatabasesPath(), 'lemburnakit_offline.db');
