import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../data/auth_repository.dart';
import '../data/models/auth_user.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository);
  final AuthRepository _repository;
  AuthUser? user;
  bool isCheckingSession = true;
  bool isLoggingIn = false;
  String? errorMessage;

  Future<void> restoreSession() async {
    try {
      user = await _repository.restoreUser();
    } catch (_) {
      user = null;
    } finally {
      isCheckingSession = false;
      notifyListeners();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    isLoggingIn = true;
    errorMessage = null;
    notifyListeners();
    try {
      user = await _repository.login(email: email, password: password);
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } on FormatException {
      errorMessage = 'Respons server tidak dapat diproses. Silakan coba lagi.';
      return false;
    } finally {
      isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    user = null;
    errorMessage = null;
    notifyListeners();
  }
}
