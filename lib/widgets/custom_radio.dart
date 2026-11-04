import 'package:flutter/material.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Apple radio indicator for single-choice rows.
class CustomRadio extends StatelessWidget {
  final dynamic value;
  final dynamic groupValue;

  const CustomRadio({
    super.key,
    required this.value,
    required this.groupValue,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final selected = value == groupValue;

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? p.tint : p.label3,
          width: 2,
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        width: selected ? 12 : 0,
        height: selected ? 12 : 0,
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.tint,
        ),
      ),
    );
  }
}
