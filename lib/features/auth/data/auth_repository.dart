import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import 'models/auth_user.dart';

class AuthRepository {
  AuthRepository(this._dio, this._apiClient, this._storage);
  final Dio _dio;
  final ApiClient _apiClient;
  final TokenStorage _storage;

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
        options: Options(extra: {'skipAuth': true}),
      );
      final responseData = response.data ?? const <String, dynamic>{};
      final data = Map<String, dynamic>.from(
        responseData['data'] as Map? ?? const {},
      );
      final meta = Map<String, dynamic>.from(
        responseData['meta'] as Map? ?? const {},
      );
      final token = meta['token']?.toString();
      if (token == null || token.isEmpty || data.isEmpty) {
        throw const FormatException('Respons login tidak lengkap.');
      }
      final user = AuthUser.fromLoginResponse(data);
      await _storage.saveSession(
        token: token,
        userJson: jsonEncode(user.toJson()),
      );
      return user;
    } on DioException catch (error) {
      final exception = _apiClient.exceptionFrom(error);
      if (exception.statusCode == 401) {
        throw const ApiException(
          message: 'Email atau password tidak sesuai.',
          statusCode: 401,
        );
      }
      throw exception;
    }
  }

  Future<AuthUser?> restoreUser() async {
    final token = await _storage.readToken();
    final userJson = await _storage.readUser();
    if (token == null || userJson == null) {
      if (token != null || userJson != null) {
        await _storage.clear();
      }
      return null;
    }
    try {
      return AuthUser.fromJson(
        Map<String, dynamic>.from(jsonDecode(userJson) as Map),
      );
    } catch (_) {
      await _storage.clear();
      return null;
    }
  }

  Future<void> logout() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      await _storage.clear();
      return;
    }

    try {
      await _dio.post<Map<String, dynamic>>('/auth/logout');
    } on DioException {
      // Local credentials are always removed so the user can safely leave
      // this device even when the server cannot be reached.
    } finally {
      await _storage.clear();
    }
  }

  Future<void> clearSession() => _storage.clear();
}
