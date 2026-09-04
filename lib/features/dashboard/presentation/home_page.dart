import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/data/models/auth_user.dart';
import '../../overtime/data/models/draft_overtime.dart';
import '../../overtime/data/models/year_overtime_summary.dart';
import '../../overtime/data/overtime_repository.dart';
import 'draft_overtime_controller.dart';
import 'year_overtime_summary_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.user,
    required this.repository,
    required this.onStart,
    required this.onContinue,
    required this.onLogout,
    required this.onSessionExpired,
    super.key,
  });

  final AuthUser user;
  final OvertimeRepository repository;
  final Future<bool> Function() onStart;
  final Future<bool> Function(DraftOvertime draft) onContinue;
  final Future<void> Function() onLogout;
  final Future<void> Function() onSessionExpired;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final DraftOvertimeController _draftController;
  late final YearOvertimeSummaryController _yearSummaryController;

  @override
  void initState() {
    super.initState();
    _draftController = DraftOvertimeController(widget.repository);
    _yearSummaryController = YearOvertimeSummaryController(widget.repository);
    _loadDrafts();
    _loadYearSummary();
  }

  @override
  void dispose() {
    _draftController.dispose();
    _yearSummaryController.dispose();
    super.dispose();
  }

  Future<void> _loadDrafts() async {
    final outcome = await _draftController.load();
    if (mounted && outcome == DraftLoadOutcome.unauthenticated) {
      await widget.onSessionExpired();
    }
  }

  Future<void> _loadYearSummary() async {
    final outcome = await _yearSummaryController.load();
    if (mounted && outcome == YearSummaryLoadOutcome.unauthenticated) {
      await widget.onSessionExpired();
    }
  }

  Future<void> _refreshHome() async {
    await _loadDrafts();
    if (mounted) await _loadYearSummary();
  }

  Future<void> _startOvertime() async {
    final saved = await widget.onStart();
    if (saved && mounted) await _refreshHome();
  }

  Future<void> _continueDraft(DraftOvertime draft) async {
    final saved = await widget.onContinue(draft);
    if (saved && mounted) await _refreshHome();
  }

  Future<void> _showAccountSheet() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _AccountSheet(user: widget.user, onLogout: widget.onLogout),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: AnimatedBuilder(
      animation: Listenable.merge([_draftController, _yearSummaryController]),
      builder: (context, _) => RefreshIndicator(
        color: AppColors.skyBlue,
        onRefresh: _refreshHome,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _WelcomeHeader(
                    userName: widget.user.name,
                    onProfileTap: _showAccountSheet,
                  ),
                  const SizedBox(height: 28),
                  _TodayOvertimeCard(onStart: _startOvertime),
                  const SizedBox(height: 16),
                  const _ActivityHint(),
                  const SizedBox(height: 30),
                  _DraftSection(
                    controller: _draftController,
                    onContinue: _continueDraft,
                    onRetry: _loadDrafts,
                  ),
                  const SizedBox(height: 30),
                  const SectionHeader(
                    title: 'Ringkasan Lembur Tahun Ini',
                    subtitle: 'Gambaran lembur sepanjang tahun berjalan',
                  ),
                  const SizedBox(height: 14),
                  _YearOvertimeSummarySection(
                    summary: _yearSummaryController.summary,
                    isLoading: _yearSummaryController.isLoading,
                    errorMessage: _yearSummaryController.errorMessage,
                    onRetry: _loadYearSummary,
                  ),
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
  const _WelcomeHeader({required this.userName, required this.onProfileTap});
  final String userName;
  final VoidCallback onProfileTap;

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
      Semantics(
        button: true,
        label: 'Buka menu akun',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(17),
            child: Container(
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
                  userName.isEmpty
                      ? 'U'
                      : userName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
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

  String _todayLabel() =>
      DateFormat('EEEE, d MMMM y', 'id_ID').format(DateTime.now());
}

class _AccountSheet extends StatefulWidget {
  const _AccountSheet({required this.user, required this.onLogout});

  final AuthUser user;
  final Future<void> Function() onLogout;

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  bool _isLoggingOut = false;

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: AppColors.skyBlue),
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Anda perlu masuk kembali untuk mengakses laporan lembur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    await widget.onLogout();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.skyBlueLight,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Text(
                  widget.user.name.isEmpty
                      ? 'U'
                      : widget.user.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.skyBlue,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Divider(height: 1),
          const SizedBox(height: 10),
          ListTile(
            enabled: !_isLoggingOut,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text(
              'Keluar dari akun',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: const Text('Akhiri sesi pada perangkat ini'),
            trailing: _isLoggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right_rounded),
            onTap: _confirmLogout,
          ),
        ],
      ),
    ),
  );
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

