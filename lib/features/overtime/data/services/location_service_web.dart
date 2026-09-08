import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/config/api_config.dart';
import '../models/photo_stamp.dart';
import 'location_service_base.dart';

export 'location_service_base.dart';

/// Uses browser geolocation. Native `geocoding` is not imported on Web; an
/// optional configured HTTPS endpoint handles reverse geocoding instead.
class LocationService {
  Future<DeviceAddress> currentAddress() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw const LocationException('Aktifkan layanan lokasi di browser untuk membuat timestamp otomatis.');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw const LocationException('Izin lokasi browser belum diberikan. Anda dapat menggunakan timestamp manual.');
    try {
      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
      return await _reverse(position.latitude, position.longitude);
    } catch (_) { return const DeviceAddress(road: 'Lokasi browser tidak tersedia', districtCity: '', province: '', isFallback: true); }
  }

  Future<DeviceAddress> _reverse(double latitude, double longitude) async {
    if (ApiConfig.reverseGeocodingUrl.isEmpty) return _coordinateFallback(latitude, longitude);
    try {
      final response = await Dio().get<Map<String, dynamic>>(ApiConfig.reverseGeocodingUrl, queryParameters: {'lat': latitude, 'lng': longitude});
      final data = response.data;
      if (data == null) return _coordinateFallback(latitude, longitude);
      final road = data['road']?.toString().trim() ?? '';
      final districtCity = data['districtCity']?.toString().trim() ?? '';
      final province = data['province']?.toString().trim() ?? '';
      if (road.isEmpty && districtCity.isEmpty && province.isEmpty) return _coordinateFallback(latitude, longitude);
      return DeviceAddress(road: road.isEmpty ? 'Lokasi browser' : road, districtCity: districtCity, province: province);
    } catch (_) { return _coordinateFallback(latitude, longitude); }
  }
  DeviceAddress _coordinateFallback(double lat, double lng) => DeviceAddress(road: 'Koordinat ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}', districtCity: 'Reverse geocoding belum dikonfigurasi', province: '', isFallback: true);
}
