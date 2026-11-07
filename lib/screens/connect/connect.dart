import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/connect/fab.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/servers_list/servers_list.dart';

/// The first screen of a fresh install: the saved connections, and the plus
/// that adds one.
class Connect extends StatelessWidget {
  const Connect({super.key});

  @override
  Widget build(BuildContext context) {
    // The button that hid on scroll-down was Material's own; here the button
    // always stays, and the empty list says what it is for.
    return AppleScreen(
      title: AppLocalizations.of(context)!.connect,
      body: const ServersList(
        breakingWidth: 700,
      ),
      floatingActionButton: const FabConnect(),
    );
  }
}
