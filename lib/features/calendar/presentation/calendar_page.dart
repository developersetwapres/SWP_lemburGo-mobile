import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../history/presentation/overtime_detail_page.dart';
import '../../overtime/data/overtime_repository.dart';
import '../../overtime/data/remote_overtime_api.dart';
import '../../overtime/data/services/overtime_pdf_delivery.dart';
import '../data/models/calendar_overtime.dart';
import '../data/services/holiday_calendar.dart';
import 'calendar_controller.dart';
import 'widgets/calendar_month_grid.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    required this.controller,
    required this.repository,
    required this.onSessionExpired,
    required this.isActive,
    super.key,
  });

  final CalendarController controller;
  final OvertimeRepository repository;
  final Future<void> Function() onSessionExpired;
  final bool isActive;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final HolidayCalendar _holidayCalendar = const HolidayCalendar();
  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  bool _hasLoaded = false;
  bool _isExportingPdf = false;

  CalendarController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.startListening();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDate = now;
    if (widget.isActive) _loadCalendar(showSkeleton: true);
  }

  @override
  void didUpdateWidget(covariant CalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadCalendar(showSkeleton: !_hasLoaded);
    }
  }

  Future<void> _loadCalendar({bool showSkeleton = false}) async {
    _hasLoaded = true;
    final outcome = await _controller.load(showSkeleton: showSkeleton);
    unawaited(widget.repository.syncNow());
    if (mounted && outcome == CalendarLoadOutcome.unauthenticated) {
      await widget.onSessionExpired();
    }
  }

  void _moveMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
      if (_selectedDate.year != _visibleMonth.year ||
          _selectedDate.month != _visibleMonth.month) {
        _selectedDate = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
      }
    });
  }

  Future<void> _openDetail(CalendarOvertime entry) async {
    final result = await _controller.loadDetail(entry);
    if (!mounted) return;
    if (result.unauthenticated) {
      await widget.onSessionExpired();
      return;
    }
    if (result.record != null) {
      final detailResult = await showModalBottomSheet<OvertimeDetailResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        sheetAnimationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 320),
          reverseDuration: Duration(milliseconds: 240),
        ),
        builder: (_) => OvertimeDetailBottomSheet(
          record: result.record!,
          repository: widget.repository,
          onSessionExpired: widget.onSessionExpired,
        ),
      );
      if (!mounted || detailResult?.wasDeleted != true) return;
      await _loadCalendar();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(detailResult!.deleteMessage!)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message ?? 'Detail lembur belum tersedia untuk tanggal ini.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onDateSelected(DateTime date) async {
    setState(() => _selectedDate = date);
    final entry = _controller.entryFor(date);
    if (entry != null) await _openDetail(entry);
  }

  Future<void> _exportPdf() async {
    if (_isExportingPdf) return;
    final month = DateFormat('yyyy-MM').format(_visibleMonth);
    setState(() => _isExportingPdf = true);
    try {
      final report = await widget.repository.exportPdf(month: month);
      final delivery = await const OvertimePdfDelivery().deliver(
        bytes: report.bytes,
        fileName: report.fileName,
      );
      if (!mounted) return;
      final message = delivery.shareSheetOpened
          ? '${report.fileName} berhasil disimpan. Pilih aplikasi untuk membuka atau membagikannya.'
          : '${report.fileName} berhasil disimpan di ${delivery.savedLocation}. Buka file tersebut untuk melihat laporan.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } on NoOvertimePdfDataException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak ada data lembur lengkap yang dapat diekspor untuk bulan ini.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (error) {
      if (error.isUnauthenticated) {
        await widget.onSessionExpired();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengunduh PDF lembur. Silakan coba lagi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => RefreshIndicator(
        color: AppColors.skyBlue,
        onRefresh: _loadCalendar,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const _CalendarHeader(),
                  const SizedBox(height: 22),
                  _MonthNavigator(
                    month: _visibleMonth,
                    onPrevious: () => _moveMonth(-1),
                    onNext: () => _moveMonth(1),
                    onExport: _exportPdf,
                    isExporting: _isExportingPdf,
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(13, 17, 13, 15),
                    child: _controller.isLoading
                        ? const _CalendarSkeleton()
                        : CalendarMonthGrid(
                            month: _visibleMonth,
                            selectedDate: _selectedDate,
                            entriesByDate: _controller.entriesByDate,
                            holidayCalendar: _holidayCalendar,
                            onDateSelected: _onDateSelected,
                          ),
                  ),
                  const SizedBox(height: 13),
                  const _CalendarLegend(),
                  if (_controller.errorMessage != null) ...[
                    const SizedBox(height: 18),
                    _CalendarError(
                      message: _controller.errorMessage!,
                      onRetry: () => _loadCalendar(showSkeleton: true),
                    ),
                  ],
                  if (_controller.isOpeningDetail) ...[
                    const SizedBox(height: 18),
                    const _DetailLoadingIndicator(),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Kalender Lembur',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 5),
      Text(
        'Lihat jadwal dan riwayat lembur berdasarkan tanggal.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ],
  );
}

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onExport,
    required this.isExporting,
  });
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onExport;
  final bool isExporting;

  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.skyBlueLight,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Bulan sebelumnya',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
              color: AppColors.skyBlue,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  DateFormat('MMMM y', 'id_ID').format(month),
                  key: ValueKey('${month.year}-${month.month}'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Bulan berikutnya',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
              color: AppColors.skyBlue,
            ),
          ],
        ),
        const Divider(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isExporting ? null : onExport,
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 185, 41, 41),
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.errorLight,
              disabledForegroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            icon: isExporting
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.error,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(
              isExporting ? 'Mengunduh PDF...' : 'Ekspor PDF bulan ini',
            ),
          ),
        ),
      ],
    ),
  );
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();
  @override
  Widget build(BuildContext context) => Row(
    children: const [
      _LegendItem(color: AppColors.skyBlue, label: 'Ada lembur'),
      SizedBox(width: 18),
      _LegendItem(color: AppColors.holiday, label: 'Hari libur'),
    ],
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

class _DetailLoadingIndicator extends StatelessWidget {
  const _DetailLoadingIndicator();

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox(
        width: 17,
        height: 17,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      SizedBox(width: 9),
      Text('Memuat detail lembur...'),
    ],
  );
}

class _CalendarSkeleton extends StatelessWidget {
  const _CalendarSkeleton();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const _SkeletonBar(widthFactor: .9, height: 13),
      const SizedBox(height: 16),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 35,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 5,
          crossAxisSpacing: 4,
        ),
        itemBuilder: (context, index) => const _CalendarSkeletonCell(),
      ),
    ],
  );
}

class _CalendarSkeletonCell extends StatelessWidget {
  const _CalendarSkeletonCell();
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.skyBlueLight,
      borderRadius: BorderRadius.circular(15),
    ),
  );
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.widthFactor, required this.height});
  final double widthFactor;
  final double height;
  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: widthFactor,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.skyBlueLight,
        borderRadius: BorderRadius.circular(99),
      ),
    ),
  );
}

class _CalendarError extends StatelessWidget {
  const _CalendarError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.errorLight,
    padding: const EdgeInsets.all(17),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cloud_off_outlined, color: AppColors.error),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gagal memuat kalender lembur',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(message, style: const TextStyle(color: AppColors.navy)),
              TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      ],
    ),
  );
}
