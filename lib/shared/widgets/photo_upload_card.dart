import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class PhotoUploadCard extends StatelessWidget {
  const PhotoUploadCard({
    required this.label,
    required this.photoFile,
    required this.timestampLabel,
    required this.modeLabel,
    required this.isProcessing,
    required this.onTap,
    required this.onRemove,
    super.key,
  });
  final String label;
  final File? photoFile;
  final String? timestampLabel;
  final String? modeLabel;
  final bool isProcessing;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (isProcessing) return const _ProcessingPhotoCard();
    if (photoFile == null) return _EmptyPhoto(label: label, onTap: onTap);
    return _PhotoPreview(
      label: label,
      file: photoFile!,
      timestampLabel: timestampLabel!,
      modeLabel: modeLabel!,
      onReplace: onTap,
      onRemove: onRemove,
    );
  }
}

class _EmptyPhoto extends StatelessWidget {
  const _EmptyPhoto({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
                      'Kamera atau galeri • timestamp permanen',
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
        Text('Memproses foto dan timestamp...'),
      ],
    ),
  );
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.label,
    required this.file,
    required this.timestampLabel,
    required this.modeLabel,
    required this.onReplace,
    required this.onRemove,
  });
  final String label, timestampLabel, modeLabel;
  final File file;
  final VoidCallback onReplace, onRemove;

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
          child: SizedBox(
            height: 190,
            width: double.infinity,
            child: Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: AppColors.navy,
                child: Center(
                  child: Icon(Icons.broken_image_outlined, color: Colors.white),
                ),
              ),
            ),
          ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        modeLabel,
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      timestampLabel,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.navy),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Ganti $label',
                onPressed: onReplace,
                icon: const Icon(Icons.edit_outlined, color: AppColors.skyBlue),
              ),
              IconButton(
                tooltip: 'Hapus foto',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
