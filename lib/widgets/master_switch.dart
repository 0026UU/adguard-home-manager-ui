import 'package:flutter/material.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Header switch that gates a whole settings group.
class MasterSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChange;
  final EdgeInsets? margin;

  const MasterSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChange,
    this.margin
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(horizontal: 16),
      child: AppleListSection(
        margin: EdgeInsets.zero,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onChange(!value),
              child: AppleSwitchListTile(
                title: label,
                value: value,
                onChanged: onChange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
