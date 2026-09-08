import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class OvertimePdfDelivery {
  const OvertimePdfDelivery();

  /// Stores the export in the application's document directory before opening
  /// the native share sheet, so the report remains available after sharing.
  Future<PdfDeliveryResult> deliver({
    required List<int> bytes,
    required String fileName,
  }) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, 'laporan_lembur'));
    await directory.create(recursive: true);
    final file = File(path.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    var shareSheetOpened = true;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          title: 'Laporan lembur',
        ),
      );
    } catch (_) {
      // Saving succeeded. Keep the file available even when the platform has
      // no compatible sharing target (for example, some Linux desktops).
      shareSheetOpened = false;
    }

    return PdfDeliveryResult(
      fileName: fileName,
      savedLocation: file.path,
      shareSheetOpened: shareSheetOpened,
    );
  }
}

class PdfDeliveryResult {
  const PdfDeliveryResult({
    required this.fileName,
    required this.savedLocation,
    required this.shareSheetOpened,
  });

  final String fileName;
  final String savedLocation;
  final bool shareSheetOpened;
}
