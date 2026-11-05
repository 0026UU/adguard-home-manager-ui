import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/home/management_modal/management_modal.dart';

import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/constants/enums.dart';

class HomeFab extends StatelessWidget {
  const HomeFab({super.key});

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<StatusProvider>(context);

    final width = MediaQuery.of(context).size.width;

    void openManagementBottomSheet() {
      if (width > 700) {
        showDialog(
          context: context,
          builder: (context) => const ManagementModal(
            dialog: true,
          ),
        );
      }
      else {
        showAppleSheet(
          context,
          useRootNavigator: true,
          title: AppLocalizations.of(context)!.allProtections,
          initialFraction: 0.65,
          body: const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ManagementModal(dialog: false),
          ),
        );
      }
    }

    return statusProvider.loadStatus == LoadStatus.loaded
      ? FloatingActionButton(
          onPressed: openManagementBottomSheet,
          backgroundColor: statusProvider.serverStatus!.generalEnabled == true
            ? AppleColors.green(ApplePalette.brightnessOf(context))
            : AppleColors.red(ApplePalette.brightnessOf(context)),
          foregroundColor: Colors.white,
          child: const Icon(CupertinoIcons.shield_fill),
        )
      : const SizedBox();
  }
}