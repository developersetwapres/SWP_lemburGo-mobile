import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/offline/local_photo_store.dart';
import '../../../core/theme/app_colors.dart';

class LocalPhotoImage extends StatelessWidget {
  const LocalPhotoImage({required this.reference, required this.fit, super.key});
  final String reference;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: readLocalPhoto(reference),
    builder: (_, snapshot) {
      final bytes = snapshot.data;
      if (bytes == null) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return const ColoredBox(color: AppColors.navy, child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white)));
      }
      return Image.memory(bytes, fit: fit, errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.navy, child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white))));
    },
  );
}
