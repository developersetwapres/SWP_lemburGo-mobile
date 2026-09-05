import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../overtime/data/models/draft_overtime.dart';
import '../../overtime/data/overtime_repository.dart';
import 'history_controller.dart';
import 'overtime_detail_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    required this.repository,
    required this.onEdit,
    required this.onSessionExpired,
    required this.isActive,
    super.key,
  });

  final OvertimeRepository repository;
  final Future<bool> Function(DraftOvertime record) onEdit;
  final Future<void> Function() onSessionExpired;
  final bool isActive;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final HistoryController _controller;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _controller = HistoryController(widget.repository);
    _controller.startListening();
    if (widget.isActive) _loadInitial();
  }

  @override
  void didUpdateWidget(covariant HistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive && !_hasLoaded) {
      _loadInitial();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    _hasLoaded = true;
    final outcome = await _controller.load(showSkeleton: true);
    unawaited(
      widget.repository.syncNow(historyMonth: _controller.selectedMonth),
    );
    if (mounted && outcome == HistoryLoadOutcome.unauthenticated) {
      await widget.onSessionExpired();
    }
  }

  Future<void> _refresh() async {
    unawaited(
      widget.repository.syncNow(historyMonth: _controller.selectedMonth),
    );
    final outcome = await _controller.refresh();
    if (mounted && outcome == HistoryLoadOutcome.unauthenticated) {
      await widget.onSessionExpired();
    }
  }

  Future<void> _selectMonth() async {
    final month = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _MonthSheet(selectedMonth: _controller.selectedMonth),
    );
    if (!mounted || month == null || month == _controller.selectedMonth) return;
    final outcome = await _controller.load(month: month);
    unawaited(widget.repository.syncNow(historyMonth: month));
    if (mounted && outcome == HistoryLoadOutcome.unauthenticated) {
      await widget.onSessionExpired();
    }
  }

  Future<void> _openRecord(DraftOvertime record) async {
    final messenger = ScaffoldMessenger.of(context);
    DraftOvertime detail;
    try {
      detail = await widget.repository.fetchRecordDetail(record);
    } on ApiException catch (error) {
      if (error.isUnauthenticated) {
        if (!mounted) return;
        await widget.onSessionExpired();
        return;
      }
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      return;
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Detail lembur belum dapat dimuat.')),
      );
      return;
    }

    if (!mounted) return;
    final detailResult = await Navigator.of(context).push<OvertimeDetailResult>(
      MaterialPageRoute(
        builder: (_) => OvertimeDetailPage(
          record: detail,
          repository: widget.repository,
          onSessionExpired: widget.onSessionExpired,
          canEdit: !detail.isFinalized,
        ),
      ),
    );
    if (!mounted || detailResult == null) return;

    if (detailResult.requestsEdit) {
      final saved = await widget.onEdit(detail);
      if (saved && mounted) await _refresh();
      return;
    }

    if (detailResult.wasDeleted) {
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(detailResult.deleteMessage!)));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => RefreshIndicator(
        color: AppColors.skyBlue,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const _HistoryHeader(),
                  const SizedBox(height: 22),
                  _IncomeSummary(
                    totalUpah: _controller.history?.totalUpah ?? 0,
                    month: _controller.selectedMonth,
                    totalOvertime: _controller.history?.totalOvertime ?? 0,
                    workdayOvertime: _controller.history?.workdayOvertime ?? 0,
                    holidayOvertime: _controller.history?.holidayOvertime ?? 0,
                    isServerSummaryStale:
                        _controller.history?.isServerSummaryStale ?? true,
                    isLoading: _controller.isLoading,
                  ),
                  const SizedBox(height: 18),
                  _MonthFilter(
                    month: _controller.selectedMonth,
                    isLoading: _controller.isFiltering,
                    onTap: _selectMonth,
                  ),
                  const SizedBox(height: 26),
                  _HistoryContent(
                    controller: _controller,
                    onRetry: _refresh,
                    onRecordTap: _openRecord,
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

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Riwayat Lembur', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 5),
      Text(
        'Pantau kegiatan dan upah lembur Anda.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ],
  );
}

class _IncomeSummary extends StatelessWidget {
  const _IncomeSummary({
    required this.totalUpah,
    required this.month,
    required this.totalOvertime,
    required this.workdayOvertime,
    required this.holidayOvertime,
    required this.isServerSummaryStale,
    required this.isLoading,
  });
  final num totalUpah;
  final int month;
  final int totalOvertime;
  final int workdayOvertime;
  final int holidayOvertime;
  final bool isServerSummaryStale;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.skyBlue, AppColors.skyBlueDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(26),
      boxShadow: const [
        BoxShadow(
          color: Color(0x301688E8),
          blurRadius: 22,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: -28,
          top: -35,
          child: Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 11),
                const Text(
                  'TOTAL UPAH LEMBUR',
                  style: TextStyle(
                    color: Color(0xFFDDF1FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (isLoading)
              Container(
                width: 180,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .22),
                  borderRadius: BorderRadius.circular(9),
                ),
              )
            else if (isServerSummaryStale)
              const Text(
                'Belum tersedia',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              )
            else
              Text(
                NumberFormat.currency(
                  locale: 'id_ID',
                  symbol: 'Rp',
                  decimalDigits: 0,
                ).format(totalUpah),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 31,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              isServerSummaryStale
                  ? '${_monthName(month)} ${DateTime.now().year} • upah menunggu data server'
                  : '${_monthName(month)} ${DateTime.now().year} • $totalOvertime kegiatan lembur',
              style: const TextStyle(color: Color(0xFFE3F3FF), fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              Container(
                width: double.infinity,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
              )
            else if (isServerSummaryStale)
              const Text(
                'Jumlah upah dan klasifikasi hari akan diperbarui saat tersambung ke server.',
                style: TextStyle(color: Color(0xFFE3F3FF), fontSize: 12),
              )
            else
              _OvertimeBreakdown(
                workdayOvertime: workdayOvertime,
                holidayOvertime: holidayOvertime,
              ),
          ],
        ),
      ],
    ),
  );
}

