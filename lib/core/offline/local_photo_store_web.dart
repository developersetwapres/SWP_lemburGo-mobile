import 'dart:convert';
import 'dart:typed_data';

/// Browser evidence is stored alongside the offline row in the Web SQLite
/// database (which is persisted in IndexedDB). A data URI is intentionally a
/// reference rather than an ephemeral object URL, so queued uploads survive a
/// reload and can be decoded without a browser file-system path.
class LocalPhotoStore {
  Future<String> persist({
    required String ownerId,
    required String localOvertimeId,
    required Uint8List bytes,
    required String fileName,
    required String slot,
  }) async => 'data:image/jpeg;base64,${base64Encode(bytes)}';

  Future<void> discard(String? value) async {}
  Future<void> removeOvertime({required String ownerId, required String localOvertimeId}) async {}
}

Future<Uint8List?> readLocalPhoto(String reference) async {
  final comma = reference.indexOf(',');
  if (!reference.startsWith('data:') || comma < 0) return null;
  try {
    return Uint8List.fromList(base64Decode(reference.substring(comma + 1)));
  } on FormatException {
    return null;
  }
}
