import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../data/models/photo_stamp.dart';

class OvertimeRepository {
  OvertimeRepository(this._dio, this._apiClient);
  final Dio _dio;
  final ApiClient _apiClient;

  Future<void> submit({
    required DateTime date,
    required String activityName,
    required String location,
    StampedPhoto? activityPhoto,
    StampedPhoto? checkoutPhoto,
  }) async {
    try {
      final fields = <String, dynamic>{
        'tanggal_kegiatan': _formatDate(date),
        'nama_kegiatan': activityName,
        'lokasi_kegiatan': location,
      };
      if (activityPhoto != null) {
        fields['foto_kegiatan'] = await MultipartFile.fromFile(
          activityPhoto.file.path,
          filename: 'foto_kegiatan${_fileExtension(activityPhoto.file.path)}',
        );
        fields['foto_kegiatan_at'] = _formatDateTime(activityPhoto.timestamp);
      }
      if (checkoutPhoto != null) {
        fields['foto_pulang'] = await MultipartFile.fromFile(
          checkoutPhoto.file.path,
          filename: 'foto_pulang${_fileExtension(checkoutPhoto.file.path)}',
        );
        fields['foto_pulang_at'] = _formatDateTime(checkoutPhoto.timestamp);
      }
      final data = activityPhoto == null && checkoutPhoto == null
          ? fields
          : FormData.fromMap(fields);
      await _dio.post<void>('/lemburs', data: data);
    } on DioException catch (error) {
      throw _apiClient.exceptionFrom(error);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String _formatDateTime(DateTime value) =>
      '${_formatDate(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

  String _fileExtension(String path) {
    final index = path.lastIndexOf('.');
    return index < 0 ? '.jpg' : path.substring(index);
  }
}
