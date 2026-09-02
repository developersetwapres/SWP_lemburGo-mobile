import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A25405F),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}
