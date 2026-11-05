import 'package:flutter/material.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Setting row with an iOS switch.
class CustomSwitchListTile extends StatelessWidget {
  final bool value;
  final void Function(bool) onChanged;
  final String title;
  final String? subtitle;
  final bool? disabled;
  final EdgeInsets? padding;
  final IconData? leadingIcon;

  const CustomSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.disabled,
    this.subtitle,
    this.padding,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = disabled == true;

    final row = AppleSwitchListTile(
      title: title,
      subtitle: subtitle,
      icon: leadingIcon,
      value: value,
      onChanged: isDisabled ? null : onChanged,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    );

    // iOS toggles from anywhere on the row, not just the control itself.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : () => onChanged(!value),
        child: row,
      ),
    );
  }
}
