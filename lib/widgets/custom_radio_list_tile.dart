import 'package:flutter/material.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/custom_radio.dart';

/// Single-choice row: radio indicator on the leading edge, like a
/// grouped list picker.
class CustomRadioListTile extends StatelessWidget {
  final String groupValue;
  final String value;
  final String title;
  final String? subtitle;
  final void Function(String) onChanged;

  const CustomRadioListTile({
    super.key,
    required this.groupValue,
    required this.value,
    required this.title,
    this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppleListTile(
      title: title,
      subtitle: subtitle,
      leading: CustomRadio(value: value, groupValue: groupValue),
      showChevron: false,
      onTap: () => onChanged(value),
    );
  }
}
