class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode, this.fieldErrors = const {}});
  final String message;
  final int? statusCode;
  final Map<String, List<String>> fieldErrors;

  bool get isUnauthenticated => statusCode == 401;
  @override
  String toString() => message;
}
