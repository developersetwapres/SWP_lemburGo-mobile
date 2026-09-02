import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient(this._tokenStorage) {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: const {'Accept': 'application/json'},
      ),
    )..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token = await _tokenStorage.readToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          },
        ),
      );
  }

  final TokenStorage _tokenStorage;
  late final Dio dio;

  ApiException exceptionFrom(DioException error) {
    final data = error.response?.data;
    final statusCode = error.response?.statusCode;
    if (data is Map<String, dynamic>) {
      final errors = <String, List<String>>{};
      final rawErrors = data['errors'];
      if (rawErrors is Map) {
        rawErrors.forEach((key, value) {
          if (value is List) errors[key.toString()] = value.map((item) => item.toString()).toList();
        });
      }
      final message = data['message']?.toString() ?? _messageFor(statusCode);
      return ApiException(message: message, statusCode: statusCode, fieldErrors: errors);
    }
    if (error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.receiveTimeout) {
      return const ApiException(message: 'Koneksi ke server terlalu lama. Silakan coba lagi.');
    }
    if (error.type == DioExceptionType.connectionError) {
      return const ApiException(message: 'Tidak dapat terhubung ke server. Periksa koneksi Anda.');
    }
    return ApiException(message: _messageFor(statusCode), statusCode: statusCode);
  }

  String _messageFor(int? statusCode) {
    if (statusCode == 401) return 'Sesi Anda telah berakhir. Silakan masuk kembali.';
    if (statusCode == 422) return 'Periksa kembali data yang Anda masukkan.';
    if (statusCode != null && statusCode >= 500) return 'Server sedang bermasalah. Coba lagi beberapa saat.';
    return 'Terjadi kendala. Silakan coba lagi.';
  }
}
