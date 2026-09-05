import 'dart:async';

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
  bool _reloadScheduled = false;

  void startListening() => _repository.addListener(_onRepositoryChanged);

  void _onRepositoryChanged() {
    if (_reloadScheduled) return;
    _reloadScheduled = true;
    scheduleMicrotask(() async {
      _reloadScheduled = false;
      await load();
    });
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }

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
