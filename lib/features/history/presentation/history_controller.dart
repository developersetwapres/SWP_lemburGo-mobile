import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../data/models/overtime_history.dart';
import '../../overtime/data/overtime_repository.dart';

class HistoryController extends ChangeNotifier {
  HistoryController(this._repository);

  final OvertimeRepository _repository;
  OvertimeHistory? history;
  String? errorMessage;
  bool isLoading = true;
  bool isFiltering = false;
  int? _requestedMonth;

  int get selectedMonth => _requestedMonth ?? history?.month ?? DateTime.now().month;

  Future<HistoryLoadOutcome> load({int? month, bool showSkeleton = false}) async {
    _requestedMonth = month ?? _requestedMonth;
    if (showSkeleton) {
      isLoading = true;
    } else {
      isFiltering = true;
    }
    errorMessage = null;
    notifyListeners();
    try {
      history = await _repository.fetchHistory(month: month);
      _requestedMonth = history!.month;
      return HistoryLoadOutcome.success;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return error.isUnauthenticated
          ? HistoryLoadOutcome.unauthenticated
          : HistoryLoadOutcome.failure;
    } catch (_) {
      errorMessage = 'Riwayat lembur belum dapat dimuat. Silakan coba lagi.';
      return HistoryLoadOutcome.failure;
    } finally {
      isLoading = false;
      isFiltering = false;
      notifyListeners();
    }
  }

  Future<HistoryLoadOutcome> refresh() => load(month: selectedMonth);
}

enum HistoryLoadOutcome { success, unauthenticated, failure }
