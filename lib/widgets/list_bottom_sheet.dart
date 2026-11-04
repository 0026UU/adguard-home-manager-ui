import 'package:flutter/material.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Grouped bottom sheet listing rows under a titled header.
class ListBottomSheet extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  final double? initialChildSize;
  final double? minChildSize;
  final double? maxChildSize;

  const ListBottomSheet({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.initialChildSize,
    this.maxChildSize,
    this.minChildSize,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return AppleSheet(
      title: title,
      leading: Icon(icon, size: 20, color: p.tint),
      initialFraction: initialChildSize ?? 0.6,
      minFraction: minChildSize ?? 0.4,
      maxFraction: maxChildSize ?? 0.95,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
