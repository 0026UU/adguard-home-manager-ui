// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Switch one filter list on or off, the way both the row itself and the
/// context menu do it.
Future<void> toggleFilterList({
  required BuildContext context,
  required Filter list,
  required String listType,
}) async {
  final l = AppLocalizations.of(context)!;
  final filteringProvider = Provider.of<FilteringProvider>(context, listen: false);
  final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);

  final ProcessModal processModal = ProcessModal();
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

  final palette = ApplePalette.of(context);

  showSnackbar(
    appConfigProvider: appConfigProvider,
    label: result == true ? l.listDataUpdated : l.listDataNotUpdated,
    color: result == true ? palette.green : palette.red
  );
}
