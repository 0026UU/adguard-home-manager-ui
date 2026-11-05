import 'package:flutter/cupertino.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Shown when the server runs on an OS where AdGuard cannot serve DHCP.
class DhcpNotAvailable extends StatelessWidget {
  const DhcpNotAvailable({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    return AppleScreen(
      title: l.dhcpSettings,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppleEmptyState(
            icon: CupertinoIcons.antenna_radiowaves_left_right,
            title: l.dhcpNotAvailable,
            message: l.osServerInstalledIncompatible,
            color: p.orange,
          ),
        ),
      ],
    );
  }
}
