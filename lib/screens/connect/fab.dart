import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/widgets/add_server/add_server_functions.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

class FabConnect extends StatelessWidget {
  const FabConnect({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final l = AppLocalizations.of(context)!;

    void openAddServerModal() async {
      await Future.delayed(const Duration(seconds: 0), (() => {
        openServerFormModal(context: context, width: width)
      }));
    }

    // The plus is the only way into the app for a new user, so it carries a
    // tooltip and the design layer's tint instead of Material's own accent.
    final p = ApplePalette.of(context);
    return FloatingActionButton(
      onPressed: openAddServerModal,
      tooltip: l.createConnection,
      backgroundColor: p.tint,
      foregroundColor: onTint(p.tint),
      child: const Icon(CupertinoIcons.plus),
    );
  }
}
