import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final Future<SecurityContext> _securityContext = _createSecurityContext();

Future<SecurityContext> _createSecurityContext() async {
  final caData = await rootBundle.load('assets/certs/ca.crt');
  final context = SecurityContext(withTrustedRoots: false);
  context.setTrustedCertificatesBytes(caData.buffer.asUint8List());
  return context;
}

Future<Uint8List> _loadRemoteImage(String url) async {
  final client = HttpClient(context: await _securityContext);
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Image request failed: ${response.statusCode}');
    }
    final bytes = await response.fold<List<int>>(<int>[], (bytes, chunk) {
      bytes.addAll(chunk);
      return bytes;
    });
    return Uint8List.fromList(bytes);
  } finally {
    client.close(force: true);
  }
}

class RemoteImage extends StatelessWidget {
  const RemoteImage({
    required this.url,
    required this.fit,
    required this.error,
    this.loading,
    super.key,
  });

  final String url;
  final BoxFit fit;
  final Widget error;
  final Widget? loading;

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _loadRemoteImage(url),
    builder: (context, snapshot) {
      if (snapshot.hasError) return error;
      final bytes = snapshot.data;
      if (bytes == null) return loading ?? const SizedBox.shrink();
      return Image.memory(bytes, fit: fit, errorBuilder: (_, _, _) => error);
    },
  );
}
