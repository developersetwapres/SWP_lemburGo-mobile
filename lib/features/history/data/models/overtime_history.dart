import '../../../overtime/data/models/draft_overtime.dart';

class OvertimeHistory {
  const OvertimeHistory({
    required this.records,
    required this.month,
    required this.totalUpah,
    required this.totalOvertime,
    required this.workdayOvertime,
    required this.holidayOvertime,
    this.isServerSummaryStale = false,
    this.serverSummaryUpdatedAt,
  });

  final List<DraftOvertime> records;
  final int month;
  final num totalUpah;
  final int totalOvertime;
  final int workdayOvertime;
  final int holidayOvertime;

  /// Totals for pay remain server-authoritative. Offline screens show the
  /// latest cached value and can identify when none is available yet.
  final bool isServerSummaryStale;
  final DateTime? serverSummaryUpdatedAt;

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
                  (item) =>
                      DraftOvertime.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      month: _month(meta['bulan']),
      totalUpah: _number(meta['total_upah']),
      totalOvertime: _integer(meta['total_lembur']),
      workdayOvertime: _integer(meta['lembur_hari_kerja']),
      holidayOvertime: _integer(meta['lembur_hari_libur']),
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

  static int _integer(Object? value) =>
      int.tryParse(value?.toString() ?? '') ?? 0;
}
