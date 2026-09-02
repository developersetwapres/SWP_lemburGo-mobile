import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

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
            const Icon(Icons.add_circle_outline_rounded, color: AppColors.skyBlue),
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
        SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
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
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
          child: SizedBox(height: 190, width: double.infinity, child: _image()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(modeLabel, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 11)),
                    ),
                    const SizedBox(height: 7),
                    Text(timestampLabel, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.navy)),
                  ],
                ),
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
                  const PopupMenuItem(value: _PhotoAction.replace, child: Text('Ganti Foto')),
                  if (onChangeTimestamp != null)
                    const PopupMenuItem(value: _PhotoAction.changeTimestamp, child: Text('Ubah Timestamp')),
                  if (onRemove != null)
                    const PopupMenuItem(value: _PhotoAction.remove, child: Text('Hapus Foto')),
                ],
                icon: const Icon(Icons.more_horiz_rounded, color: AppColors.skyBlue),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _image() {
    if (file != null) {
      return Image.file(file!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _BrokenImage());
    }
    return Image.network(
      remoteUrl!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) => progress == null ? child : const _PhotoLoading(),
      errorBuilder: (_, _, _) => const _BrokenImage(),
    );
  }
}

enum _PhotoAction { replace, changeTimestamp, remove }

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.navy,
    child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white)),
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