class _OvertimeBreakdown extends StatelessWidget {
  const _OvertimeBreakdown({
    required this.workdayOvertime,
    required this.holidayOvertime,
  });
  final int workdayOvertime;
  final int holidayOvertime;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _BreakdownItem(
          icon: Icons.business_center_outlined,
          value: workdayOvertime,
          label: 'Hari kerja',
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: _BreakdownItem(
          icon: Icons.wb_sunny_outlined,
          value: holidayOvertime,
          label: 'Hari libur',
        ),
      ),
    ],
  );
}

class _BreakdownItem extends StatelessWidget {
  const _BreakdownItem({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: .13)),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFFDDF1FF), size: 18),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Color(0xFFDDF1FF), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MonthFilter extends StatelessWidget {
  const _MonthFilter({
    required this.month,
    required this.isLoading,
    required this.onTap,
  });
  final int month;
  final bool isLoading;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: isLoading ? null : onTap,
    borderRadius: BorderRadius.circular(17),
    child: AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.skyBlueLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.skyBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Periode riwayat',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_monthName(month)} ${DateTime.now().year}',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          else
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.skyBlue,
            ),
        ],
      ),
    ),
  );
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({
    required this.controller,
    required this.onRetry,
    required this.onRecordTap,
  });
  final HistoryController controller;
  final VoidCallback onRetry;
  final ValueChanged<DraftOvertime> onRecordTap;
  @override
  Widget build(BuildContext context) {
    if (controller.isLoading) {
      return const _HistorySkeleton();
    }
    if (controller.errorMessage != null) {
      return _HistoryError(message: controller.errorMessage!, onRetry: onRetry);
    }
    final records = controller.history?.records ?? const <DraftOvertime>[];
    if (records.isEmpty) {
      return _HistoryEmpty(month: controller.selectedMonth);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Kegiatan Lembur',
          subtitle:
              '${records.length} riwayat pada ${_monthName(controller.selectedMonth)}',
        ),
        const SizedBox(height: 14),
        ...records.map(
          (record) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HistoryCard(
              record: record,
              onTap: () => onRecordTap(record),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.record, required this.onTap});
  final DraftOvertime record;
  final VoidCallback onTap;
  bool get _isLocked => record.isFinalized;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: record.isFinalized
                  ? const Color(0xFFEAF1F6)
                  : AppColors.skyBlueLight,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              DateFormat(
                'dd\nMMM',
                'id_ID',
              ).format(record.activityDate).toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: record.isFinalized ? AppColors.muted : AppColors.skyBlue,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusChip(status: record.status),
                    if (!_isLocked)
                      const Padding(
                        padding: EdgeInsets.only(left: 7),
                        child: Text(
                          'Bisa diedit',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  record.activityName,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        record.location,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      record.isFinalized
                          ? Icons.check_circle_outline_rounded
                          : Icons.schedule_rounded,
                      size: 16,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      record.checkoutTime == null
                          ? 'Belum pulang'
                          : 'Pulang ${DateFormat('HH:mm').format(record.checkoutTime!)}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      record.isFinalized
                          ? Icons.chevron_right_rounded
                          : Icons.edit_outlined,
                      color: AppColors.skyBlue,
                      size: 19,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final recordStatus = DraftOvertime.normalizeStatus(status);
    final locked = recordStatus == 'locked';
    final finalized = DraftOvertime.isFinalizedStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: locked ? const Color(0xFFEAF1F6) : AppColors.warningLight,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            locked ? Icons.lock_outline_rounded : Icons.edit_note_rounded,
            size: 13,
            color: finalized ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            DraftOvertime.labelForStatus(status),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: .3,
              fontWeight: FontWeight.w800,
              color: finalized ? AppColors.muted : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader(
        title: 'Kegiatan Lembur',
        subtitle: 'Memuat riwayat...',
      ),
      const SizedBox(height: 14),
      ...List.generate(
        3,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _HistorySkeletonCard(),
        ),
      ),
    ],
  );
}

