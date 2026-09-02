import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/calendar_overtime.dart';
import '../../data/services/holiday_calendar.dart';

class CalendarMonthGrid extends StatelessWidget {
  const CalendarMonthGrid({
    required this.month,
    required this.selectedDate,
    required this.entriesByDate,
    required this.holidayCalendar,
    required this.onDateSelected,
    super.key,
  });

  final DateTime month;
  final DateTime selectedDate;
  final Map<String, CalendarOvertime> entriesByDate;
  final HolidayCalendar holidayCalendar;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final leadingCells = firstDay.weekday - DateTime.monday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cellCount = ((leadingCells + daysInMonth + 6) ~/ 7) * 7;

    return Column(
      children: [
        const _WeekdayHeader(),
        const SizedBox(height: 7),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cellCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 5,
            crossAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            final day = index - leadingCells + 1;
            if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
            final date = DateTime(month.year, month.month, day);
            return _DayCell(
              date: date,
              isSelected: _isSameDate(date, selectedDate),
              isToday: _isSameDate(date, DateTime.now()),
              hasOvertime: entriesByDate.containsKey(
                CalendarOvertime.dateKeyFor(date),
              ),
              isHoliday: holidayCalendar.isHoliday(date),
              onTap: () => onDateSelected(date),
            );
          },
        ),
      ],
    );
  }

  bool _isSameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();
  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) => Row(
    children: _days
        .map(
          (day) => Expanded(
            child: Center(
              child: Text(
                day,
                style: TextStyle(
                  color: day == 'Min' ? AppColors.holiday : AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        )
        .toList(),
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.hasOvertime,
    required this.isHoliday,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool hasOvertime;
  final bool isHoliday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(15),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.skyBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        border: isToday && !isSelected
            ? Border.all(color: AppColors.skyBlue, width: 1.4)
            : isToday && isSelected
            ? Border.all(color: Colors.white, width: 1.4)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            date.day.toString(),
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : isHoliday
                  ? AppColors.holiday
                  : AppColors.navy,
              fontWeight: isToday || isSelected
                  ? FontWeight.w800
                  : FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: hasOvertime ? 1 : 0,
            child: Container(
              height: 5,
              width: 5,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : AppColors.skyBlue,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
