import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/offline/local_photo_store.dart';
import '../../calendar/data/models/calendar_overtime.dart';
import '../../history/data/models/overtime_history.dart';
import 'models/draft_overtime.dart';
import 'models/year_overtime_summary.dart';

/// Thin Laravel transport. It intentionally owns no local state; callers can
/// therefore persist a mutation before a network attempt is made.
abstract interface class OvertimeRemoteGateway {
  Future<List<DraftOvertime>> fetchDrafts();
  Future<DraftOvertime> fetchDetail(String uuid);
  Future<OvertimeHistory> fetchHistory({int? month});
  Future<List<CalendarOvertime>> fetchCalendarEntries();
  Future<YearOvertimeSummary> fetchYearOvertimeSummary();
  Future<OvertimePdfExport> exportPdf({required String month});
  Future<DraftOvertime> create(DraftOvertime record);
  Future<void> update(DraftOvertime record);
  Future<void> delete(String uuid);
}

class RemoteOvertimeApi implements OvertimeRemoteGateway {
  RemoteOvertimeApi(this._dio, this._apiClient);

  final Dio _dio;
  final ApiClient _apiClient;

  @override
  Future<List<DraftOvertime>> fetchDrafts() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/lemburs/draft');
      final rawData = response.data?['data'];
      if (rawData is! List) return const [];
      return rawData
          .whereType<Map>()
          .map(
            (item) => DraftOvertime.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } on DioException catch (error) {
      throw _apiClient.exceptionFrom(error);
    }
  }

  @override
  Future<DraftOvertime> fetchDetail(String uuid) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/lemburs/detail/$uuid',
      );
      final rawData = response.data?['data'];
      if (rawData is! Map) {
        throw const FormatException('Format detail lembur tidak valid.');
      }
      return DraftOvertime.fromJson(Map<String, dynamic>.from(rawData));
    } on DioException catch (error) {
      throw _apiClient.exceptionFrom(error);
    }
  }

  @override
  Future<OvertimeHistory> fetchHistory({int? month}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/lemburs',
        queryParameters: month == null ? null : {'bulan': month},
      );
      return OvertimeHistory.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _apiClient.exceptionFrom(error);
    }
  }

  @override
  Future<List<CalendarOvertime>> fetchCalendarEntries() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/lemburs/kalender',
      );
      final rawData = response.data?['data'];
      if (rawData is! List) return const [];
      return rawData
          .whereType<Map>()
          .map(
            (item) =>
                CalendarOvertime.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } on DioException catch (error) {
      throw _apiClient.exceptionFrom(error);
    }
  }

  @override
  Future<YearOvertimeSummary> fetchYearOvertimeSummary() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/lemburs/total-upah',
      );
      return YearOvertimeSummary.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _apiClient.exceptionFrom(error);
    }
  }

  @override
  Future<OvertimePdfExport> exportPdf({required String month}) async {
    try {
      final response = await _dio.get<List<int>>(
        '/lemburs/export',
        queryParameters: {'bulan': month},
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {'Accept': 'application/pdf'},
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const NoOvertimePdfDataException();
      }
      return OvertimePdfExport(month: month, bytes: bytes);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        throw const NoOvertimePdfDataException();
      }
      throw _apiClient.exceptionFrom(error);
    }
  }

  /// Requires Laravel to use [record.clientRequestId] as an idempotency key
  /// and return the created JSON:API resource in `data` (including UUID).
  @override
  Future<DraftOvertime> create(DraftOvertime record) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/lemburs',
        data: await _requestData(
          record,
          includePendingPhotos: true,
          includeClientRequestId: true,
        ),
        options: Options(headers: {'Idempotency-Key': record.clientRequestId}),
      );
      final raw = response.data?['data'];
      if (raw is! Map) {
        throw const MissingCreateIdentityException();
      }
      final created = DraftOvertime.fromJson(Map<String, dynamic>.from(raw));
      if (created.uuid.trim().isEmpty) {
        throw const MissingCreateIdentityException();
      }
      return created;
    } on DioException catch (error) {
      throw _apiClient.exceptionFrom(error);
    }
  }

  @override
  Future<void> update(DraftOvertime record) async {
    if (record.uuid.trim().isEmpty) {
      throw StateError('Laporan belum memiliki UUID server.');
    }
    try {
      await _dio.put<Map<String, dynamic>>(
        '/lemburs/${record.uuid}',
        data: await _requestData(
          record,
          includePendingPhotos: true,
          includeClientRequestId: false,
        ),
      );
    } on DioException catch (error) {
      throw _apiClient.exceptionFrom(error);
    }
  }

  @override
  Future<void> delete(String uuid) async {
    try {
      await _dio.delete<Map<String, dynamic>>('/lemburs/delete/$uuid');
    } on DioException catch (error) {
      final exception = _apiClient.exceptionFrom(error);
      // DELETE is convergent: if another device already removed it, the local
      // desired state (removed) has still been achieved.
      if (exception.statusCode == 404) {
        return;
      }
      throw exception;
    }
  }

  Future<Object> _requestData(
    DraftOvertime record, {
    required bool includePendingPhotos,
    required bool includeClientRequestId,
  }) async {
    final fields = <String, dynamic>{
      'tanggal_kegiatan': _formatDate(record.activityDate),
      'nama_kegiatan': record.activityName,
      'lokasi_kegiatan': record.location,
      if (includeClientRequestId && record.clientRequestId?.isNotEmpty == true)
        'client_request_id': record.clientRequestId,
    };
    if (includePendingPhotos && record.activityPhotoPendingUpload) {
      fields['foto_kegiatan'] = await _photoFile(
        record.activityPhotoLocalPath,
        'foto_kegiatan',
      );
      fields['foto_kegiatan_at'] = _formatDateTime(record.activityPhotoAt);
    }
    if (includePendingPhotos && record.checkoutPhotoPendingUpload) {
      fields['foto_pulang'] = await _photoFile(
        record.checkoutPhotoLocalPath,
        'foto_pulang',
      );
      fields['foto_pulang_at'] = _formatDateTime(record.checkoutPhotoAt);
    }
    final hasFiles = fields.values.any((value) => value is MultipartFile);
    if (!hasFiles) return fields;
    final data = FormData();
    fields.forEach((key, value) {
      if (value is MultipartFile) {
        data.files.add(MapEntry(key, value));
      } else {
        data.fields.add(MapEntry(key, value.toString()));
      }
    });
    return data;
  }

  Future<MultipartFile> _photoFile(String? localPath, String field) async {
    if (localPath == null) {
      throw StateError('File $field yang menunggu upload tidak ditemukan.');
    }
    final bytes = await readLocalPhoto(localPath);
    if (bytes == null) {
      throw StateError('File $field yang menunggu upload tidak ditemukan.');
    }
    return MultipartFile.fromBytes(
      bytes,
      filename: '$field${_extension(localPath)}',
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String _formatDateTime(DateTime? value) {
    if (value == null) throw StateError('Timestamp foto tidak tersedia.');
    return '${_formatDate(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
  }

  String _extension(String value) {
    final index = value.lastIndexOf('.');
    return index < 0 ? '.jpg' : value.substring(index);
  }
}

class MissingCreateIdentityException implements Exception {
  const MissingCreateIdentityException();

  @override
  String toString() =>
      'Server belum mengembalikan UUID laporan. Sinkronisasi create dihentikan untuk mencegah duplikasi.';
}

class OvertimePdfExport {
  const OvertimePdfExport({required this.month, required this.bytes});

  final String month;
  final List<int> bytes;

  String get fileName => 'lembur-$month.pdf';
}

class NoOvertimePdfDataException implements Exception {
  const NoOvertimePdfDataException();

  @override
  String toString() =>
      'Tidak ada data lembur lengkap yang dapat diekspor untuk bulan ini.';
}
