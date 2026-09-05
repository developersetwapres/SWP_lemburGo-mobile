import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../data/models/photo_stamp.dart';
import '../data/services/location_service.dart';
import '../data/services/photo_processing_service.dart';

/// In-app camera for automatic documentary stamps.
///
/// `image_picker` is still used for the gallery flow. A system camera intent
/// cannot host a Flutter overlay, whereas this page lets the user see the
/// exact stamp content before the shutter is pressed.
class TimestampCameraPage extends StatefulWidget {
  const TimestampCameraPage({required this.photoService, super.key});

  final PhotoProcessingService photoService;

  @override
  State<TimestampCameraPage> createState() => _TimestampCameraPageState();
}

class _TimestampCameraPageState extends State<TimestampCameraPage>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  DeviceAddress? _address;
  Timer? _clock;
  DateTime _visibleTimestamp = DateTime.now();
  FlashMode _flashMode = FlashMode.off;
  bool _isStarting = false;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    unawaited(_cameraController?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_releaseCamera());
      return;
    }
    if (state == AppLifecycleState.resumed &&
        _cameraController == null &&
        !_isStarting &&
        !_isCapturing) {
      unawaited(_initializeCamera(reusePreparedAddress: true));
    }
  }

  Future<void> _initializeCamera({bool reusePreparedAddress = false}) async {
    if (_isStarting || _isCapturing) return;
    if (mounted) {
      setState(() {
        _isStarting = true;
        _errorMessage = null;
      });
    }
    CameraController? pendingController;
    try {
      await _releaseCamera(updateState: false);
      final address = reusePreparedAddress && _address != null
          ? _address!
          : await widget.photoService.prepareAutomaticCameraStamp();
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
          'NoCameraAvailable',
          'Kamera perangkat tidak tersedia.',
        );
      }
      final rearCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = pendingController = CameraController(
        rearCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await controller.setFlashMode(_flashMode);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _address = address;
        _visibleTimestamp = DateTime.now();
        _isStarting = false;
      });
      pendingController = null;
      _clock?.cancel();
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && !_isCapturing) {
          setState(() => _visibleTimestamp = DateTime.now());
        }
      });
    } catch (error) {
      await pendingController?.dispose();
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _errorMessage = _cameraErrorMessage(error);
      });
    }
  }

  Future<void> _releaseCamera({bool updateState = true}) async {
    _clock?.cancel();
    _clock = null;
    final controller = _cameraController;
    if (updateState && mounted && controller != null) {
      setState(() => _cameraController = null);
    } else {
      _cameraController = null;
    }
    await controller?.dispose();
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || _isCapturing) return;
    final next = _flashMode == FlashMode.torch
        ? FlashMode.off
        : FlashMode.torch;
    try {
      await controller.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mode lampu tidak didukung oleh kamera ini.'),
          ),
        );
      }
    }
  }

  Future<void> _capture() async {
    final controller = _cameraController;
    final address = _address;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing ||
        address == null) {
      return;
    }
    final timestamp = DateTime.now();
    setState(() {
      _isCapturing = true;
      _visibleTimestamp = timestamp;
    });
    try {
      final source = await controller.takePicture();
      final photo = await widget.photoService.createAutomaticStampAt(
        source: source,
        timestamp: timestamp,
        address: address,
      );
      if (mounted) Navigator.of(context).pop(photo);
    } on PhotoProcessingException catch (error) {
      _showCaptureError(error.message);
    } on CameraException catch (_) {
      _showCaptureError('Foto tidak dapat diambil. Silakan coba lagi.');
    } catch (_) {
      _showCaptureError('Foto belum dapat diproses. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _showCaptureError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _cameraErrorMessage(Object error) {
    if (error is LocationException) return error.message;
    if (error is CameraException) {
      return switch (error.code) {
        'CameraAccessDenied' => 'Izin kamera belum diberikan.',
        'CameraAccessDeniedWithoutPrompt' =>
          'Izin kamera ditolak. Aktifkan melalui Pengaturan perangkat.',
        'CameraAccessRestricted' => 'Kamera dibatasi pada perangkat ini.',
        'NoCameraAvailable' => 'Kamera perangkat tidak tersedia.',
        _ => 'Kamera belum dapat disiapkan. Silakan coba lagi.',
      };
    }
    return 'Timestamp kamera belum dapat disiapkan. Silakan coba lagi.';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    if (_errorMessage != null) {
      return _TimestampCameraError(
        message: _errorMessage!,
        onRetry: () => _initializeCamera(),
      );
    }
    if (_isStarting || controller == null || !controller.value.isInitialized) {
      return const _TimestampCameraLoading();
    }
    final content = PhotoTimestampContent(
      timestamp: _visibleTimestamp,
      address: _address!,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CameraPreviewCover(controller: controller),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  _CameraIconButton(
                    tooltip: 'Tutup kamera',
                    icon: Icons.close_rounded,
                    onPressed: _isCapturing
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  _CameraIconButton(
                    tooltip: _flashMode == FlashMode.torch
                        ? 'Matikan lampu'
                        : 'Nyalakan lampu',
                    icon: _flashMode == FlashMode.torch
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    onPressed: _isCapturing ? null : _toggleFlash,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 112,
              child: _LiveTimestampOverlay(content: content),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                children: [
                  Text(
                    _isCapturing
                        ? 'MENYIMPAN TIMESTAMP KE FOTO...'
                        : 'TIMESTAMP AKAN TERCETAK PADA FOTO',
                    style: const TextStyle(
                      color: Color(0xFFD7E9F8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .65,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    button: true,
                    label: 'Ambil foto dengan timestamp',
                    child: InkResponse(
                      onTap: _isCapturing ? null : _capture,
                      radius: 46,
                      child: Container(
                        width: 72,
                        height: 72,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _isCapturing
                                ? AppColors.skyBlue
                                : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: _isCapturing
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveTimestampOverlay extends StatelessWidget {
  const _LiveTimestampOverlay({required this.content});

  final PhotoTimestampContent content;

  @override
  Widget build(BuildContext context) {
    final addressLines = content.addressLines;
    return Container(
      constraints: const BoxConstraints(maxWidth: 680),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xC80B1D31),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xA65DADEB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content.dateLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: .15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            content.timeLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: .15,
            ),
          ),
          if (addressLines.isNotEmpty) ...[
            const SizedBox(height: 9),
            for (final line in addressLines)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE1EFFA),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.22,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TimestampCameraLoading extends StatelessWidget {
  const _TimestampCameraLoading();

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppColors.navy,
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 18),
            Text(
              'Menyiapkan kamera dan timestamp...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Waktu dan lokasi akan ditampilkan sebelum foto diambil.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFB8D4E8), height: 1.4),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Makes the native camera feed cover the complete Stack. The timestamp and
/// controls are positioned above this widget, so they never reserve space
/// below the preview or reduce its available area.
class _CameraPreviewCover extends StatelessWidget {
  const _CameraPreviewCover({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final screenAspectRatio = constraints.maxWidth / constraints.maxHeight;
      final previewAspectRatio = controller.value.aspectRatio;
      final aspectRatioScale = previewAspectRatio / screenAspectRatio;
      final scale = aspectRatioScale < 1
          ? 1 / aspectRatioScale
          : aspectRatioScale;
      return ClipRect(
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: Center(
            child: AspectRatio(
              aspectRatio: previewAspectRatio,
              child: CameraPreview(controller),
            ),
          ),
        ),
      );
    },
  );
}

class _TimestampCameraError extends StatelessWidget {
  const _TimestampCameraError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.navy,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                color: Color(0xFF8FD2FF),
                size: 44,
              ),
              const SizedBox(height: 18),
              const Text(
                'Kamera Timestamp',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFD6E6F3), height: 1.45),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Kembali',
                  style: TextStyle(color: Color(0xFFB8DFFF)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CameraIconButton extends StatelessWidget {
  const _CameraIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0x99000000),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
    ),
  );
}
