import '../../../../core/config/api_config.dart';

class DraftOvertime {
  const DraftOvertime({
    required this.id,
    required this.uuid,
    required this.activityDate,
    required this.activityName,
    required this.location,
    required this.status,
    this.activityPhotoUrl,
    this.activityPhotoAt,
    this.checkoutPhotoUrl,
    this.checkoutPhotoAt,
    this.checkoutTime,
  });

  final String id;
  final String uuid;
  final DateTime activityDate;
  final String activityName;
  final String location;
  final String status;
  final String? activityPhotoUrl;
  final DateTime? activityPhotoAt;
  final String? checkoutPhotoUrl;
  final DateTime? checkoutPhotoAt;
  final DateTime? checkoutTime;

  bool get hasActivityPhoto => activityPhotoUrl != null;
  bool get hasCheckoutPhoto => checkoutPhotoUrl != null;

  factory DraftOvertime.fromJson(Map<String, dynamic> json) {
    final attributes = Map<String, dynamic>.from(
      json['attributes'] as Map? ?? const <String, dynamic>{},
    );
    return DraftOvertime(
      id: json['id']?.toString() ?? '',
      uuid: attributes['uuid']?.toString() ?? '',
      activityDate: _dateOnly(attributes['tanggal_kegiatan']?.toString()),
      activityName: attributes['nama_kegiatan']?.toString() ?? '',
      location: attributes['lokasi_kegiatan']?.toString() ?? '',
      status: attributes['status']?.toString() ?? 'draft',
      activityPhotoUrl: _remoteUrl(attributes['foto_kegiatan']),
      activityPhotoAt: _nullableDate(attributes['foto_kegiatan_at']),
      checkoutPhotoUrl: _remoteUrl(attributes['foto_pulang']),
      checkoutPhotoAt: _nullableDate(attributes['foto_pulang_at']),
      checkoutTime: _nullableDate(attributes['waktu_pulang']),
    );
  }

  static String? _nullableString(Object? value) {
    final result = value?.toString().trim();
    return result == null || result.isEmpty ? null : result;
  }

  static String? _remoteUrl(Object? value) {
    final raw = _nullableString(value);
    return raw == null ? null : ApiConfig.resolveRemoteUrl(raw);
  }

  static DateTime _dateOnly(String? value) {
    final parsed = _nullableDate(value);
    if (parsed == null) return DateTime.now();
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime? _nullableDate(Object? value) {
    final raw = _nullableString(value);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }
}
