import '../models/calendar_overtime.dart';

/// A single extension point for national-holiday data. The list is deliberately
/// empty until the product supplies an official holiday dataset/API.
class HolidayCalendar {
  const HolidayCalendar({this.nationalHolidayKeys = const {}});

  final Set<String> nationalHolidayKeys;

  bool isNationalHoliday(DateTime date) =>
      nationalHolidayKeys.contains(CalendarOvertime.dateKeyFor(date));

  bool isWeekend(DateTime date) => date.weekday == DateTime.sunday;

  bool isHoliday(DateTime date) => isWeekend(date) || isNationalHoliday(date);
}
