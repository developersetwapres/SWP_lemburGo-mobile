import 'dart:typed_data';

enum PhotoSlot { activity, checkout }

enum PhotoStampMode { automatic, manual, existingTimestamp }

enum PhotoInputState {
  empty,
  sourceSelected,
  photoSelected,
  timestampProcessing,
  ready,
  error,
}

class DeviceAddress {
  const DeviceAddress({
    required this.road,
    required this.districtCity,
    required this.province,
    this.isFallback = false,
  });
  final String road;
  final String districtCity;
  final String province;
  final bool isFallback;

  List<String> get lines => [
    road,
    districtCity,
    province,
  ].where((line) => line.trim().isNotEmpty).toList();
}

/// The text that appears in the live camera overlay and is permanently
/// embedded in a captured photo. Keeping it independent of Flutter widgets
/// makes the preview and the rendered image use the same wording.
class PhotoTimestampContent {
  const PhotoTimestampContent({required this.timestamp, required this.address});

  final DateTime timestamp;
  final DeviceAddress address;

  String get dateLabel {
    const monthNames = [
      'JANUARI',
      'FEBRUARI',
      'MARET',
      'APRIL',
      'MEI',
      'JUNI',
      'JULI',
      'AGUSTUS',
      'SEPTEMBER',
      'OKTOBER',
      'NOVEMBER',
      'DESEMBER',
    ];
    return '${timestamp.day.toString().padLeft(2, '0')} '
        '${monthNames[timestamp.month - 1]} ${timestamp.year}';
  }

  String get timeLabel =>
      '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')} WIB';

  List<String> get addressLines => address.lines.take(3).toList();
}

class ManualTimestampData {
  const ManualTimestampData({required this.dateTime, required this.address});
  final DateTime dateTime;
  final DeviceAddress address;
}

class StampedPhoto {
  const StampedPhoto({
    required this.bytes,
    required this.fileName,
    required this.timestamp,
    required this.address,
    required this.mode,
  });
  /// Byte data makes browser camera/file-picker output independent of a path.
  final Uint8List bytes;
  final String fileName;
  final DateTime timestamp;
  final DeviceAddress address;
  final PhotoStampMode mode;
}
