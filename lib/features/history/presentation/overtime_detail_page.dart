import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/remote_image.dart';
import '../../overtime/data/models/draft_overtime.dart';
import '../../overtime/data/overtime_repository.dart';

class OvertimeDetailPage extends StatefulWidget {
  const OvertimeDetailPage({
    required this.record,
    required this.repository,
    required this.onSessionExpired,
    this.canEdit = false,
    super.key,
  });

  final DraftOvertime record;
  final OvertimeRepository repository;
  final Future<void> Function() onSessionExpired;
  final bool canEdit;

  @override
  State<OvertimeDetailPage> createState() => _OvertimeDetailPageState();
}

class _OvertimeDetailPageState extends State<OvertimeDetailPage> {
  bool _isDeleting = false;

  void _requestEdit() =>
      Navigator.of(context).pop(const OvertimeDetailResult.edit());

  Future<void> _deleteRecord() async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);
    final result = await _confirmAndDelete(
      context,
      record: widget.record,
      repository: widget.repository,
    );
    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (result.isUnauthenticated) {
      await widget.onSessionExpired();
      return;
    }
    if (result.message == null) return;
    if (!result.wasDeleted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message!)));
      return;
    }
    Navigator.of(context).pop(OvertimeDetailResult.deleted(result.message!));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Kembali',
        onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Detail Lembur'),
      titleTextStyle: Theme.of(context).textTheme.titleLarge,
      actions: [
        if (widget.canEdit)
          IconButton(
            tooltip: 'Edit laporan',
            onPressed: _isDeleting ? null : _requestEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _DeleteIconButton(
            isDeleting: _isDeleting,
            onPressed: _deleteRecord,
          ),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: OvertimeDetailContent(record: widget.record),
    ),
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
        _DocumentationGallery(record: record),
      ],
    ),
  );
}

class OvertimeDetailBottomSheet extends StatefulWidget {
  const OvertimeDetailBottomSheet({
    required this.record,
    required this.repository,
    required this.onSessionExpired,
    super.key,
  });

  final DraftOvertime record;
  final OvertimeRepository repository;
  final Future<void> Function() onSessionExpired;

  @override
  State<OvertimeDetailBottomSheet> createState() =>
      _OvertimeDetailBottomSheetState();
}

class _OvertimeDetailBottomSheetState extends State<OvertimeDetailBottomSheet> {
  bool _isDeleting = false;

  Future<void> _deleteRecord() async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);
    final result = await _confirmAndDelete(
      context,
      record: widget.record,
      repository: widget.repository,
    );
    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (result.isUnauthenticated) {
      await widget.onSessionExpired();
      return;
    }
    if (result.message == null) return;
    if (!result.wasDeleted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message!)));
      return;
    }
    Navigator.of(context).pop(OvertimeDetailResult.deleted(result.message!));
  }

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
                    onPressed: _isDeleting
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  _DeleteIconButton(
                    isDeleting: _isDeleting,
                    onPressed: _deleteRecord,
                  ),
                ],
              ),
            ),
            Expanded(
              child: OvertimeDetailContent(
                record: widget.record,
                scrollController: scrollController,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DeleteIconButton extends StatelessWidget {
  const _DeleteIconButton({required this.isDeleting, required this.onPressed});

  final bool isDeleting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isDeleting) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    return IconButton(
      tooltip: 'Hapus laporan',
      onPressed: onPressed,
      icon: const Icon(Icons.delete_outline_rounded),
      color: AppColors.error,
    );
  }
}

Future<_DeleteRecordResult> _confirmAndDelete(
  BuildContext context, {
  required DraftOvertime record,
  required OvertimeRepository repository,
}) async {
  if (record.uuid.trim().isEmpty) {
    return const _DeleteRecordResult.failed(
      'Data laporan tidak memiliki UUID sehingga tidak dapat dihapus.',
    );
  }

  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.delete_forever_outlined, color: AppColors.error),
      title: const Text('Hapus laporan lembur?'),
      content: Text(
        'Laporan “${record.activityName}” beserta dokumentasinya akan dihapus permanen dan tidak dapat dipulihkan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Hapus'),
        ),
      ],
    ),
  );
  if (shouldDelete != true) return const _DeleteRecordResult.cancelled();
  if (!context.mounted) return const _DeleteRecordResult.cancelled();

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Menghapus laporan lembur...')),
          ],
        ),
      ),
    ),
  );

  try {
    final message = await repository.delete(record.uuid);
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    return _DeleteRecordResult.deleted(message);
  } on ApiException catch (error) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    return _DeleteRecordResult.failed(
      error.message,
      isUnauthenticated: error.isUnauthenticated,
    );
  } catch (_) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    return const _DeleteRecordResult.failed(
      'Laporan lembur belum dapat dihapus. Silakan coba lagi.',
    );
  }
}

class _DeleteRecordResult {
  const _DeleteRecordResult._({
    required this.wasDeleted,
    required this.isUnauthenticated,
    this.message,
  });

  const _DeleteRecordResult.cancelled()
    : this._(wasDeleted: false, isUnauthenticated: false);

  const _DeleteRecordResult.deleted(String message)
    : this._(wasDeleted: true, isUnauthenticated: false, message: message);

  const _DeleteRecordResult.failed(
    String message, {
    bool isUnauthenticated = false,
  }) : this._(
         wasDeleted: false,
         isUnauthenticated: isUnauthenticated,
         message: message,
       );

  final bool wasDeleted;
  final bool isUnauthenticated;
  final String? message;
}

/// Result returned to the list or calendar after the user leaves a detail.
class OvertimeDetailResult {
  const OvertimeDetailResult._({this.deleteMessage, this.requestsEdit = false});

