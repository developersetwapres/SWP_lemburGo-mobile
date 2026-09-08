import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/offline/local_photo_store.dart';
import '../../core/theme/app_colors.dart';
import 'remote_image.dart';
import 'timestamp_info_panel.dart';

class PhotoUploadCard extends StatelessWidget {
  const PhotoUploadCard({
    required this.label,
    required this.photoBytes,
    required this.timestamp,
    required this.modeLabel,
    required this.isProcessing,
    required this.onTap,
    this.existingImageUrl,
    this.existingImageReference,
    this.onRemove,
    this.onChangeTimestamp,
    super.key,
  });

  final String label;
  final Uint8List? photoBytes;
  final String? existingImageUrl;
  final String? existingImageReference;
  final DateTime? timestamp;
  final String? modeLabel;
  final bool isProcessing;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onChangeTimestamp;

  @override
  Widget build(BuildContext context) {
    if (isProcessing) return const _ProcessingPhotoCard();
    if (photoBytes == null && existingImageReference == null && existingImageUrl == null) {
      return _EmptyPhoto(label: label, onTap: onTap);
    }
    return _PhotoPreview(
      label: label,
      bytes: photoBytes,
      localReference: existingImageReference,
      remoteUrl: existingImageUrl,
      timestamp: timestamp,
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
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Container(height: 54, width: 54, decoration: BoxDecoration(color: AppColors.skyBlueLight, borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.camera_alt_outlined, color: AppColors.skyBlue, size: 27)),
          const SizedBox(width: 15),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 4), Text('Kamera atau galeri • opsional', style: Theme.of(context).textTheme.bodyMedium)])),
          const Icon(Icons.add_circle_outline_rounded, color: AppColors.skyBlue),
        ]),
      ),
    ),
  );
}

class _ProcessingPhotoCard extends StatelessWidget {
  const _ProcessingPhotoCard();
  @override
  Widget build(BuildContext context) => Container(height: 142, decoration: BoxDecoration(color: AppColors.skyBlueLight, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)), SizedBox(width: 12), Text('Menyiapkan foto dan lokasi...')]));
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.label, required this.bytes, required this.localReference, required this.remoteUrl, required this.timestamp, required this.modeLabel, required this.onReplace, this.onRemove, this.onChangeTimestamp});
  final String label;
  final Uint8List? bytes;
  final String? localReference;
  final String? remoteUrl;
  final DateTime? timestamp;
  final String modeLabel;
  final VoidCallback onReplace;
  final VoidCallback? onRemove;
  final VoidCallback? onChangeTimestamp;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(99)), child: Text(modeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: .25)))),
      const SizedBox(width: 8),
      IconButton(tooltip: 'Buka foto layar penuh', onPressed: () => _open(context), icon: const Icon(Icons.open_in_full_rounded), color: AppColors.skyBlue),
      PopupMenuButton<_PhotoAction>(tooltip: 'Aksi foto', onSelected: (action) { switch (action) { case _PhotoAction.replace: onReplace(); break; case _PhotoAction.changeTimestamp: onChangeTimestamp?.call(); break; case _PhotoAction.remove: onRemove?.call(); break; } }, itemBuilder: (_) => [const PopupMenuItem(value: _PhotoAction.replace, child: Text('Ganti Foto')), if (onChangeTimestamp != null) const PopupMenuItem(value: _PhotoAction.changeTimestamp, child: Text('Ubah Timestamp')), if (onRemove != null) const PopupMenuItem(value: _PhotoAction.remove, child: Text('Hapus Foto'))], icon: const Icon(Icons.more_horiz_rounded, color: AppColors.skyBlue)),
    ]),
    const SizedBox(height: 10),
    Material(color: Colors.transparent, borderRadius: BorderRadius.circular(22), clipBehavior: Clip.antiAlias, child: InkWell(onTap: () => _open(context), child: DecoratedBox(decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: AspectRatio(aspectRatio: 4 / 3, child: _image(BoxFit.contain))))),
    const SizedBox(height: 10), TimestampInfoPanel(timestamp: timestamp),
  ]);

  void _open(BuildContext context) => Navigator.of(context).push<void>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => _FormPhotoFullScreenPreview(bytes: bytes, localReference: localReference, remoteUrl: remoteUrl)));
  Widget _image(BoxFit fit) => _PhotoImage(bytes: bytes, localReference: localReference, remoteUrl: remoteUrl, fit: fit);
}

class _FormPhotoFullScreenPreview extends StatelessWidget {
  const _FormPhotoFullScreenPreview({required this.bytes, required this.localReference, required this.remoteUrl});
  final Uint8List? bytes;
  final String? localReference;
  final String? remoteUrl;
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black, body: SafeArea(child: Stack(children: [Center(child: InteractiveViewer(minScale: 1, maxScale: 4, child: _PhotoImage(bytes: bytes, localReference: localReference, remoteUrl: remoteUrl, fit: BoxFit.contain))), Positioned(top: 12, left: 16, child: Material(color: Colors.black54, shape: const CircleBorder(), child: IconButton(tooltip: 'Tutup foto', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: Colors.white))))])));
}

class _PhotoImage extends StatelessWidget {
  const _PhotoImage({required this.bytes, required this.localReference, required this.remoteUrl, required this.fit});
  final Uint8List? bytes;
  final String? localReference;
  final String? remoteUrl;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    if (bytes != null) return Image.memory(bytes!, fit: fit, errorBuilder: (_, _, _) => const _BrokenImage());
    if (localReference != null) return FutureBuilder<Uint8List?>(future: readLocalPhoto(localReference!), builder: (_, snapshot) { final value = snapshot.data; if (value == null) return snapshot.connectionState == ConnectionState.waiting ? const _PhotoLoading() : const _BrokenImage(); return Image.memory(value, fit: fit, errorBuilder: (_, _, _) => const _BrokenImage()); });
    return RemoteImage(url: remoteUrl!, fit: fit, loading: const _PhotoLoading(), error: const _BrokenImage());
  }
}

enum _PhotoAction { replace, changeTimestamp, remove }
class _BrokenImage extends StatelessWidget { const _BrokenImage(); @override Widget build(BuildContext context) => const ColoredBox(color: AppColors.navy, child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white))); }
class _PhotoLoading extends StatelessWidget { const _PhotoLoading(); @override Widget build(BuildContext context) => const ColoredBox(color: AppColors.skyBlueLight, child: Center(child: CircularProgressIndicator(strokeWidth: 2.5))); }
