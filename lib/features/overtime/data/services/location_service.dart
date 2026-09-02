import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/photo_stamp.dart';

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;
}

class LocationService {
  Future<DeviceAddress> currentAddress() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Aktifkan layanan lokasi untuk membuat timestamp otomatis.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw const LocationException('Izin lokasi belum diberikan. Anda dapat mencoba lagi atau mengatur timestamp manual.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException('Izin lokasi ditolak permanen. Buka Pengaturan atau gunakan timestamp manual.');
    }
    try {
      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
      final places = await placemarkFromCoordinates(position.latitude, position.longitude);
      final place = places.isNotEmpty ? places.first : null;
      if (place == null) return const DeviceAddress(road: 'Lokasi perangkat', districtCity: '', province: '', isFallback: true);
      final road = _first(place.street, place.name, 'Lokasi perangkat');
      final district = _first(place.subLocality, place.subAdministrativeArea, '');
      final city = _first(place.locality, place.subAdministrativeArea, place.administrativeArea, '');
      return DeviceAddress(road: road, districtCity: _joinDistinct(district, city), province: _first(place.administrativeArea, ''));
    } catch (_) {
      return const DeviceAddress(road: 'Lokasi perangkat tidak tersedia', districtCity: '', province: '', isFallback: true);
    }
  }

  String _first(String? first, [String? second, String? third, String? fourth]) {
    for (final value in [first, second, third, fourth]) { if (value != null && value.trim().isNotEmpty) return value.trim(); }
    return '';
  }

  String _joinDistinct(String first, String second) => first.isEmpty || first.toLowerCase() == second.toLowerCase() ? (first.isEmpty ? second : first) : '$first, $second';
}