  const OvertimeDetailResult.deleted(String message)
    : this._(deleteMessage: message);

  const OvertimeDetailResult.edit() : this._(requestsEdit: true);

  final String? deleteMessage;
  final bool requestsEdit;

  bool get wasDeleted => deleteMessage != null;
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.record});
  final DraftOvertime record;

  bool get _isLocked => record.isFinalized;
  bool get _isActuallyLocked => record.normalizedStatus == 'locked';

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
            _isActuallyLocked
                ? Icons.lock_outline_rounded
                : _isLocked
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            color: _isLocked ? AppColors.muted : AppColors.success,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isActuallyLocked
                    ? 'Lembur terkunci'
                    : _isLocked
                    ? 'Lembur selesai'
                    : 'Detail lembur',
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

class _DocumentationGallery extends StatelessWidget {
  const _DocumentationGallery({required this.record});

  final DraftOvertime record;

  @override
  Widget build(BuildContext context) {
    final photos = [
      _OvertimePhoto(
        title: 'Foto Kegiatan',
        subtitle: 'Dokumentasi aktivitas lembur',
        url: record.activityPhotoUrl,
        timestamp: record.activityPhotoAt,
        emptyMessage: 'Foto kegiatan belum tersedia.',
        icon: Icons.photo_camera_back_outlined,
      ),
      _OvertimePhoto(
        title: 'Foto Presensi Pulang',
        subtitle: 'Bukti presensi saat pulang',
        url: record.checkoutPhotoUrl,
        timestamp: record.checkoutPhotoAt,
        emptyMessage: 'Foto presensi pulang belum tersedia.',
        icon: Icons.verified_user_outlined,
      ),
    ];
    final availablePhotos = photos.where((photo) => photo.url != null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dokumentasi Lembur',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    availablePhotos.isEmpty
                        ? 'Belum ada foto yang diunggah'
                        : '${availablePhotos.length} foto tersedia • ketuk untuk melihat detail',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.skyBlueLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.skyBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < photos.length; index++) ...[
          _PhotoAlbumTile(
            photo: photos[index],
            onOpen: photos[index].url == null
                ? null
                : () => _openGallery(
                    context,
                    photos: availablePhotos,
                    initialPhoto: photos[index],
                  ),
          ),
          if (index < photos.length - 1) const SizedBox(height: 18),
        ],
      ],
    );
  }

  void _openGallery(
    BuildContext context, {
    required List<_OvertimePhoto> photos,
    required _OvertimePhoto initialPhoto,
  }) {
    final initialIndex = photos.indexOf(initialPhoto);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _PhotoGalleryPage(
          photos: photos,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
        ),
      ),
    );
  }
}

class _PhotoAlbumTile extends StatelessWidget {
  const _PhotoAlbumTile({required this.photo, this.onOpen});

  final _OvertimePhoto photo;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    if (photo.url == null) return _EmptyPhoto(message: photo.emptyMessage);

    return Semantics(
      button: true,
      label: 'Buka ${photo.title} dalam layar penuh',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A25405F),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 15, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.skyBlueLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          photo.icon,
                          color: AppColors.skyBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              photo.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              photo.subtitle,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.open_in_full_rounded,
                        color: AppColors.skyBlue,
                        size: 21,
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: ColoredBox(
                      color: AppColors.navy,
                      child: RemoteImage(
                        url: photo.url!,
                        // Contain keeps every part of the submitted evidence visible.
                        fit: BoxFit.contain,
                        loading: const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: const _ImageError(),
                      ),
                    ),
                  ),
                ),
                _PhotoTimestamp(timestamp: photo.timestamp),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoTimestamp extends StatelessWidget {
  const _PhotoTimestamp({required this.timestamp});

  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
    child: Row(
      children: [
        const Icon(Icons.access_time_rounded, size: 17, color: AppColors.muted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            timestamp == null
                ? 'Waktu foto tidak tersedia'
                : DateFormat(
                    'EEEE, d MMMM y • HH:mm',
                    'id_ID',
                  ).format(timestamp!),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.zoom_in_rounded, color: AppColors.skyBlue, size: 20),
      ],
    ),
  );
}

class _OvertimePhoto {
  const _OvertimePhoto({
    required this.title,
    required this.subtitle,
    required this.url,
    required this.timestamp,
    required this.emptyMessage,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String? url;
  final DateTime? timestamp;
  final String emptyMessage;
  final IconData icon;
}

class _PhotoGalleryPage extends StatefulWidget {
  const _PhotoGalleryPage({required this.photos, required this.initialIndex});

  final List<_OvertimePhoto> photos;
  final int initialIndex;

  @override
  State<_PhotoGalleryPage> createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<_PhotoGalleryPage> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late int _currentIndex = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_currentIndex];
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final pagePhoto = widget.photos[index];
                return Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: RemoteImage(
                      url: pagePhoto.url!,
                      fit: BoxFit.contain,
                      loading: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      error: const _ImageError(),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  _GalleryIconButton(
                    tooltip: 'Tutup galeri',
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.photos.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xDD000000)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 42, 24, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        photo.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        photo.timestamp == null
                            ? 'Waktu foto tidak tersedia'
                            : DateFormat(
                                'EEEE, d MMMM y • HH:mm',
                                'id_ID',
                              ).format(photo.timestamp!),
                        style: const TextStyle(color: Color(0xFFD8E0EA)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Geser untuk foto lain • Cubit untuk memperbesar',
                        style: TextStyle(
                          color: Color(0xFFABB8C8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryIconButton extends StatelessWidget {
  const _GalleryIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black54,
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
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