class _HistorySkeletonCard extends StatelessWidget {
  const _HistorySkeletonCard();
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(16),
    child: const SizedBox(height: 78, child: _SkeletonLines()),
  );
}

class _SkeletonLines extends StatelessWidget {
  const _SkeletonLines();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(width: 72, height: 13, decoration: _shape()),
      const SizedBox(height: 12),
      Container(width: double.infinity, height: 16, decoration: _shape()),
      const SizedBox(height: 9),
      Container(width: 170, height: 13, decoration: _shape()),
    ],
  );
  BoxDecoration _shape() => BoxDecoration(
    color: AppColors.skyBlueLight,
    borderRadius: BorderRadius.circular(8),
  );
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({required this.month});
  final int month;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader(title: 'Kegiatan Lembur'),
      const SizedBox(height: 14),
      AppCard(
        color: AppColors.skyBlueLight,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.skyBlue,
              size: 38,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada riwayat lembur',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Belum ada kegiatan lembur pada ${_monthName(month)} ${DateTime.now().year}.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    ],
  );
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.errorLight,
    padding: const EdgeInsets.all(19),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cloud_off_outlined, color: AppColors.error, size: 27),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gagal memuat riwayat lembur',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(color: AppColors.navy, height: 1.3),
              ),
              TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MonthSheet extends StatelessWidget {
  const _MonthSheet({required this.selectedMonth});
  final int selectedMonth;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pilih Bulan', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 5),
          Text(
            'Riwayat akan dimuat ulang dari server.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final selected = month == selectedMonth;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.skyBlue
                          : AppColors.skyBlueLight,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      month.toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.skyBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    _monthName(month),
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.skyBlue,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, month),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

String _monthName(int month) =>
    DateFormat.MMMM('id_ID').format(DateTime(DateTime.now().year, month));
