import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/remote_image.dart';
import '../../overtime/data/models/draft_overtime.dart';

class OvertimeDetailPage extends StatelessWidget {
  const OvertimeDetailPage({required this.record, super.key});

  final DraftOvertime record;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Kembali',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Detail Lembur'),
      titleTextStyle: Theme.of(context).textTheme.titleLarge,
    ),
    body: SafeArea(top: false, child: OvertimeDetailContent(record: record)),
  );
}

class OvertimeDetailContent extends StatelessWidget {
  const OvertimeDetailContent({
    required this.record,
    this.scrollController,
    super.key,
  });

  final DraftOvertime record;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    controller: scrollController,
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusHeader(record: record),
        const SizedBox(height: 24),
        _DetailCard(record: record),
        const SizedBox(height: 24),
        _PhotoDetail(
          title: 'Foto Kegiatan',
          url: record.activityPhotoUrl,
          timestamp: record.activityPhotoAt,
          emptyMessage: 'Foto kegiatan belum tersedia.',
        ),
        const SizedBox(height: 20),
        _PhotoDetail(
          title: 'Foto Presensi Pulang',
          url: record.checkoutPhotoUrl,
          timestamp: record.checkoutPhotoAt,
          emptyMessage: 'Foto presensi pulang belum tersedia.',
        ),
      ],
    ),
  );
}

class OvertimeDetailBottomSheet extends StatelessWidget {
  const OvertimeDetailBottomSheet({required this.record, super.key});

  final DraftOvertime record;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 1, end: 0),
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
    builder: (context, offset, child) => Opacity(
      opacity: 1 - (offset * .2),
      child: Transform.translate(offset: Offset(0, 24 * offset), child: child),
    ),
    child: DraggableScrollableSheet(
      initialChildSize: .82,
      minChildSize: .5,
      maxChildSize: .95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        Text(
                          'Detail Lembur',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: OvertimeDetailContent(
                record: record,
                scrollController: scrollController,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.record});
  final DraftOvertime record;

  bool get _isLocked => record.status.toLowerCase() == 'locked';

  @override
  Widget build(BuildContext context) => AppCard(
    color: _isLocked ? const Color(0xFFEAF1F6) : AppColors.successLight,
    padding: const EdgeInsets.all(17),
    child: Row(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            _isLocked ? Icons.lock_outline_rounded : Icons.info_outline_rounded,
            color: _isLocked ? AppColors.muted : AppColors.success,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isLocked ? 'Lembur terkunci' : 'Detail lembur',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _isLocked
                    ? 'Data ini hanya dapat dilihat.'
                    : 'Data lengkap dapat diperbarui dari lembur draft.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.record});
  final DraftOvertime record;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      children: [
        _DetailRow(
          icon: Icons.calendar_today_outlined,
          label: 'Tanggal kegiatan',
          value: DateFormat('d MMMM y', 'id_ID').format(record.activityDate),
        ),
        const Divider(height: 25),
        _DetailRow(
          icon: Icons.event_note_outlined,
          label: 'Nama kegiatan',
          value: record.activityName,
        ),
        const Divider(height: 25),
        _DetailRow(
          icon: Icons.location_on_outlined,
          label: 'Lokasi',
          value: record.location,
        ),
        const Divider(height: 25),
        _DetailRow(
          icon: Icons.schedule_outlined,
          label: 'Waktu pulang',
          value: record.checkoutTime == null
              ? 'Belum pulang'
              : DateFormat('HH:mm').format(record.checkoutTime!),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.skyBlue, size: 20),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _PhotoDetail extends StatelessWidget {
  const _PhotoDetail({
    required this.title,
    required this.url,
    required this.timestamp,
    required this.emptyMessage,
  });
  final String title;
  final String? url;
  final DateTime? timestamp;
  final String emptyMessage;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      if (url == null)
        _EmptyPhoto(message: emptyMessage)
      else
        InkWell(
          onTap: () => _showPreview(context),
          borderRadius: BorderRadius.circular(21),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1.5,
                    child: RemoteImage(
                      url: url!,
                      fit: BoxFit.cover,
                      loading: const Center(child: CircularProgressIndicator()),
                      error: const _ImageError(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 17,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timestamp == null
                              ? 'Waktu foto tidak tersedia'
                              : DateFormat(
                                  'd MMM y • HH:mm',
                                  'id_ID',
                                ).format(timestamp!),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.fullscreen_rounded,
                          color: AppColors.skyBlue,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  void _showPreview(BuildContext context) => showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: RemoteImage(
                url: url!,
                fit: BoxFit.contain,
                loading: const Center(child: CircularProgressIndicator()),
                error: const _ImageError(),
              ),
            ),
          ),
          Positioned(
            top: 42,
            right: 16,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              tooltip: 'Tutup',
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyPhoto extends StatelessWidget {
  const _EmptyPhoto({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.skyBlueLight,
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        const Icon(Icons.photo_outlined, color: AppColors.skyBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

class _ImageError extends StatelessWidget {
  const _ImageError();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.navy,
    child: Center(
      child: Icon(Icons.broken_image_outlined, color: Colors.white, size: 34),
    ),
  );
}
