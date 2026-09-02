import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import 'auth_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({required this.controller, super.key});
  final AuthController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() { _emailController.dispose(); _passwordController.dispose(); super.dispose(); }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await widget.controller.login(email: _emailController.text.trim(), password: _passwordController.text);
    if (!mounted || success) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.controller.errorMessage ?? 'Login belum berhasil.'), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 30),
      child: AutofillGroup(child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _BrandMark(), const SizedBox(height: 38),
          Text('Selamat datang', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 30)),
          const SizedBox(height: 8),
          Text('Masuk untuk mencatat laporan lembur Anda dengan lebih mudah.', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 34),
          _LoginField(
            controller: _emailController, label: 'Email', hint: 'nama@set.wapresri.go.id', icon: Icons.alternate_email_rounded,
            autofillHints: const [AutofillHints.username, AutofillHints.email], keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next,
            validator: (value) { if (value == null || value.trim().isEmpty) return 'Email wajib diisi'; if (!value.contains('@')) return 'Masukkan alamat email yang valid'; return null; },
          ),
          const SizedBox(height: 16),
          _LoginField(
            controller: _passwordController, label: 'Password', hint: 'Masukkan password Anda', icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword, autofillHints: const [AutofillHints.password], textInputAction: TextInputAction.done, onSubmitted: (_) => _login(),
            suffix: IconButton(tooltip: _obscurePassword ? 'Tampilkan password' : 'Sembunyikan password', icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
            validator: (value) => value == null || value.isEmpty ? 'Password wajib diisi' : null,
          ),
          const SizedBox(height: 26),
          AnimatedBuilder(animation: widget.controller, builder: (context, _) => PrimaryButton(label: widget.controller.isLoggingIn ? 'Memeriksa akun...' : 'Masuk ke LemburIN', icon: widget.controller.isLoggingIn ? null : Icons.arrow_forward_rounded, isLoading: widget.controller.isLoggingIn, onPressed: _login)),
          const SizedBox(height: 22),
          const _PrivacyNote(),
        ]),
      )),
    )),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 54, height: 54, decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.skyBlue, AppColors.skyBlueDark], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x2B1688E8), blurRadius: 18, offset: Offset(0, 8))]), child: const Icon(Icons.timelapse_rounded, color: Colors.white, size: 30)),
    const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('LemburIN', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 21)), const Text('Pelaporan lembur digital', style: TextStyle(color: AppColors.muted, fontSize: 12))]),
  ]);
}

class _LoginField extends StatelessWidget {
  const _LoginField({required this.controller, required this.label, required this.hint, required this.icon, required this.validator, this.autofillHints, this.keyboardType, this.textInputAction, this.obscureText = false, this.suffix, this.onSubmitted});
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final String? Function(String?) validator;
  final Iterable<String>? autofillHints;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller, validator: validator, obscureText: obscureText, autofillHints: autofillHints, keyboardType: keyboardType, textInputAction: textInputAction, onFieldSubmitted: onSubmitted,
    decoration: InputDecoration(
      labelText: label, hintText: hint, prefixIcon: Icon(icon, color: AppColors.muted), suffixIcon: suffix, filled: true, fillColor: AppColors.surface,
      labelStyle: const TextStyle(color: AppColors.muted), hintStyle: const TextStyle(color: AppColors.disabled), contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: _border(AppColors.border), enabledBorder: _border(AppColors.border), focusedBorder: _border(AppColors.skyBlue, 1.8), errorBorder: _border(AppColors.error), focusedErrorBorder: _border(AppColors.error, 1.8),
    ),
  );
  OutlineInputBorder _border(Color color, [double width = 1]) => OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: color, width: width));
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();
  @override
  Widget build(BuildContext context) => const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(Icons.verified_user_outlined, color: AppColors.muted, size: 18), SizedBox(width: 8), Expanded(child: Text('Akses Anda diamankan. Password tidak pernah disimpan di perangkat.', style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.45))),
  ]);
}
