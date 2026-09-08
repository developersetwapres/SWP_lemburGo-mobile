abstract final class ApiConfig {
  /// Configure a full endpoint with `--dart-define=API_BASE_URL=...`.
  /// Same-origin Web deployments can keep the safe `/api` default.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://10.1.3.86/api',
  );

  /// Optional browser-compatible reverse-geocoding endpoint. It receives
  /// `lat`/`lng` and returns `road`, `districtCity`, and `province`.
  static const reverseGeocodingUrl = String.fromEnvironment(
    'REVERSE_GEOCODING_URL',
  );
  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 30);

  static String resolveRemoteUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    return Uri.parse(baseUrl).resolve(value).toString();
  }
}
