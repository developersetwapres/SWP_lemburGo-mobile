import 'package:flutter/material.dart';

/// Browser image loading intentionally uses the browser networking stack. CORS,
/// HTTPS certificate validation and Authorization-compatible URLs are enforced
/// by the browser rather than bypassed with a custom HttpClient.
class RemoteImage extends StatelessWidget {
  const RemoteImage({required this.url, required this.fit, required this.error, this.loading, super.key});
  final String url; final BoxFit fit; final Widget error; final Widget? loading;
  @override
  Widget build(BuildContext context) => Image.network(
    url,
    fit: fit,
    loadingBuilder: (_, child, progress) => progress == null ? child : (loading ?? const SizedBox.shrink()),
    errorBuilder: (_, _, _) => error,
  );
}
