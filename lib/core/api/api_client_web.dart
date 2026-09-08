import 'package:dio/dio.dart';

/// Browser transport deliberately relies on browser TLS and CORS enforcement.
Future<Dio> createPlatformDio(BaseOptions options) async => Dio(options);
