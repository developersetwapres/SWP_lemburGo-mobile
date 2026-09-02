import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    super.key,
    this.errorText,
    this.onChanged,
    this.textInputAction,
  });
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    textInputAction: textInputAction,
    cursorColor: AppColors.skyBlue,
    style: Theme.of(context).textTheme.bodyLarge,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      floatingLabelStyle: const TextStyle(color: AppColors.skyBlue),
      labelStyle: const TextStyle(color: AppColors.muted),
      hintStyle: const TextStyle(color: AppColors.disabled),
      prefixIcon: Icon(icon, color: AppColors.muted),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: _border(AppColors.border),
      enabledBorder: _border(AppColors.border),
      focusedBorder: _border(AppColors.skyBlue, 1.8),
      errorBorder: _border(AppColors.error),
      focusedErrorBorder: _border(AppColors.error, 1.8),
    ),
  );
  OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: width),
      );
}
