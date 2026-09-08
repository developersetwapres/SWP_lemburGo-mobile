import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';

Future<Dio> createPlatformDio(BaseOptions options) async {
  final caData = await rootBundle.load('assets/certs/ca.crt');
  final context = SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificatesBytes(caData.buffer.asUint8List());
  final dio = Dio(options);
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => HttpClient(context: context),
  );
  return dio;
}
