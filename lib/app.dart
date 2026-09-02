import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/dashboard/presentation/home_page.dart';
import 'shared/widgets/app_bottom_navigation.dart';

class LemburInApp extends StatelessWidget {
  const LemburInApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LemburIN',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const AppShell(),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _selectedIndex,
      children: const [
        HomePage(),
        _ComingSoonPlaceholder(
          icon: Icons.calendar_month_rounded,
          title: 'Kalender segera hadir',
          message: 'Nantikan tampilan jadwal lembur Anda di sini.',
        ),
        _ComingSoonPlaceholder(
          icon: Icons.history_rounded,
          title: 'Riwayat segera hadir',
          message: 'Pengajuan lembur Anda akan tampil di sini.',
        ),
      ],
    ),
    bottomNavigationBar: AppBottomNavigation(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
    ),
  );
}

class _ComingSoonPlaceholder extends StatelessWidget {
  const _ComingSoonPlaceholder({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title, message;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, color: colors.primary, size: 34),
              ),
              const SizedBox(height: 20),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
