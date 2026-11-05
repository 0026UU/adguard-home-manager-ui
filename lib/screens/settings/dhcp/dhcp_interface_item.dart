import 'package:flutter/cupertino.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/models/dhcp.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// One row of the interface picker: its name plus whatever the server reported.
class DhcpInterfaceItem extends StatelessWidget {
  final NetworkInterface networkInterface;
  final void Function(NetworkInterface) onSelect;

  const DhcpInterfaceItem({
    super.key,
    required this.networkInterface,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    final details = <String>[
      '${l.hardwareAddress}: ${networkInterface.hardwareAddress}',
      if (networkInterface.flags.isNotEmpty)
        'Flags: ${networkInterface.flags.join(', ')}',
      if (networkInterface.gatewayIp != null &&
          networkInterface.gatewayIp != '')
        '${l.gatewayIp}: ${networkInterface.gatewayIp}',
      if (networkInterface.ipv4Addresses.isNotEmpty)
        '${l.ipv4addresses}: ${networkInterface.ipv4Addresses.join(', ')}',
      if (networkInterface.ipv6Addresses.isNotEmpty)
        '${l.ipv6addresses}: ${networkInterface.ipv6Addresses.join(', ')}',
    ];

    return AppleListTile(
      title: networkInterface.name,
      subtitle: details.join('\n'),
      subtitleMaxLines: details.length,
      icon: CupertinoIcons.antenna_radiowaves_left_right,
      showChevron: false,
      onTap: () {
        Navigator.pop(context);
        onSelect(networkInterface);
      },
    );
  }
}
