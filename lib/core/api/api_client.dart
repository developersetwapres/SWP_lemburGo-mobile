import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../storage/token_storage.dart';
import 'api_client_platform.dart'
    if (dart.library.html) 'api_client_web.dart' as platform;
import 'api_exception.dart';

class ApiClient {
  ApiClient._(this.dio);

  final Dio dio;

  static Future<ApiClient> create(TokenStorage tokenStorage) async {
    final dio = await platform.createPlatformDio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: const {'Accept': 'application/json'},
      ),
    );

    final apiClient = ApiClient._(dio);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] != true) {
            final token = await tokenStorage.readToken();

            if (token == null || token.isEmpty) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 401,
                    data: const {
                      'message':
                          'Sesi Anda telah berakhir. Silakan masuk kembali.',
                    },
                  ),
                ),
              );
              return;
            }

            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },
      ),
    );

    return apiClient;
  }

  ApiException exceptionFrom(DioException error) {
    final data = error.response?.data;
    final statusCode = error.response?.statusCode;

    if (data is Map<String, dynamic>) {
      final errors = <String, List<String>>{};
      final rawErrors = data['errors'];

      if (rawErrors is Map) {
        rawErrors.forEach((key, value) {
          if (value is List) {
            errors[key.toString()] = value
                .map((item) => item.toString())
                .toList();
          }
        });
      }

      final message = data['message']?.toString() ?? _messageFor(statusCode);

      return ApiException(
        message: message,
        statusCode: statusCode,
        fieldErrors: errors,
      );
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const ApiException(
        message: 'Koneksi ke server terlalu lama. Silakan coba lagi.',
      );
    }

    if (error.type == DioExceptionType.connectionError) {
      return const ApiException(
        message: 'Tidak dapat terhubung ke server. Periksa koneksi Anda.',
      );
    }

    return ApiException(
      message: _messageFor(statusCode),
      statusCode: statusCode,
    );
  }

  String _messageFor(int? statusCode) {
    if (statusCode == 401) {
      return 'Sesi Anda telah berakhir. Silakan masuk kembali.';
    }

    if (statusCode == 422) {
      return 'Periksa kembali data yang Anda masukkan.';
    }

    if (statusCode != null && statusCode >= 500) {
      return 'Server sedang bermasalah. Coba lagi beberapa saat.';
    }

    return 'Terjadi kendala. Silakan coba lagi.';
  }
}
