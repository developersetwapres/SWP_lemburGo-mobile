import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../../overtime/data/overtime_repository.dart';
import '../../overtime/data/models/draft_overtime.dart';
import '../data/models/calendar_overtime.dart';

class CalendarController extends ChangeNotifier {
  CalendarController(this._repository);

  final OvertimeRepository _repository;
  Map<String, CalendarOvertime> entriesByDate = const {};
  bool isLoading = true;
  bool isOpeningDetail = false;
  String? errorMessage;

  Future<CalendarLoadOutcome> load({bool showSkeleton = false}) async {
    if (showSkeleton) isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final entries = await _repository.fetchCalendarEntries();
      entriesByDate = {
        for (final entry in entries)
          if (entry.overtimeId > 0) entry.dateKey: entry,
      };
      return CalendarLoadOutcome.success;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return error.isUnauthenticated
          ? CalendarLoadOutcome.unauthenticated
          : CalendarLoadOutcome.failure;
    } catch (_) {
      errorMessage = 'Kalender lembur belum dapat dimuat. Silakan coba lagi.';
      return CalendarLoadOutcome.failure;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  CalendarOvertime? entryFor(DateTime date) =>
      entriesByDate[CalendarOvertime.dateKeyFor(date)];

  /// Details are loaded on demand for the one item the user explicitly asked
  /// to inspect.
  Future<CalendarDetailResult> loadDetail(CalendarOvertime entry) async {
    isOpeningDetail = true;
    notifyListeners();
    try {
      if (entry.uuid.isEmpty) {
        return const CalendarDetailResult.error(
          message: 'UUID lembur tidak tersedia dari data kalender.',
        );
      }
      return CalendarDetailResult.record(
        await _repository.fetchDetail(entry.uuid),
      );
    } on ApiException catch (error) {
      return CalendarDetailResult.error(
        message: error.message,
        unauthenticated: error.isUnauthenticated,
      );
    } catch (_) {
      return const CalendarDetailResult.error(
        message: 'Detail lembur belum dapat dimuat. Silakan coba lagi.',
      );
    } finally {
      isOpeningDetail = false;
      notifyListeners();
    }
  }
}

enum CalendarLoadOutcome { success, unauthenticated, failure }

class CalendarDetailResult {
  const CalendarDetailResult({
    this.record,
    this.message,
    this.unauthenticated = false,
  });

  const CalendarDetailResult.record(DraftOvertime record)
    : this(record: record);
  const CalendarDetailResult.notFound() : this();
  const CalendarDetailResult.error({
    required String message,
    bool unauthenticated = false,
  }) : this(message: message, unauthenticated: unauthenticated);

  final DraftOvertime? record;
  final String? message;
  final bool unauthenticated;
}