class _DraftSection extends StatelessWidget {
  const _DraftSection({
    required this.controller,
    required this.onContinue,
    required this.onRetry,
  });
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
        SectionHeader(
          title: 'Lembur Belum Selesai',
          subtitle: '${controller.drafts.length} draft perlu dilengkapi',
        ),
        const SizedBox(height: 14),
        ...controller.drafts.map(
          (draft) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DraftCard(
              draft: draft,
              onContinue: () => onContinue(draft),
            ),
          ),
        ),
      ],
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.draft, required this.onContinue});

  final DraftOvertime draft;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onContinue,
      borderRadius: BorderRadius.circular(22),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DraftDateBadge(date: draft.activityDate),
                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.activityName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              draft.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                _DraftStatusChip(status: draft.status),
              ],
            ),

            const SizedBox(height: 18),

            _DraftProgress(draft: draft),

            const SizedBox(height: 16),

            Container(height: 1, color: AppColors.border.withOpacity(.55)),

            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(
                  Icons.edit_note_rounded,
                  size: 18,
                  color: AppColors.skyBlue,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Lanjutkan',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.skyBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: AppColors.skyBlue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftDateBadge extends StatelessWidget {
  const _DraftDateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.skyBlueLight,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat('dd', 'id_ID').format(date),
            style: const TextStyle(
              color: AppColors.skyBlue,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('MMM', 'id_ID').format(date).toUpperCase(),
            style: const TextStyle(
              color: AppColors.skyBlue,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftStatusChip extends StatelessWidget {
  const _DraftStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.toUpperCase(),
            style: const TextStyle(
              color: AppColors.warning,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: .35,
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftProgress extends StatelessWidget {
  const _DraftProgress({required this.draft});

  final DraftOvertime draft;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _ProgressStep(label: 'Data', complete: true)),
        Expanded(
          child: _ProgressStep(
            label: 'Kegiatan',
            complete: draft.hasActivityPhoto,
          ),
        ),
        Expanded(
          child: _ProgressStep(
            label: 'Pulang',
            complete: draft.hasCheckoutPhoto,
            last: true,
          ),
        ),
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.label,
    required this.complete,
    this.last = false,
  });

  final String label;
  final bool complete;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: complete
                ? AppColors.success
                : AppColors.border.withOpacity(.45),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            complete ? Icons.check_rounded : Icons.circle_outlined,
            size: complete ? 14 : 10,
            color: complete ? Colors.white : AppColors.muted,
          ),
        ),

        const SizedBox(width: 6),

        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: complete ? FontWeight.w700 : FontWeight.w500,
            color: complete ? AppColors.navy : AppColors.muted,
          ),
        ),

        if (!last) ...[
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 1.5,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: complete
                    ? AppColors.success.withOpacity(.25)
                    : AppColors.border.withOpacity(.55),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DraftSkeleton extends StatelessWidget {
  const _DraftSkeleton();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader(
        title: 'Lembur Belum Selesai',
        subtitle: 'Memuat draft Anda...',
      ),
      const SizedBox(height: 14),
      AppCard(
        color: AppColors.surface,
        padding: const EdgeInsets.all(18),
        child: const SizedBox(height: 150, child: _ShimmerPlaceholder()),
      ),
    ],
  );
}

class _ShimmerPlaceholder extends StatelessWidget {
  const _ShimmerPlaceholder();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(width: 100, height: 16, decoration: _box()),
      const SizedBox(height: 22),
      Container(width: double.infinity, height: 19, decoration: _box()),
      const SizedBox(height: 10),
      Container(width: 180, height: 14, decoration: _box()),
      const Spacer(),
      Container(width: double.infinity, height: 12, decoration: _box()),
    ],
  );
  BoxDecoration _box() => BoxDecoration(
    color: AppColors.skyBlueLight,
    borderRadius: BorderRadius.circular(99),
  );
}

