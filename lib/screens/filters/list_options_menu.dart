// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/widgets/options_menu.dart';
import 'package:adguard_home_manager/screens/filters/selection/selection_screen.dart';

import 'package:adguard_home_manager/functions/open_url.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/functions/copy_clipboard.dart';
import 'package:adguard_home_manager/models/menu_option.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

class ListOptionsMenu extends StatelessWidget {
  final Filter list;
  final Widget child;
  final String listType;

  const ListOptionsMenu({
    super.key,
    required this.list,
    required this.child,
    required this.listType,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final filteringProvider = Provider.of<FilteringProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final width = MediaQuery.of(context).size.width;

    void enableDisable() async {
      ProcessModal processModal = ProcessModal();
      processModal.open(
        list.enabled == true
          ? l.disablingList
          : l.enablingList
      );

      final result = await filteringProvider.updateList(
        list: list, 
        type: listType, 
        action: list.enabled == true
          ? FilteringListActions.disable
          : FilteringListActions.enable
      );

      processModal.close();
      
      if (!context.mounted) return;
      if (result == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.listDataUpdated, 
          color: ApplePalette.of(context).green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.listDataNotUpdated, 
          color: ApplePalette.of(context).red
        );
      }
    }

    void openSelectionMode() {
      showGeneralDialog(
        context: context, 
        barrierColor: !(width > 900 || !(Platform.isAndroid | Platform.isIOS))
          ?Colors.transparent 
          : Colors.black54,
        transitionBuilder: (context, anim1, anim2, child) {
          return SlideTransition(
            position: Tween(
              begin: const Offset(0, 1), 
              end: const Offset(0, 0)
            ).animate(
              CurvedAnimation(
                parent: anim1, 
                curve: Curves.easeInOutCubicEmphasized
              )
            ),
            child: child,
          );
        },
        pageBuilder: (context, animation, secondaryAnimation) => SelectionScreen(
          isModal: width > 900 || !(Platform.isAndroid | Platform.isIOS)
        )
      );
    }

    return OptionsMenu(
      options: (_) => [
        MenuOption(
          title: list.enabled == true ? l.disable : l.enable,
          icon: list.enabled == true
            ? CupertinoIcons.nosign
            : CupertinoIcons.checkmark_shield,
          action: () => enableDisable()
        ),
        MenuOption(
          title: l.copyListUrl,
          icon: CupertinoIcons.doc_on_clipboard,
          action: () => copyToClipboard(
            value: list.url, 
            successMessage: l.listUrlCopied
          )
        ),
        MenuOption(
          title: l.openListUrl,
          icon: CupertinoIcons.arrow_up_right,
          action: () => openUrl(list.url)
        ),
        MenuOption(
          title: l.selectionMode,
          icon: CupertinoIcons.checkmark,
          action: () => Future.delayed(
            const Duration(milliseconds: 0), 
            () => openSelectionMode()
          )
        ),
      ],
      child: child
    );
  }
}
