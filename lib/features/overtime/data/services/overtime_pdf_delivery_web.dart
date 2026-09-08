import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

class OvertimePdfDelivery {
  const OvertimePdfDelivery();

  /// Uses the browser share UI when it is available. Otherwise share_plus
  /// downloads the generated file with [fileName].
  Future<PdfDeliveryResult> deliver({
    required List<int> bytes,
    required String fileName,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(bytes),
            mimeType: 'application/pdf',
          ),
        ],
        fileNameOverrides: [fileName],
        title: 'Laporan lembur',
      ),
    );
    return PdfDeliveryResult(
      fileName: fileName,
      savedLocation: 'Unduhan browser',
      shareSheetOpened: true,
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
