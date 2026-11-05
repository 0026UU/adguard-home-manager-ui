import 'package:flutter/material.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// One switch of the per-device settings. While the device follows the server
/// the switch is only a readout of what the server does, so it answers no tap.
class SettingsTile extends StatelessWidget {
  final String label;
  final bool? value;
  final void Function(bool)? onChange;
  final bool useGlobalSettingsFiltering;
  final IconData? icon;
  final Color? iconColor;

  const SettingsTile({
    super.key,
    required this.label,
    required this.value,
    this.onChange,
    required this.useGlobalSettingsFiltering,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppleSwitchListTile(
      icon: icon,
      iconColor: iconColor,
      title: label,
      value: value ?? false,
      onChanged: useGlobalSettingsFiltering || onChange == null || value == null
          ? null
          : onChange,
    );
  }
}
