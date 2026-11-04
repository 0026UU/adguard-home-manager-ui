import 'dart:io';

import 'package:contextmenu/contextmenu.dart';
import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/models/menu_option.dart';

class OptionsMenu extends StatelessWidget {
  final Widget child;
  final List<MenuOption> Function(dynamic) options;
  final dynamic value;
  final BorderRadius? borderRadius;
  final void Function(dynamic)? onTap;

  const OptionsMenu({
    super.key,
    required this.child,
    required this.options,
    this.value,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    void openOptionsModal() {
      showAppleActionSheet(
        context,
        cancelLabel: AppLocalizations.of(context)?.cancel,
        actions: options(value)
          .map((opt) => AppleSheetAction(
            label: opt.title,
            icon: opt.icon,
            disabled: opt.disabled == true,
            onTap: opt.action,
          ))
          .toList(),
      );
    }

    return Material(
      color: Colors.transparent,
      child: ContextMenuArea(
        builder: (context) => options(value).map(
          (opt) => _AppleMenuRow(
            title: opt.title,
            icon: opt.icon,
            enabled: opt.disabled != true,
            onTap: () {
              opt.action();
              Navigator.pop(context);
            },
          )
        ).toList(),
        child: InkWell(
          onTap: onTap != null
            ? () => onTap!(value)
            : null,
          onLongPress: (Platform.isAndroid || Platform.isIOS)
            ? () => openOptionsModal()
            : null,
          borderRadius: borderRadius,
          child: child,
        ),
      ),
    );
  }
}

/// Single line inside the desktop right-click menu.
class _AppleMenuRow extends StatelessWidget {
  final String title;
  final IconData? icon;
  final bool enabled;
  final void Function() onTap;

  const _AppleMenuRow({
    required this.title,
    required this.onTap,
    this.icon,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          splashColor: Colors.transparent,
          highlightColor: p.fill3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 18,
                    color: enabled ? p.tint : p.label3,
                  ),
                  const SizedBox(width: 12),
                ],
                Flexible(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.25,
                      color: enabled ? p.label : p.label3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
