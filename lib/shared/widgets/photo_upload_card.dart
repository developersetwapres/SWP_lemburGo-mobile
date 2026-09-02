import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class PhotoUploadCard extends StatelessWidget {
  const PhotoUploadCard({
    required this.label,
    required this.hasPhoto,
    required this.timestamp,
    required this.onTap,
    super.key,
  });
  final String label, timestamp;
  final bool hasPhoto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Ink(
      height: hasPhoto ? 170 : 142,
      decoration: BoxDecoration(
        color: hasPhoto ? AppColors.navy : AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: hasPhoto ? AppColors.navy : AppColors.border),
      ),
      child: hasPhoto
          ? _PhotoPreview(label: label, timestamp: timestamp)
          : _EmptyPhoto(label: label),
    ),
  );
}

class _EmptyPhoto extends StatelessWidget {
  const _EmptyPhoto({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
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
                'Foto akan diberi timestamp',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const Icon(Icons.add_circle_outline_rounded, color: AppColors.skyBlue),
      ],
    ),
  );
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.label, required this.timestamp});
  final String label, timestamp;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF335E89), Color(0xFF172A43)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.image_outlined,
              size: 48,
              color: Color(0x77FFFFFF),
            ),
          ),
        ),
      ),
      Positioned(
        top: 12,
        right: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .38),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.edit_outlined, color: Colors.white, size: 17),
        ),
      ),
      Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .48),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 15,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  timestamp,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                label.replaceFirst('Ambil ', ''),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
