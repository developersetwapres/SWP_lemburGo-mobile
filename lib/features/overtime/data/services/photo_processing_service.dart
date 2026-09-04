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
    return _stamp(
      source: source,
      timestamp: timestamp,
      address: address,
      mode: PhotoStampMode.automatic,
    );
  }

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
  final monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  final dateLine =
      '${payload.timestamp.day.toString().padLeft(2, '0')} ${monthNames[payload.timestamp.month - 1]} ${payload.timestamp.year} | ${payload.timestamp.hour.toString().padLeft(2, '0')}:${payload.timestamp.minute.toString().padLeft(2, '0')} WIB';
  final lines = [dateLine, ...payload.addressLines.take(3)];
  const padding = 30;
  const lineHeight = 32;
  final fontSize = image.arial24;
  final boxHeight = 28 + (lines.length * lineHeight);
  final left = padding;
  final bottom = padding;
  final top = decoded.height - boxHeight - bottom;
  image.fillRect(
    decoded,
    x1: left,
    y1: top,
    x2: decoded.width - padding,
    y2: decoded.height - bottom,
    color: image.ColorRgba8(9, 24, 42, 205),
    radius: 18,
  );
  var lineY = top + 14;
  for (var index = 0; index < lines.length; index++) {
    image.drawString(
      decoded,
      lines[index],
      font: fontSize,
      x: left + 22,
      y: lineY,
      color: image.ColorRgba8(255, 255, 255, 255),
    );
    lineY += lineHeight;
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
