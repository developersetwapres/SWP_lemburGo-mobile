import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/token_storage.dart';
import 'models/auth_user.dart';

class AuthRepository {
  AuthRepository(this._dio, this._apiClient, this._storage);
  final Dio _dio;
  final ApiClient _apiClient;
  final TokenStorage _storage;

  Future<AuthUser> login({required String email, required String password}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/auth/login', data: {'email': email, 'password': password});
      final responseData = response.data ?? const <String, dynamic>{};
      final data = Map<String, dynamic>.from(responseData['data'] as Map? ?? const {});
      final meta = Map<String, dynamic>.from(responseData['meta'] as Map? ?? const {});
      final token = meta['token']?.toString();
      if (token == null || token.isEmpty || data.isEmpty) throw const FormatException('Respons login tidak lengkap.');
      final user = AuthUser.fromLoginResponse(data);
      await _storage.saveSession(token: token, userJson: jsonEncode(user.toJson()));
      return user;
    } on DioException catch (error) {
      throw _apiClient.exceptionFrom(error);
    }
  }

  Future<AuthUser?> restoreUser() async {
    final token = await _storage.readToken();
    final userJson = await _storage.readUser();
    if (token == null || userJson == null) return null;
    try { return AuthUser.fromJson(Map<String, dynamic>.from(jsonDecode(userJson) as Map)); } catch (_) { await _storage.clear(); return null; }
  }

  Future<void> logout() => _storage.clear();
}
