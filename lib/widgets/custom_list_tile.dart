import 'package:flutter/material.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// List row used across menus and detail screens.
///
/// Kept as a thin wrapper so existing call sites stay untouched while the
/// visuals come from the Apple layer.
class CustomListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final void Function()? onTap;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsets? padding;
  final void Function()? onLongPress;
  final bool? disabled;
  final void Function(bool)? onHover;
  final Color? color;

  const CustomListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.onTap,
    this.icon,
    this.trailing,
    this.padding,
    this.onLongPress,
    this.disabled,
    this.onHover,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tile = AppleListTile(
      title: title,
      subtitle: subtitle,
      subtitleWidget: subtitleWidget,
      icon: icon,
      iconColor: disabled == true ? ApplePalette.of(context).label4 : null,
      trailing: trailing,
      onTap: disabled == true ? null : onTap,
      onLongPress: onLongPress,
      onHover: onHover,
      showChevron: false,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );

    if (color == null) return tile;

    return ColoredBox(color: color!, child: tile);
  }
}
