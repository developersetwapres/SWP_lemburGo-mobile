import 'package:flutter/material.dart';

/// The official LemburNakIT logo used throughout the application.
class AppLogo extends StatelessWidget {
  const AppLogo({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/logo.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    semanticLabel: 'Logo LemburNakIT',
  );
}
