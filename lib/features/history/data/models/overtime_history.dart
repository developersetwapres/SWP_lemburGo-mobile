import '../../../overtime/data/models/draft_overtime.dart';

class OvertimeHistory {
  const OvertimeHistory({
    required this.records,
    required this.month,
    required this.totalUpah,
  });

  final List<DraftOvertime> records;
  final int month;
  final num totalUpah;

  factory OvertimeHistory.fromJson(Map<String, dynamic> json) {
    final rawRecords = json['data'];
    final meta = Map<String, dynamic>.from(
      json['meta'] as Map? ?? const <String, dynamic>{},
    );
    return OvertimeHistory(
      records: rawRecords is List
          ? rawRecords
                .whereType<Map>()
                .map(
                  (item) => DraftOvertime.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      month: _month(meta['bulan']),
      totalUpah: _number(meta['total_upah']),
    );
  }

  static int _month(Object? value) {
    final month = int.tryParse(value?.toString() ?? '');
    return month != null && month >= 1 && month <= 12
        ? month
        : DateTime.now().month;
  }

  static num _number(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }
}
