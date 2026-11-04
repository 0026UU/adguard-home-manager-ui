import 'package:flutter/cupertino.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/models/dhcp.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Enable switch of the DHCP server, labelled with the interface it runs on.
class DhcpMainButton extends StatelessWidget {
  final NetworkInterface? selectedInterface;
  final bool enabled;
  final void Function(bool) setEnabled;

  const DhcpMainButton({
    super.key,
    required this.selectedInterface,
    required this.enabled,
    required this.setEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final ready = selectedInterface != null;

    return AppleListSection(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 22),
      children: [
        AppleSwitchListTile(
          title: l.enableDhcpServer,
          subtitle: selectedInterface?.name,
          value: enabled,
          onChanged: ready ? (value) => setEnabled(value) : null,
          icon: CupertinoIcons.antenna_radiowaves_left_right,
          iconColor: ready ? p.tint : p.gray,
        ),
      ],
    );
  }
}
