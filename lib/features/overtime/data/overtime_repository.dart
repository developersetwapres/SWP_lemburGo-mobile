import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../data/models/photo_stamp.dart';

class OvertimeRepository {
  OvertimeRepository(this._dio, this._apiClient);
  final Dio _dio;
  final ApiClient _apiClient;

  Future<void> submit({required DateTime date, required String activityName, required String location, required StampedPhoto activityPhoto, required StampedPhoto checkoutPhoto}) async {
    try {
      final formData = FormData.fromMap({
        'tanggal_kegiatan': _formatDate(date),
        'nama_kegiatan': activityName,
        'lokasi_kegiatan': location,
        'foto_kegiatan': await MultipartFile.fromFile(activityPhoto.file.path, filename: 'foto_kegiatan.jpg'),
        'foto_kegiatan_at': _formatDateTime(activityPhoto.timestamp),
        'foto_pulang': await MultipartFile.fromFile(checkoutPhoto.file.path, filename: 'foto_pulang.jpg'),
        'foto_pulang_at': _formatDateTime(checkoutPhoto.timestamp),
      });
      await _dio.post<void>('/lemburs', data: formData);
    } on DioException catch (error) { throw _apiClient.exceptionFrom(error); }
  }

  String _formatDate(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String _formatDateTime(DateTime value) => '${_formatDate(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
}
