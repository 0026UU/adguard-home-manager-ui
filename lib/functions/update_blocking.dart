import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Turns one protection on or off and reports what the server answered.
///
/// [filter] is the name the API takes (`general`, `filtering`, `safeBrowsing`,
/// `parentalControl`, `safeSearch`) and [time] is how long a pause should
/// last, in milliseconds.
Future<void> toggleProtection({
  required BuildContext context,
  required String filter,
  required bool value,
  int? time,
}) async {
  final statusProvider = Provider.of<StatusProvider>(context, listen: false);
  final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);

  final result = await statusProvider.updateBlocking(
    block: filter,
    newStatus: value,
    time: time,
  );

  if (context.mounted && result == false) {
    showSnackbar(
      appConfigProvider: appConfigProvider,
      // A rejected switch is not necessarily an auth problem; the server can
      // refuse for any number of reasons and blaming the password sends the
      // user to change a credential that was fine.
      label: AppLocalizations.of(context)!.protectionNotChanged,
      color: ApplePalette.of(context).red,
    );
  }
}
