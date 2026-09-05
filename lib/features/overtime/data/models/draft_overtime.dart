import '../../../../core/config/api_config.dart';
import '../../../../core/offline/sync_models.dart';

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
    this.localId,
    this.clientRequestId,
    this.activityPhotoLocalPath,
    this.checkoutPhotoLocalPath,
    this.activityPhotoPendingUpload = false,
    this.checkoutPhotoPendingUpload = false,
    this.localSyncState = LocalSyncState.synced,
    this.syncError,
    this.localRevision = 0,
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

  /// A permanent device identifier. It exists before Laravel has assigned a
  /// UUID and never changes when the server record is linked.
  final String? localId;
  final String? clientRequestId;
  final String? activityPhotoLocalPath;
  final String? checkoutPhotoLocalPath;
  final bool activityPhotoPendingUpload;
  final bool checkoutPhotoPendingUpload;
  final LocalSyncState localSyncState;
  final String? syncError;
  final int localRevision;

  bool get hasActivityPhoto =>
      activityPhotoUrl != null || activityPhotoLocalPath != null;
  bool get hasCheckoutPhoto =>
      checkoutPhotoUrl != null || checkoutPhotoLocalPath != null;

  bool get isLocalOnly => uuid.trim().isEmpty;

  String get normalizedStatus => normalizeStatus(status);

  bool get isFinalized => isFinalizedStatus(status);

  String get statusLabel => labelForStatus(status);

  static String normalizeStatus(String value) => value.trim().toLowerCase();

  static bool isFinalizedStatus(String value) =>
      switch (normalizeStatus(value)) {
        'locked' => true,
        _ => false,
      };

  static String labelForStatus(String value) => switch (normalizeStatus(
    value,
  )) {
    'locked' => 'TERKUNCI',
    'complete' || 'completed' => 'SELESAI',
    'draft' => 'DRAFT',
    _ => value.trim().isEmpty ? 'STATUS TIDAK DIKETAHUI' : value.toUpperCase(),
  };

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
