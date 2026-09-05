class YearOvertimeSummary {
  const YearOvertimeSummary({
    required this.workdayOvertime,
    required this.holidayOvertime,
    required this.totalOvertime,
    required this.totalPay,
    this.isServerSummaryStale = false,
    this.serverSummaryUpdatedAt,
  });

  final int workdayOvertime;
  final int holidayOvertime;
  final int totalOvertime;
  final num totalPay;
  final bool isServerSummaryStale;
  final DateTime? serverSummaryUpdatedAt;

  const YearOvertimeSummary.empty()
    : workdayOvertime = 0,
      holidayOvertime = 0,
      totalOvertime = 0,
      totalPay = 0,
      isServerSummaryStale = true,
      serverSummaryUpdatedAt = null;

  factory YearOvertimeSummary.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : const <String, dynamic>{};

    return YearOvertimeSummary(
      workdayOvertime: _asInt(data['lembur_hari_kerja']),
      holidayOvertime: _asInt(data['lembur_hari_libur']),
      totalOvertime: _asInt(data['total_lembur']),
      totalPay: _asNum(data['total_upah']),
    );
  }

  static int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  static num _asNum(dynamic value) =>
      value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0;
}
