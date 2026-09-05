import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Owns unsynchronised photos. Files are copied out of the temporary directory
/// before their database record is committed, so closing the app cannot lose a
/// pending upload.
class LocalPhotoStore {
  LocalPhotoStore({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  Future<String> persist({
    required String ownerId,
    required String localOvertimeId,
    required File source,
    required String slot,
  }) async {
    final documents = await _documentsDirectory();
    final directory = Directory(
      path.join(
        documents.path,
        'lemburnakit',
        'photos',
        ownerId,
        localOvertimeId,
      ),
    );
    await directory.create(recursive: true);
    final extension = path.extension(source.path).isEmpty
        ? '.jpg'
        : path.extension(source.path);
    // Never overwrite an existing evidence file before the SQLite mutation has
    // committed. This keeps the previous photo valid if a second photo copy or
    // database write fails midway through an edit.
    final target = File(
      path.join(
        directory.path,
        '$slot-${DateTime.now().microsecondsSinceEpoch}$extension',
      ),
    );
    await source.copy(target.path);
    return target.path;
  }

  Future<void> discard(String? value) async {
    if (value == null) return;
    final file = File(value);
    if (await file.exists()) await file.delete();
  }

  Future<void> removeOvertime({
    required String ownerId,
    required String localOvertimeId,
  }) async {
    final documents = await _documentsDirectory();
    final directory = Directory(
      path.join(
        documents.path,
        'lemburnakit',
        'photos',
        ownerId,
        localOvertimeId,
      ),
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
