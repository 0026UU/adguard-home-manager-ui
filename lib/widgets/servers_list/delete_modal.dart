import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

class DeleteModal extends StatelessWidget {
  final Server serverToDelete;

  const DeleteModal({
    super.key,
    required this.serverToDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final serversProvider =
        Provider.of<ServersProvider>(context, listen: false);
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);

    void removeServer() async {
      final previouslySelectedServer = serversProvider.selectedServer;

      final deleted = await serversProvider.removeServer(serverToDelete);

      if (deleted == true) {
        if (previouslySelectedServer != null &&
            previouslySelectedServer.id == serverToDelete.id) {
          appConfigProvider.setSelectedScreen(0);
        }

        showSnackbar(
            appConfigProvider: appConfigProvider,
            label: l.connectionRemoved,
            color: p.green);
      } else {
        showSnackbar(
            appConfigProvider: appConfigProvider,
            label: l.connectionCannotBeRemoved,
            color: p.red);
      }
    }

    return AppleAlertDialog(
      title: l.remove,
      message:
          "${l.removeWarning}\n\n${serverToDelete.connectionMethod}://${serverToDelete.domain}${serverToDelete.path ?? ""}${serverToDelete.port != null ? ':${serverToDelete.port}' : ""}",
      actions: [
        AppleSheetAction(label: l.cancel),
        AppleSheetAction(
            label: l.remove, destructive: true, onTap: removeServer),
      ],
    );
  }
}
