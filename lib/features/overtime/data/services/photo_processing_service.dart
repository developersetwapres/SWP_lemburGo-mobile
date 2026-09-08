import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

import '../models/photo_stamp.dart';
import 'location_service.dart';

class PhotoProcessingService {
  PhotoProcessingService({ImagePicker? picker, LocationService? locationService})
      : _picker = picker ?? ImagePicker(),
        _locationService = locationService ?? LocationService();

  final ImagePicker _picker;
  final LocationService _locationService;

  Future<XFile?> pickImage({required ImageSource source}) => _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 94,
        maxWidth: 2400,
      );

  Future<StampedPhoto> createAutomaticStamp(XFile source) async => _stamp(
        source: source,
        timestamp: DateTime.now(),
        address: await _locationService.currentAddress(),
        mode: PhotoStampMode.automatic,
      );

  Future<StampedPhoto> createAutomaticStampAt({
    required XFile source,
    required DateTime timestamp,
    required DeviceAddress address,
  }) => _stamp(source: source, timestamp: timestamp, address: address, mode: PhotoStampMode.automatic);

  Future<DeviceAddress> prepareAutomaticCameraStamp() => _locationService.currentAddress();

  Future<StampedPhoto> createManualStamp({required XFile source, required ManualTimestampData data}) =>
      _stamp(source: source, timestamp: data.dateTime, address: data.address, mode: PhotoStampMode.manual);

  Future<StampedPhoto> keepExistingTimestamp({required XFile source, required DateTime timestamp}) async {
    final bytes = await _readAndValidate(source);
    return StampedPhoto(
      bytes: bytes,
      fileName: _fileName(source),
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
    final bytes = await _readAndValidate(source);
    final stamped = await compute(
      _burnTimestamp,
      _StampPayload(bytes, timestamp, address.lines),
    );
    if (stamped.length > 10 * 1024 * 1024) {
      throw const PhotoProcessingException('Ukuran foto melebihi 10 MB. Pilih foto dengan ukuran lebih kecil.');
    }
    return StampedPhoto(
      bytes: stamped,
      fileName: _jpegFileName(source),
      timestamp: timestamp,
      address: address,
      mode: mode,
    );
  }

  Future<Uint8List> _readAndValidate(XFile source) async {
    final bytes = await source.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      throw const PhotoProcessingException('Ukuran foto melebihi 10 MB. Pilih foto dengan ukuran lebih kecil.');
    }
    return bytes;
  }

  String _fileName(XFile source) => source.name.isEmpty ? 'photo.jpg' : source.name;

  String _jpegFileName(XFile source) {
    final name = _fileName(source);
    final dot = name.lastIndexOf('.');
    return '${dot < 0 ? name : name.substring(0, dot)}.jpg';
  }
}

class PhotoProcessingException implements Exception {
  const PhotoProcessingException(this.message);
  final String message;
}

class _StampPayload {
  const _StampPayload(this.bytes, this.timestamp, this.addressLines);
  final Uint8List bytes;
  final DateTime timestamp;
  final List<String> addressLines;
}

Uint8List _burnTimestamp(_StampPayload payload) {
  var decoded = image.decodeImage(payload.bytes);
  if (decoded == null) throw const PhotoProcessingException('Format foto tidak didukung. Gunakan JPG atau PNG.');
  decoded = image.bakeOrientation(decoded);
  if (decoded.width > 1920) decoded = image.copyResize(decoded, width: 1920);
  final content = PhotoTimestampContent(
    timestamp: payload.timestamp,
    address: DeviceAddress(
      road: payload.addressLines.isNotEmpty ? payload.addressLines.first : '',
      districtCity: payload.addressLines.length > 1 ? payload.addressLines[1] : '',
      province: payload.addressLines.length > 2 ? payload.addressLines[2] : '',
    ),
  );
  final lines = content.addressLines;
  const outer = 32, padding = 26, lineHeight = 30;
  final boxHeight = 32 + 34 + 34 + 14 + (lines.length * lineHeight) + 18;
  final left = outer, right = decoded.width - outer, top = decoded.height - boxHeight - outer;
  image.fillRect(decoded, x1: left, y1: top, x2: right, y2: decoded.height - outer, color: image.ColorRgba8(8, 21, 37, 194), radius: 20);
  image.fillRect(decoded, x1: left, y1: top, x2: right, y2: top + 8, color: image.ColorRgba8(22, 136, 232, 255), radius: 20);
  final maxWidth = right - left - padding * 2;
  image.drawString(decoded, _trimToWidth(content.dateLabel, image.arial24, maxWidth), font: image.arial24, x: left + padding, y: top + 24, color: image.ColorRgba8(255, 255, 255, 255));
  image.drawString(decoded, content.timeLabel, font: image.arial24, x: left + padding, y: top + 58, color: image.ColorRgba8(255, 255, 255, 255));
  var y = top + 98;
  for (final line in lines) {
    image.drawString(decoded, _trimToWidth(line, image.arial24, maxWidth), font: image.arial24, x: left + padding, y: y, color: image.ColorRgba8(222, 235, 247, 255));
    y += lineHeight;
  }
  var quality = 92;
  var output = Uint8List.fromList(image.encodeJpg(decoded, quality: quality));
  while (output.length > 9 * 1024 * 1024 && quality > 68) {
    quality -= 8;
    output = Uint8List.fromList(image.encodeJpg(decoded, quality: quality));
  }
  return output;
}

String _trimToWidth(String value, image.BitmapFont font, int maxWidth) {
  var width = 0;
  final buffer = StringBuffer();
  for (final codeUnit in value.codeUnits) {
    final character = String.fromCharCode(codeUnit);
    final nextWidth = width + font.characterXAdvance(character);
    if (nextWidth > maxWidth) return '${buffer.toString().trimRight()}...';
    buffer.write(character);
    width = nextWidth;
  }
  return value;
}
