import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<String?> readUser() => _storage.read(key: _userKey);

  Future<void> saveSession({required String token, required String userJson}) =>
      _storage
          .write(key: _tokenKey, value: token)
          .then((_) => _storage.write(key: _userKey, value: userJson));

  Future<void> clear() => _storage.deleteAll();
}
