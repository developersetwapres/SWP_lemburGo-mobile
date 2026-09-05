import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';

/// A compact, high-contrast companion for a photo timestamp.
///
/// The actual timestamp is part of newly captured images; this panel keeps the
/// form and detail screens visually aligned with that documentary-camera look.
class TimestampInfoPanel extends StatelessWidget {
  const TimestampInfoPanel({required this.timestamp, this.margin, super.key});

  final DateTime? timestamp;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final hasTimestamp = timestamp != null;
    return Container(
      width: double.infinity,
      margin: margin,
      decoration: BoxDecoration(
        color: const Color(0xE014243A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF31506D)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1025405F),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: const BoxDecoration(
              color: AppColors.skyBlue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
            child: hasTimestamp
                ? _TimestampDetails(timestamp: timestamp!)
                : const _MissingTimestamp(),
          ),
        ],
      ),
    );
  }
}

class _TimestampDetails extends StatelessWidget {
  const _TimestampDetails({required this.timestamp});

  final DateTime timestamp;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Text(
          DateFormat('EEEE, d MMMM y', 'id_ID').format(timestamp),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 9),
      Text(
        '${DateFormat('HH:mm').format(timestamp)} WIB',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _MissingTimestamp extends StatelessWidget {
  const _MissingTimestamp();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Icon(Icons.schedule_outlined, color: Color(0xFF8FD2FF), size: 20),
      SizedBox(width: 9),
      Expanded(
        child: Text(
          'Timestamp foto belum tersedia',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}
