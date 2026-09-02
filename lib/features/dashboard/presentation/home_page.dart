import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/data/models/auth_user.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.user, required this.onStart, super.key});
  final AuthUser user;
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _WelcomeHeader(userName: user.name),
              const SizedBox(height: 28),
              _TodayOvertimeCard(onStart: onStart),
              const SizedBox(height: 30),
              const SectionHeader(
                title: 'Ringkasan Lembur',
                subtitle: 'September 2026',
              ),
              const SizedBox(height: 14),
              const _OvertimeSummary(),
              const SizedBox(height: 28),
              const _ActivityHint(),
            ]),
          ),
        ),
      ],
    ),
  );
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.userName});
  final String userName;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_greeting(), style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 2),
            Text(userName, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 15,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 7),
                Text(
                  _todayLabel(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.skyBlue, AppColors.skyBlueDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(17),
          boxShadow: const [
            BoxShadow(
              color: Color(0x331688E8),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            userName.isEmpty ? 'U' : userName.substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ],
  );

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi,';
    if (hour < 15) return 'Selamat siang,';
    if (hour < 18) return 'Selamat sore,';
    return 'Selamat malam,';
  }

  String _todayLabel() {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

class _TodayOvertimeCard extends StatelessWidget {
  const _TodayOvertimeCard({required this.onStart});
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1688E8), Color(0xFF0870C8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(26),
      boxShadow: const [
        BoxShadow(
          color: Color(0x301688E8),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(99),
          ),
          child: const Text(
            'STATUS HARI INI',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: .7,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Belum ada lembur hari ini',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Catat kegiatan lembur Anda dengan mudah.',
          style: TextStyle(color: Color(0xFFE6F4FF), fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Mulai Lembur'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.skyBlueDark,
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _OvertimeSummary extends StatelessWidget {
  const _OvertimeSummary();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cards = const [
        _SummaryCard(
          icon: Icons.timer_outlined,
          label: 'Total bulan ini',
          value: '12 jam',
          tint: AppColors.skyBlueLight,
          iconColor: AppColors.skyBlue,
        ),
        _SummaryCard(
          icon: Icons.check_circle_outline_rounded,
          label: 'Status hari ini',
          value: 'Belum ada',
          tint: AppColors.warningLight,
          iconColor: AppColors.warning,
        ),
      ];
      return constraints.maxWidth >= 360
          ? Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
              ],
            )
          : Column(children: [cards[0], const SizedBox(height: 12), cards[1]]);
    },
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
    required this.iconColor,
  });
  final IconData icon;
  final String label, value;
  final Color tint, iconColor;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 16),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

class _ActivityHint extends StatelessWidget {
  const _ActivityHint();
  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.successLight,
    padding: const EdgeInsets.all(17),
    child: Row(
      children: [
        const Icon(
          Icons.lightbulb_outline_rounded,
          color: AppColors.success,
          size: 24,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            'Lengkapi foto kegiatan dan presensi pulang setelah lembur selesai.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.navy),
          ),
        ),
      ],
    ),
  );
}
