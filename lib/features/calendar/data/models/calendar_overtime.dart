class CalendarOvertime {
  const CalendarOvertime({
    required this.date,
    required this.overtimeId,
    required this.uuid,
    this.localId,
  });

  /// Calendar dates are intentionally parsed as local date-only values.
  final DateTime date;
  final int overtimeId;
  final String uuid;

  /// Used for records created offline before Laravel has returned a UUID.
  final String? localId;

  String get dateKey => dateKeyFor(date);

  factory CalendarOvertime.fromJson(Map<String, dynamic> json) {
    return CalendarOvertime(
      date: parseDateOnly(json['tanggal']?.toString()),
      overtimeId: int.tryParse(json['lembur_id']?.toString() ?? '') ?? 0,
      uuid: _uuid(json),
    );
  }

  static String _uuid(Map<String, dynamic> json) {
    final attributes = json['attributes'];
    final nestedUuid = attributes is Map ? attributes['uuid'] : null;
    return (json['uuid'] ?? json['lembur_uuid'] ?? nestedUuid)
            ?.toString()
            .trim() ??
        '';
  }

  static DateTime parseDateOnly(String? value) {
    final parts = value?.split('-') ?? const [];
    if (parts.length == 3) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.now();
  }

  static String dateKeyFor(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
