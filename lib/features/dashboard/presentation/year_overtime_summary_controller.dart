import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../../overtime/data/models/year_overtime_summary.dart';
import '../../overtime/data/overtime_repository.dart';

class YearOvertimeSummaryController extends ChangeNotifier {
  YearOvertimeSummaryController(this._repository);

  final OvertimeRepository _repository;

  YearOvertimeSummary? summary;
  bool isLoading = true;
  String? errorMessage;

  Future<YearSummaryLoadOutcome> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      summary = await _repository.fetchYearOvertimeSummary();
      return YearSummaryLoadOutcome.success;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return error.isUnauthenticated
          ? YearSummaryLoadOutcome.unauthenticated
          : YearSummaryLoadOutcome.failure;
    } catch (_) {
      errorMessage = 'Ringkasan lembur belum dapat dimuat. Silakan coba lagi.';
      return YearSummaryLoadOutcome.failure;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

enum YearSummaryLoadOutcome { success, unauthenticated, failure }
