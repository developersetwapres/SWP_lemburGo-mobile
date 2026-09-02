import 'dart:io';

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

class ManualTimestampData {
  const ManualTimestampData({required this.dateTime, required this.address});
  final DateTime dateTime;
  final DeviceAddress address;
}

class StampedPhoto {
  const StampedPhoto({
    required this.file,
    required this.sourceFile,
    required this.timestamp,
    required this.address,
    required this.mode,
  });
  final File file;
  final File sourceFile;
  final DateTime timestamp;
  final DeviceAddress address;
  final PhotoStampMode mode;
}
