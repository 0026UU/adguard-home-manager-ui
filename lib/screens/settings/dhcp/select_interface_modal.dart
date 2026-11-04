import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/settings/dhcp/dhcp_interface_item.dart';

import 'package:adguard_home_manager/models/dhcp.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Picker listing the interfaces the server can serve DHCP on.
class SelectInterfaceModal extends StatelessWidget {
  final List<NetworkInterface> interfaces;
  final void Function(NetworkInterface) onSelect;
  final bool dialog;

  const SelectInterfaceModal({
    super.key,
    required this.interfaces,
    required this.onSelect,
    required this.dialog,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    return AppleFormModal(
      title: l.selectInterface,
      icon: CupertinoIcons.antenna_radiowaves_left_right,
      dialog: dialog,
      maxWidth: 500,
      trailing: IconButton(
        onPressed: () => Navigator.pop(context),
        padding: EdgeInsets.zero,
        tooltip: l.cancel,
        icon: Icon(
          CupertinoIcons.xmark_circle_fill,
          size: 22,
          color: p.label3,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: AppleListSection(
          margin: EdgeInsets.zero,
          children: [
            for (final iface in interfaces)
              DhcpInterfaceItem(
                networkInterface: iface,
                onSelect: onSelect,
              ),
          ],
        ),
      ),
    );
  }
}
