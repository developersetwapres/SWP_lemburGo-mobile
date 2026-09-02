import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final colors = ColorScheme.fromSeed(
      seedColor: AppColors.skyBlue,
      primary: AppColors.skyBlue,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.navy,
      error: AppColors.error,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
        ),
        titleLarge: TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: AppColors.navy, height: 1.45),
        bodyMedium: TextStyle(color: AppColors.muted, height: 1.45),
        labelLarge: TextStyle(fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