class _DraftEmpty extends StatelessWidget {
  const _DraftEmpty();
  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.successLight,
    padding: const EdgeInsets.all(18),
    child: const Row(
      children: [
        Icon(Icons.task_alt_rounded, color: AppColors.success, size: 28),
        SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tidak ada lembur yang perlu dilengkapi',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Mulai lembur baru kapan pun Anda membutuhkannya.',
                style: TextStyle(color: AppColors.navy, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    ),
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
    child: Row(
      children: [
        const Icon(Icons.cloud_off_outlined, color: AppColors.error, size: 27),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Draft belum dapat dimuat',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                message,
                style: const TextStyle(color: AppColors.navy, height: 1.3),
              ),
              TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
            ],
          ),
        ),
      ],
    ),
  );
}

class _YearOvertimeSummarySection extends StatelessWidget {
  const _YearOvertimeSummarySection({
    required this.summary,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });

  final YearOvertimeSummary? summary;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _YearOvertimeSummarySkeleton();
    if (errorMessage != null || summary == null) {
      return _YearOvertimeSummaryError(
        message: errorMessage ?? 'Ringkasan lembur belum dapat dimuat.',
        onRetry: onRetry,
      );
    }

    return _YearOvertimeSummaryCard(summary: summary!);
  }
}

class _YearOvertimeSummarySkeleton extends StatelessWidget {
  const _YearOvertimeSummarySkeleton();

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(20),
    child: const SizedBox(height: 194, child: _ShimmerPlaceholder()),
  );
}

class _YearOvertimeSummaryError extends StatelessWidget {
  const _YearOvertimeSummaryError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.errorLight,
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_outlined, color: AppColors.error, size: 26),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ringkasan lembur belum dapat dimuat',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(message, style: const TextStyle(color: AppColors.navy)),
              TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
            ],
          ),
        ),
      ],
    ),
  );
}

class _YearOvertimeSummaryCard extends StatelessWidget {
  const _YearOvertimeSummaryCard({required this.summary});

  final YearOvertimeSummary summary;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.skyBlue, AppColors.skyBlueDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x2B1688E8),
          blurRadius: 18,
          offset: Offset(0, 9),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'TOTAL UPAH LEMBUR',
                style: TextStyle(
                  color: Color(0xFFEAF6FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .7,
                ),
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .17),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 21,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          NumberFormat.currency(
            locale: 'id_ID',
            symbol: 'Rp ',
            decimalDigits: 0,
          ).format(summary.totalPay),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Tahun ${DateTime.now().year}',
          style: const TextStyle(color: Color(0xFFEAF6FF), fontSize: 13),
        ),
        if (summary.totalOvertime == 0) ...[
          const SizedBox(height: 3),
          const Text(
            'Belum ada lembur tahun ini',
            style: TextStyle(color: Color(0xFFEAF6FF), fontSize: 12),
          ),
        ],
        const SizedBox(height: 18),
        _YearStats(summary: summary),
      ],
    ),
  );
}

class _YearStats extends StatelessWidget {
  const _YearStats({required this.summary});

  final YearOvertimeSummary summary;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _TotalOvertimeHighlight(total: summary.totalOvertime),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _YearStatCard(
              data: _YearStatData(
                value: summary.workdayOvertime,
                label: 'Hari Kerja',
                icon: Icons.business_center_outlined,
                tint: const Color(0x2BE7FFF6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _YearStatCard(
              data: _YearStatData(
                value: summary.holidayOvertime,
                label: 'Hari Libur',
                icon: Icons.wb_sunny_outlined,
                tint: const Color(0x33FFF2CB),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

class _TotalOvertimeHighlight extends StatelessWidget {
  const _TotalOvertimeHighlight({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        '$total',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 42,
          fontWeight: FontWeight.w800,
          height: .95,
          letterSpacing: -1.2,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Lembur',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            const Text(
              'kegiatan tercatat tahun ini',
              style: TextStyle(
                color: Color(0xFFEAF6FF),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      const Icon(
        Icons.receipt_long_outlined,
        color: Color(0xFFEAF6FF),
        size: 23,
      ),
    ],
  );
}

class _YearStatData {
  const _YearStatData({
    required this.value,
    required this.label,
    required this.icon,
    required this.tint,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color tint;
}

class _YearStatCard extends StatelessWidget {
  const _YearStatCard({required this.data});

  final _YearStatData data;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: data.tint,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white.withValues(alpha: .14)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(data.icon, color: Colors.white, size: 16),
        const SizedBox(height: 7),
        Text(
          '${data.value}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          data.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFEAF6FF),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
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
            'Simpan informasi kegiatan terlebih dahulu, lalu lengkapi foto saat Anda siap.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.navy),
          ),
        ),
      ],
    ),
  );
}
