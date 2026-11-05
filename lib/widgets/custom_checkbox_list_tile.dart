import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Multi-choice row with an Apple checkbox on the trailing edge.
class CustomCheckboxListTile extends StatelessWidget {
  final bool value;
  final void Function(bool) onChanged;
  final String title;
  final String? subtitle;
  final bool? disabled;
  final EdgeInsets? padding;

  const CustomCheckboxListTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.disabled,
    this.subtitle,
    this.padding
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final isDisabled = disabled == true;

    final row = AppleListTile(
      title: title,
      subtitle: subtitle,
      showChevron: false,
      enabled: !isDisabled,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      trailing: CupertinoCheckbox(
        value: value,
        onChanged: isDisabled ? null : (next) => onChanged(next ?? !value),
        activeColor: p.tint,
      ),
    );

    // Tapping anywhere on the row flips the box, like the system lists.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : () => onChanged(!value),
        child: row,
      ),
    );
  }
}
