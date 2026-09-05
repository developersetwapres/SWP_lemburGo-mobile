import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/photo_stamp.dart';
import 'location_service.dart';

class PhotoProcessingService {
  PhotoProcessingService({
    ImagePicker? picker,
    LocationService? locationService,
  }) : _picker = picker ?? ImagePicker(),
       _locationService = locationService ?? LocationService();
  final ImagePicker _picker;
  final LocationService _locationService;

  Future<XFile?> pickImage({required ImageSource source}) => _picker.pickImage(
    source: source,
    preferredCameraDevice: CameraDevice.rear,
    imageQuality: 94,
    maxWidth: 2400,
  );

  Future<StampedPhoto> createAutomaticStamp(XFile source) async {
    final timestamp = DateTime.now();
    final address = await _locationService.currentAddress();
    return createAutomaticStampAt(
      source: source,
      timestamp: timestamp,
      address: address,
    );
  }

  /// Used by the in-app camera. Location is resolved before opening the live
  /// preview and [timestamp] is frozen at shutter time, so the values burned
  /// into the JPEG are the same values the user saw in the camera overlay.
  Future<StampedPhoto> createAutomaticStampAt({
    required XFile source,
    required DateTime timestamp,
    required DeviceAddress address,
  }) => _stamp(
    source: source,
    timestamp: timestamp,
    address: address,
    mode: PhotoStampMode.automatic,
  );

  /// Resolves the data required by the automatic camera stamp before the
  /// camera is shown, avoiding a post-capture location lookup.
  Future<DeviceAddress> prepareAutomaticCameraStamp() =>
      _locationService.currentAddress();

  Future<StampedPhoto> createManualStamp({
    required XFile source,
    required ManualTimestampData data,
  }) => _stamp(
    source: source,
    timestamp: data.dateTime,
    address: data.address,
    mode: PhotoStampMode.manual,
  );

  /// Keeps a photo that already contains its own visual timestamp. The file is
  /// copied only for lifetime safety; it is never decoded or visually altered.
  Future<StampedPhoto> keepExistingTimestamp({
    required XFile source,
    required DateTime timestamp,
  }) async {
    final input = File(source.path);
    if (await input.length() > 10 * 1024 * 1024) {
      throw const PhotoProcessingException(
        'Ukuran foto melebihi 10 MB. Pilih foto dengan ukuran lebih kecil.',
      );
    }
    final directory = await getTemporaryDirectory();
    final output = await input.copy(
      '${directory.path}${Platform.pathSeparator}lemburin_${DateTime.now().microsecondsSinceEpoch}${_extension(source.path)}',
    );
    return StampedPhoto(
      file: output,
      sourceFile: output,
      timestamp: timestamp,
      address: const DeviceAddress(road: '', districtCity: '', province: ''),
      mode: PhotoStampMode.existingTimestamp,
    );
  }

  Future<StampedPhoto> _stamp({
    required XFile source,
    required DateTime timestamp,
    required DeviceAddress address,
    required PhotoStampMode mode,
  }) async {
    final directory = await getTemporaryDirectory();
    final outputPath =
        '${directory.path}${Platform.pathSeparator}lemburin_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final payload = _StampPayload(
      inputPath: source.path,
      outputPath: outputPath,
      timestamp: timestamp,
      addressLines: address.lines,
    );
    final stampedPath = await compute(_burnTimestamp, payload);
    final output = File(stampedPath);
    if (await output.length() > 10 * 1024 * 1024) {
      throw const PhotoProcessingException(
        'Ukuran foto melebihi 10 MB. Pilih foto dengan ukuran lebih kecil.',
      );
    }
    return StampedPhoto(
      file: output,
      sourceFile: File(source.path),
      timestamp: timestamp,
      address: address,
      mode: mode,
    );
  }

  String _extension(String path) {
    final index = path.lastIndexOf('.');
    return index < 0 ? '.jpg' : path.substring(index);
  }
}

