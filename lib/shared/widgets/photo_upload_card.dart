import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'remote_image.dart';

/// One photo input used for both create and draft editing. A remote URL is
/// display-only; a [photoFile] is a newly selected local file that can upload.
class PhotoUploadCard extends StatelessWidget {
  const PhotoUploadCard({
    required this.label,
    required this.photoFile,
    required this.timestampLabel,
    required this.modeLabel,
    required this.isProcessing,
    required this.onTap,
    this.existingImageUrl,
    this.onRemove,
    this.onChangeTimestamp,
    super.key,
  });

  final String label;
  final File? photoFile;
  final String? existingImageUrl;
  final String? timestampLabel;
  final String? modeLabel;
  final bool isProcessing;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onChangeTimestamp;

  @override
  Widget build(BuildContext context) {
    if (isProcessing) return const _ProcessingPhotoCard();
    if (photoFile == null && existingImageUrl == null) {
      return _EmptyPhoto(label: label, onTap: onTap);
    }
    return _PhotoPreview(
      label: label,
      file: photoFile,
      remoteUrl: existingImageUrl,
      timestampLabel: timestampLabel ?? 'Waktu foto tersimpan',
      modeLabel: modeLabel ?? 'FOTO TERSIMPAN',
      onReplace: onTap,
      onRemove: onRemove,
      onChangeTimestamp: onChangeTimestamp,
    );
  }
}

class _EmptyPhoto extends StatelessWidget {
  const _EmptyPhoto({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Ink(
      height: 142,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: AppColors.skyBlueLight,
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.skyBlue,
                size: 27,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Kamera atau galeri • opsional',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.skyBlue,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProcessingPhotoCard extends StatelessWidget {
  const _ProcessingPhotoCard();

  @override
  Widget build(BuildContext context) => Container(
    height: 142,
    decoration: BoxDecoration(
      color: AppColors.skyBlueLight,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.border),
    ),
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        SizedBox(width: 12),
        Text('Menyiapkan foto dan lokasi...'),
      ],
    ),
  );
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.label,
    required this.file,
    required this.remoteUrl,
    required this.timestampLabel,
    required this.modeLabel,
    required this.onReplace,
    this.onRemove,
    this.onChangeTimestamp,
  });

  final String label;
  final File? file;
  final String? remoteUrl;
  final String timestampLabel;
  final String modeLabel;
  final VoidCallback onReplace;
  final VoidCallback? onRemove;
  final VoidCallback? onChangeTimestamp;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                modeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: .25,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Buka foto layar penuh',
            onPressed: () => _showFullScreen(context),
            icon: const Icon(Icons.open_in_full_rounded),
            color: AppColors.skyBlue,
          ),
          PopupMenuButton<_PhotoAction>(
            tooltip: 'Aksi foto',
            onSelected: (action) {
              switch (action) {
                case _PhotoAction.replace:
                  onReplace();
                  break;
                case _PhotoAction.changeTimestamp:
                  onChangeTimestamp?.call();
                  break;
                case _PhotoAction.remove:
                  onRemove?.call();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _PhotoAction.replace,
                child: Text('Ganti Foto'),
              ),
              if (onChangeTimestamp != null)
                const PopupMenuItem(
                  value: _PhotoAction.changeTimestamp,
                  child: Text('Ubah Timestamp'),
                ),
              if (onRemove != null)
                const PopupMenuItem(
                  value: _PhotoAction.remove,
                  child: Text('Hapus Foto'),
                ),
            ],
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: AppColors.skyBlue,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Semantics(
        button: true,
        label: 'Buka $label dalam layar penuh',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _showFullScreen(context),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                // Contain shows the whole submitted photo instead of cropping it.
                child: _image(BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      _PhotoTimestampPanel(timestampLabel: timestampLabel),
    ],
  );

  void _showFullScreen(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FormPhotoFullScreenPreview(
          title: label,
          timestampLabel: timestampLabel,
          file: file,
          remoteUrl: remoteUrl,
        ),
      ),
    );
  }

  Widget _image(BoxFit fit) {
    if (file != null) {
      return Image.file(
        file!,
        fit: fit,
        errorBuilder: (_, _, _) => const _BrokenImage(),
      );
    }
    return RemoteImage(
      url: remoteUrl!,
      fit: fit,
      loading: const _PhotoLoading(),
      error: const _BrokenImage(),
    );
  }
}

class _PhotoTimestampPanel extends StatelessWidget {
  const _PhotoTimestampPanel({required this.timestampLabel});

  final String timestampLabel;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      color: AppColors.skyBlueLight,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.skyBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.schedule_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WAKTU FOTO',
                style: TextStyle(
                  color: AppColors.skyBlueDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .65,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                timestampLabel,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.zoom_in_rounded, color: AppColors.skyBlue, size: 22),
      ],
    ),
  );
}

class _FormPhotoFullScreenPreview extends StatelessWidget {
  const _FormPhotoFullScreenPreview({
    required this.title,
    required this.timestampLabel,
    required this.file,
    required this.remoteUrl,
  });

  final String title;
  final String timestampLabel;
  final File? file;
  final String? remoteUrl;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(minScale: 1, maxScale: 4, child: _image()),
          ),
          Positioned(
            top: 12,
            left: 16,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Tutup foto',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
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
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'WAKTU FOTO',
                      style: TextStyle(
                        color: Color(0xFF9FB3C8),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .65,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timestampLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cubit untuk memperbesar foto',
                      style: TextStyle(color: Color(0xFFABB8C8), fontSize: 12),
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

  Widget _image() {
    if (file != null) {
      return Image.file(
        file!,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const _BrokenImage(),
      );
    }
    return RemoteImage(
      url: remoteUrl!,
      fit: BoxFit.contain,
      loading: const _PhotoLoading(),
      error: const _BrokenImage(),
    );
  }
}

enum _PhotoAction { replace, changeTimestamp, remove }

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.navy,
    child: Center(
      child: Icon(Icons.broken_image_outlined, color: Colors.white),
    ),
  );
}

class _PhotoLoading extends StatelessWidget {
  const _PhotoLoading();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.skyBlueLight,
    child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
  );
}
