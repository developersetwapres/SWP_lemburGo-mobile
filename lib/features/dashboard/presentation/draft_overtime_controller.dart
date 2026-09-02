import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../../overtime/data/models/draft_overtime.dart';
import '../../overtime/data/overtime_repository.dart';

class DraftOvertimeController extends ChangeNotifier {
  DraftOvertimeController(this._repository);

  final OvertimeRepository _repository;
  List<DraftOvertime> drafts = const [];
  bool isLoading = true;
  String? errorMessage;

  Future<DraftLoadOutcome> load() async {
    errorMessage = null;
    notifyListeners();
    try {
      drafts = await _repository.fetchDrafts();
      return DraftLoadOutcome.success;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return error.isUnauthenticated
          ? DraftLoadOutcome.unauthenticated
          : DraftLoadOutcome.failure;
    } catch (_) {
      errorMessage = 'Draft lembur belum dapat dimuat. Silakan coba lagi.';
      return DraftLoadOutcome.failure;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

enum DraftLoadOutcome { success, unauthenticated, failure }
