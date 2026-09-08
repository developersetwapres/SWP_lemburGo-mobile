import 'package:flutter/material.dart';

import '../../core/offline/sync_status.dart';
import '../../core/theme/app_colors.dart';

/// A deliberately small status surface: it appears only while the user needs
/// to know that changes are local, waiting, or being synchronized.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({
    required this.status,
    required this.onRetry,
    super.key,
  });

  final SyncStatus status;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: status,
    builder: (context, _) {
      final shouldShow =
          !status.hasNetworkTransport ||
          status.isSyncing ||
          status.pendingCount > 0 ||
          status.lastError != null;
      if (!shouldShow) return const SizedBox.shrink();
      final offline = !status.hasNetworkTransport || !status.apiReachable;
      final error = status.lastError?.trim();
      final hasError = error != null && error.isNotEmpty;
      final color = status.isSyncing
          ? AppColors.skyBlue
          : hasError
          ? AppColors.error
          : offline
          ? AppColors.warning
          : AppColors.skyBlue;
      final icon = status.isSyncing
          ? Icons.sync_rounded
          : hasError
          ? Icons.error_outline_rounded
          : offline
          ? Icons.cloud_off_outlined
          : Icons.cloud_upload_outlined;
      final text = status.isSyncing
          ? 'Menyinkronkan perubahan…'
          : hasError
          ? status.pendingCount == 0
                ? 'Sinkronisasi gagal: $error'
                : '${status.pendingCount} perubahan belum tersinkron. $error'
          : offline
          ? status.pendingCount == 0
                ? 'Mode offline — data tersimpan di perangkat'
                : '${status.pendingCount} perubahan menunggu sinkronisasi'
          : '${status.pendingCount} perubahan siap disinkronkan';
      return Material(
        color: color.withValues(alpha: .11),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            child: Row(
              children: [
                if (status.isSyncing)
                  SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      color: color,
                      strokeWidth: 2,
                    ),
                  )
                else
                  Icon(icon, color: color, size: 19),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!status.isSyncing && status.pendingCount > 0)
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Coba lagi'),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
