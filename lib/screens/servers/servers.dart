import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/screens/connect/fab.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/servers_list/servers_list.dart';

/// The saved connections, reached from the settings hub.
///
/// It is the same list the first-run screen shows, so it is drawn the same
/// way: the design layer's large title, the back capsule the hub pushed it
/// from, and the floating plus that adds one more server. The plus used to
/// slide away as soon as the list scrolled, which on a long list was the only
/// way to add a server and the first thing to disappear.
class Servers extends StatelessWidget {
  final double? breakingWidth;

  const Servers({
    super.key,
    this.breakingWidth
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    final width = MediaQuery.sizeOf(context).width;

    return AppleScreen(
      title: l.servers,
      leading: isDesktop(width)
        ? null
        : AppleBackButton(
            label: l.back,
            onPressed: () => Navigator.pop(context),
          ),
      body: ServersList(
        breakingWidth: breakingWidth ?? 700,
      ),
      floatingActionButton: const FabConnect(),
    );
  }
}
