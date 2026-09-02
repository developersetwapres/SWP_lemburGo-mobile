import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/data/models/auth_user.dart';
import '../../overtime/data/models/draft_overtime.dart';
import '../../overtime/data/overtime_repository.dart';
import 'draft_overtime_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.user,
    required this.repository,
    required this.onStart,
    required this.onContinue,
    required this.onSessionExpired,
    super.key,
  });

  final AuthUser user;
  final OvertimeRepository repository;
  final Future<bool> Function() onStart;
  final Future<bool> Function(DraftOvertime draft) onContinue;
  final Future<void> Function() onSessionExpired;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final DraftOvertimeController _draftController;

  @override
  void initState() {
    super.initState();
    _draftController = DraftOvertimeController(widget.repository);
    _loadDrafts();
  }

  @override
  void dispose() {
    _draftController.dispose();
    super.dispose();
  }

  Future<void> _loadDrafts() async {
    final outcome = await _draftController.load();
    if (mounted && outcome == DraftLoadOutcome.unauthenticated) {
      await widget.onSessionExpired();
    }
  }

  Future<void> _startOvertime() async {
    final saved = await widget.onStart();
    if (saved && mounted) await _loadDrafts();
  }

  Future<void> _continueDraft(DraftOvertime draft) async {
    final saved = await widget.onContinue(draft);
    if (saved && mounted) await _loadDrafts();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: AnimatedBuilder(
      animation: _draftController,
      builder: (context, _) => RefreshIndicator(
        color: AppColors.skyBlue,
        onRefresh: _loadDrafts,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _WelcomeHeader(userName: widget.user.name),
                  const SizedBox(height: 28),
                  _TodayOvertimeCard(onStart: _startOvertime),
                  const SizedBox(height: 30),
                  _DraftSection(
                    controller: _draftController,
                    onContinue: _continueDraft,
                    onRetry: _loadDrafts,
                  ),
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
      ),
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
                const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.muted),
                const SizedBox(width: 7),
                Text(_todayLabel(), style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.skyBlue, AppColors.skyBlueDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(17),
          boxShadow: const [BoxShadow(color: Color(0x331688E8), blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: Center(child: Text(userName.isEmpty ? 'U' : userName.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
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

  String _todayLabel() => DateFormat('EEEE, d MMMM y', 'id_ID').format(DateTime.now());
}

class _TodayOvertimeCard extends StatelessWidget {
  const _TodayOvertimeCard({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF1688E8), Color(0xFF0870C8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(26),
      boxShadow: const [BoxShadow(color: Color(0x301688E8), blurRadius: 24, offset: Offset(0, 12))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(99)), child: const Text('STATUS HARI INI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: .7))),
        const SizedBox(height: 18),
        const Text('Belum ada lembur hari ini', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -.4)),
        const SizedBox(height: 8),
        const Text('Catat kegiatan lembur Anda dengan mudah.', style: TextStyle(color: Color(0xFFE6F4FF), fontSize: 14, height: 1.4)),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Mulai Lembur'),
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.skyBlueDark, minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
      ],
    ),
  );
}

class _DraftSection extends StatelessWidget {
  const _DraftSection({required this.controller, required this.onContinue, required this.onRetry});
  final DraftOvertimeController controller;
  final ValueChanged<DraftOvertime> onContinue;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading) return const _DraftSkeleton();
    if (controller.errorMessage != null) {
      return _DraftError(message: controller.errorMessage!, onRetry: onRetry);
    }
    if (controller.drafts.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Lembur Belum Selesai',
            subtitle: 'Tidak ada draft yang perlu dilengkapi',
          ),
          SizedBox(height: 14),
          _DraftEmpty(),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Lembur Belum Selesai', subtitle: '${controller.drafts.length} draft perlu dilengkapi'),
        const SizedBox(height: 14),
        ...controller.drafts.map((draft) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _DraftCard(draft: draft, onContinue: () => onContinue(draft)))),
      ],
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.draft, required this.onContinue});
  final DraftOvertime draft;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onContinue,
    borderRadius: BorderRadius.circular(22),
    child: AppCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.skyBlueLight, borderRadius: BorderRadius.circular(13)), child: Text(DateFormat('dd\nMMM', 'id_ID').format(draft.activityDate).toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.skyBlue, fontSize: 10, fontWeight: FontWeight.w800, height: 1.1))),
              const SizedBox(width: 11),
              Expanded(child: Text(DateFormat('d MMMM y', 'id_ID').format(draft.activityDate), style: Theme.of(context).textTheme.titleSmall)),
              _DraftStatusChip(status: draft.status),
            ],
          ),
          const SizedBox(height: 15),
          Text(draft.activityName, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(children: [const Icon(Icons.location_on_outlined, color: AppColors.muted, size: 17), const SizedBox(width: 5), Expanded(child: Text(draft.location, style: Theme.of(context).textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis))]),
          const SizedBox(height: 17),
          _DraftProgress(draft: draft),
          const SizedBox(height: 14),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: onContinue, icon: const Icon(Icons.arrow_forward_rounded, size: 18), label: const Text('Lanjutkan'))),
        ],
      ),
    ),
  );
}

