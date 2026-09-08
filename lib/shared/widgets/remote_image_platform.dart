import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final Future<SecurityContext> _securityContext = _createSecurityContext();
Future<SecurityContext> _createSecurityContext() async {
  final bytes = await rootBundle.load('assets/certs/ca.crt');
  return SecurityContext(withTrustedRoots: false)..setTrustedCertificatesBytes(bytes.buffer.asUint8List());
}
Future<Uint8List> _load(String url) async {
  final client = HttpClient(context: await _securityContext);
  try {
    final response = await (await client.getUrl(Uri.parse(url))).close().timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) throw HttpException('Image request failed: ${response.statusCode}');
    return Uint8List.fromList(await response.fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk)));
  } finally { client.close(force: true); }
}
class RemoteImage extends StatelessWidget {
  const RemoteImage({required this.url, required this.fit, required this.error, this.loading, super.key});
  final String url; final BoxFit fit; final Widget error; final Widget? loading;
  @override Widget build(BuildContext context) => FutureBuilder<Uint8List>(future: _load(url), builder: (_, snapshot) { if (snapshot.hasError) return error; final bytes = snapshot.data; if (bytes == null) return loading ?? const SizedBox.shrink(); return Image.memory(bytes, fit: fit, errorBuilder: (_, _, _) => error); });
}
