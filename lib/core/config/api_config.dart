abstract final class ApiConfig {
  static const baseUrl = 'https://10.1.3.86/api'; //Final
  // static const baseUrl = 'http://10.0.2.2:8000/api'; //Pixel 8
  // static const baseUrl = 'http://10.1.53.20:8000/api';  //Sesama wlan
  // static const baseUrl = 'http://127.0.0.1:8000/api';   // db
  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 30);

  static String resolveRemoteUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    return Uri.parse(baseUrl).resolve(value).toString();
  }
}
