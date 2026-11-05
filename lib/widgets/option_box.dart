import 'package:flutter/material.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Pill-shaped choice inside an options grid.
class OptionBox extends StatelessWidget {
  final dynamic optionsValue;
  final dynamic itemValue;
  final void Function(dynamic) onTap;
  final String label;

  const OptionBox({
    super.key,
    required this.optionsValue,
    required this.itemValue,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final selected = optionsValue == itemValue;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onTap(itemValue),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected ? p.tint : p.fill2,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
              color: selected ? Colors.white : p.label,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