class PhotoProcessingException implements Exception {
  const PhotoProcessingException(this.message);
  final String message;
}

class _StampPayload {
  const _StampPayload({
    required this.inputPath,
    required this.outputPath,
    required this.timestamp,
    required this.addressLines,
  });
  final String inputPath, outputPath;
  final DateTime timestamp;
  final List<String> addressLines;
}

Future<String> _burnTimestamp(_StampPayload payload) async {
  final source = await File(payload.inputPath).readAsBytes();
  var decoded = image.decodeImage(source);
  if (decoded == null) {
    throw const PhotoProcessingException(
      'Format foto tidak didukung. Gunakan JPG atau PNG.',
    );
  }
  decoded = image.bakeOrientation(decoded);
  if (decoded.width > 1920) decoded = image.copyResize(decoded, width: 1920);
  final content = PhotoTimestampContent(
    timestamp: payload.timestamp,
    address: DeviceAddress(
      road: payload.addressLines.isNotEmpty ? payload.addressLines.first : '',
      districtCity: payload.addressLines.length > 1
          ? payload.addressLines[1]
          : '',
      province: payload.addressLines.length > 2 ? payload.addressLines[2] : '',
    ),
  );
  final addressLines = content.addressLines;
  const outerPadding = 32;
  const panelPadding = 26;
  const dateHeight = 34;
  const timeHeight = 34;
  const addressLineHeight = 30;
  final boxHeight =
      32 +
      dateHeight +
      timeHeight +
      14 +
      (addressLines.length * addressLineHeight) +
      18;
  final left = outerPadding;
  final bottom = outerPadding;
  final right = decoded.width - outerPadding;
  final top = decoded.height - boxHeight - bottom;

  // Documentary-camera styling: a translucent, high-contrast navy card with
  // one consistent text scale. The same information is rendered in the live
  // CameraPreview before shutter is pressed.
  image.fillRect(
    decoded,
    x1: left,
    y1: top,
    x2: right,
    y2: decoded.height - bottom,
    color: image.ColorRgba8(8, 21, 37, 194),
    radius: 20,
  );
  image.fillRect(
    decoded,
    x1: left,
    y1: top,
    x2: right,
    y2: top + 8,
    color: image.ColorRgba8(22, 136, 232, 255),
    radius: 20,
  );
  image.drawString(
    decoded,
    _trimToWidth(
      content.dateLabel,
      image.arial24,
      right - left - panelPadding * 2,
    ),
    font: image.arial24,
    x: left + panelPadding,
    y: top + 24,
    color: image.ColorRgba8(255, 255, 255, 255),
  );
  image.drawString(
    decoded,
    content.timeLabel,
    font: image.arial24,
    x: left + panelPadding,
    y: top + 58,
    color: image.ColorRgba8(255, 255, 255, 255),
  );
  var addressY = top + 98;
  for (final addressLine in addressLines) {
    image.drawString(
      decoded,
      _trimToWidth(addressLine, image.arial24, right - left - panelPadding * 2),
      font: image.arial24,
      x: left + panelPadding,
      y: addressY,
      color: image.ColorRgba8(222, 235, 247, 255),
    );
    addressY += addressLineHeight;
  }
  var quality = 92;
  var bytes = image.encodeJpg(decoded, quality: quality);
  while (bytes.length > 9 * 1024 * 1024 && quality > 68) {
    quality -= 8;
    bytes = image.encodeJpg(decoded, quality: quality);
  }
  await File(payload.outputPath).writeAsBytes(bytes, flush: true);
  return payload.outputPath;
}

String _trimToWidth(String value, image.BitmapFont font, int maxWidth) {
  var width = 0;
  final buffer = StringBuffer();
  for (final codeUnit in value.codeUnits) {
    final character = String.fromCharCode(codeUnit);
    final nextWidth = width + font.characterXAdvance(character);
    if (nextWidth > maxWidth) {
      return '${buffer.toString().trimRight()}...';
    }
    buffer.write(character);
    width = nextWidth;
  }
  return value;
}