class _DraftStatusChip extends StatelessWidget {
  const _DraftStatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(99)),
    child: Text(status.toUpperCase(), style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: .4)),
  );
}

class _DraftProgress extends StatelessWidget {
  const _DraftProgress({required this.draft});
  final DraftOvertime draft;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: _ProgressStep(label: 'Data', complete: true)),
      Expanded(child: _ProgressStep(label: 'Kegiatan', complete: draft.hasActivityPhoto)),
      Expanded(child: _ProgressStep(label: 'Pulang', complete: draft.hasCheckoutPhoto, last: true)),
    ],
  );
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({required this.label, required this.complete, this.last = false});
  final String label;
  final bool complete;
  final bool last;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(complete ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 17, color: complete ? AppColors.success : AppColors.muted),
      const SizedBox(width: 4),
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: complete ? AppColors.navy : AppColors.muted))),
      if (!last) const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Icon(Icons.chevron_right_rounded, size: 15, color: AppColors.border)),
    ],
  );
}

class _DraftSkeleton extends StatelessWidget {
  const _DraftSkeleton();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader(title: 'Lembur Belum Selesai', subtitle: 'Memuat draft Anda...'),
      const SizedBox(height: 14),
      AppCard(color: AppColors.surface, padding: const EdgeInsets.all(18), child: const SizedBox(height: 150, child: _ShimmerPlaceholder())),
    ],
  );
}

class _ShimmerPlaceholder extends StatelessWidget {
  const _ShimmerPlaceholder();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 100, height: 16, decoration: _box()), const SizedBox(height: 22), Container(width: double.infinity, height: 19, decoration: _box()), const SizedBox(height: 10), Container(width: 180, height: 14, decoration: _box()), const Spacer(), Container(width: double.infinity, height: 12, decoration: _box())]);
  BoxDecoration _box() => BoxDecoration(color: AppColors.skyBlueLight, borderRadius: BorderRadius.circular(99));
}

class _DraftEmpty extends StatelessWidget {
  const _DraftEmpty();
  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.successLight,
    padding: const EdgeInsets.all(18),
    child: const Row(children: [Icon(Icons.task_alt_rounded, color: AppColors.success, size: 28), SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Tidak ada lembur yang perlu dilengkapi', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('Mulai lembur baru kapan pun Anda membutuhkannya.', style: TextStyle(color: AppColors.navy, height: 1.35))]))]),
  );
}

class _DraftError extends StatelessWidget {
  const _DraftError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.errorLight,
    padding: const EdgeInsets.all(18),
    child: Row(children: [const Icon(Icons.cloud_off_outlined, color: AppColors.error, size: 27), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Draft belum dapat dimuat', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(message, style: const TextStyle(color: AppColors.navy, height: 1.3)), TextButton(onPressed: onRetry, child: const Text('Coba lagi'))]))]),
  );
}

class _OvertimeSummary extends StatelessWidget {
  const _OvertimeSummary();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cards = const [
        _SummaryCard(icon: Icons.timer_outlined, label: 'Total bulan ini', value: '12 jam', tint: AppColors.skyBlueLight, iconColor: AppColors.skyBlue),
        _SummaryCard(icon: Icons.check_circle_outline_rounded, label: 'Status hari ini', value: 'Belum ada', tint: AppColors.warningLight, iconColor: AppColors.warning),
      ];
      return constraints.maxWidth >= 360 ? Row(children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])]) : Column(children: [cards[0], const SizedBox(height: 12), cards[1]]);
    },
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.icon, required this.label, required this.value, required this.tint, required this.iconColor});
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final Color iconColor;
  @override
  Widget build(BuildContext context) => AppCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: 20)), const SizedBox(height: 16), Text(value, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 2), Text(label, style: Theme.of(context).textTheme.bodyMedium)]));
}

class _ActivityHint extends StatelessWidget {
  const _ActivityHint();
  @override
  Widget build(BuildContext context) => AppCard(color: AppColors.successLight, padding: const EdgeInsets.all(17), child: Row(children: [const Icon(Icons.lightbulb_outline_rounded, color: AppColors.success, size: 24), const SizedBox(width: 13), Expanded(child: Text('Simpan informasi kegiatan terlebih dahulu, lalu lengkapi foto saat Anda siap.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.navy)))]));
}
