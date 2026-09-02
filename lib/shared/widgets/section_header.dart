import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ],
  );
}
