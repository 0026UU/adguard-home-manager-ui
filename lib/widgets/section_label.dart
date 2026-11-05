import 'package:flutter/material.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Title above a group of rows, like a grouped-table section header.
class SectionLabel extends StatelessWidget {
  final String label;
  final EdgeInsets? padding;

  const SectionLabel({
    super.key,
    required this.label,
    this.padding
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 7),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.08,
          height: 1.25,
          color: p.label2,
        ),
      ),
    );
  }
}
