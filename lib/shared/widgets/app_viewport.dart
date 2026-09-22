import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Keeps the Web app, including Navigator routes and overlays, mobile-first.
class AppViewport extends StatelessWidget {
  const AppViewport({required this.child, super.key});

  // Matches the existing login form's comfortable single-column width.
  static const double maxWidth = 520;

  final Widget child;

  static Widget builder(BuildContext context, Widget? child) =>
      AppViewport(child: child ?? const SizedBox.shrink());

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: LayoutBuilder(
            builder: (context, constraints) => MediaQuery(
              // Routes must see the same size as their actual layout area.
              // Preserve keyboard insets, safe areas, and accessibility data.
              data: MediaQuery.of(context).copyWith(size: constraints.biggest),
              child: ClipRect(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
