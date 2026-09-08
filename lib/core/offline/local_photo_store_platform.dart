import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class LocalPhotoStore {
  LocalPhotoStore({Future<Directory> Function()? documentsDirectory})
      : _documentsDirectory = documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  Future<String> persist({
    required String ownerId,
    required String localOvertimeId,
    required Uint8List bytes,
    required String fileName,
    required String slot,
  }) async {
    final documents = await _documentsDirectory();
    final directory = Directory(path.join(documents.path, 'lemburnakit', 'photos', ownerId, localOvertimeId));
    await directory.create(recursive: true);
    final extension = path.extension(fileName).isEmpty ? '.jpg' : path.extension(fileName);
    final target = File(path.join(directory.path, '$slot-${DateTime.now().microsecondsSinceEpoch}$extension'));
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  Future<void> discard(String? value) async {
    if (value == null) return;
    final file = File(value);
    if (await file.exists()) await file.delete();
  }

  Future<void> removeOvertime({required String ownerId, required String localOvertimeId}) async {
    final documents = await _documentsDirectory();
    final directory = Directory(path.join(documents.path, 'lemburnakit', 'photos', ownerId, localOvertimeId));
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

Future<Uint8List?> readLocalPhoto(String reference) async {
  final file = File(reference);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}
