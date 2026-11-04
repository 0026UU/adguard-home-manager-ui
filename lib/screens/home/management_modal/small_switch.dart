import 'package:flutter/cupertino.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// One protection toggle inside the management sheet.
class SmallSwitch extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final void Function(bool) onChange;
  final bool disabled;
  final Color? iconColor;

  const SmallSwitch({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChange,
    required this.disabled,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppleSwitchListTile(
      title: label,
      value: value,
      icon: icon,
      iconColor: iconColor ?? ApplePalette.of(context).tint,
      onChanged: disabled == false ? onChange : null,
    );
  }
}
