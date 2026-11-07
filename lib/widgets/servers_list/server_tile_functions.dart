import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/widgets/add_server/unsupported_version_modal.dart';
import 'package:adguard_home_manager/widgets/servers_list/delete_modal.dart';
import 'package:adguard_home_manager/widgets/add_server/add_server_functions.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/config/minimum_server_version.dart';
import 'package:adguard_home_manager/functions/compare_versions.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/auth_error_message.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/services/api_client.dart';
import 'package:adguard_home_manager/services/auth.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/models/server.dart';

EdgeInsets generateMargins({
  required int index,
  required int serversListLength
}) {
  if (index == 0) {
    return const EdgeInsets.only(top: 16, left: 16, right: 8, bottom: 8);
  }
  if (index == 1) {
    return const EdgeInsets.only(top: 16, left: 8, right: 16, bottom: 8);
  }
  else if (index == serversListLength-1 && (index+1)%2 == 0) {
    return const EdgeInsets.only(top: 8, left: 8, right: 16, bottom: 16);
  }
  else if (index == serversListLength-1 && (index+1)%2 == 1) {
    return const EdgeInsets.only(top: 8, left: 16, right: 8, bottom: 16);
  }
  else {
    if ((index+1)%2 == 0) {
      return const EdgeInsets.only(top: 8, left: 8, right: 16, bottom: 8);
    }
    else {
      return const EdgeInsets.only(top: 8, left: 16, right: 8, bottom: 8);
    }
  }
}

void showDeleteModal({
  required BuildContext context,
  required Server server
}) async {
  await Future.delayed(const Duration(seconds: 0), () {
    if (!context.mounted) return;
    showDialog(
      context: context, 
      builder: (context) => DeleteModal(
        serverToDelete: server,
      ),
      barrierDismissible: false
    );
  });
}

void openServerModal({
  required BuildContext context,
  required double width,
  Server? server,
}) async {
  await Future.delayed(const Duration(seconds: 0), (() => {
    openServerFormModal(context: context, width: width, server: server)
  }));
}

void connectToServer({
  required BuildContext context,
  required Server server
}) async {
  final ProcessModal process = ProcessModal();
  process.open(AppLocalizations.of(context)!.connecting);
      
  final result = server.runningOnHa == true 
    ? await ServerAuth.loginHA(server)
    : await ServerAuth.login(server);
        
  if (result == AuthStatus.success && context.mounted) {
    final serversProvider = Provider.of<ServersProvider>(context, listen: false);
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    
    final ApiClientV2 apiClient2 = ApiClientV2(server: server);

    // The client is only installed once the server has answered: pointing it
    // at a row that failed its own status call would leave every screen still
    // showing the previous server while its writes went to the dead one.
    statusProvider.setServerStatusLoad(LoadStatus.loading);
    final serverStatus = await apiClient2.getServerStatus();
    if (serverStatus.successful == true) {
      final status = serverStatus.content as ServerStatus;

      // Check if server version is supported
      final tooOld = serverVersionIsTooOld(
        currentVersion: status.serverVersion, 
        referenceVersion: MinimumServerVersion.stable,
        referenceVersionBeta: MinimumServerVersion.beta
      );
      if (tooOld) {
        process.close();
        showDialog(
          context: globalNavigatorKey.currentContext!, 
          builder: (ctx) => UnsupportedVersionModal(
            serverVersion: status.serverVersion, 
            onClose: () {
              serversProvider.setSelectedServer(null);
            }
          )
        );
        return;
      }
      
      serversProvider.setApiClient2(apiClient2);
      serversProvider.setSelectedServer(server);
      // Connecting from a tile has to survive the next launch: the row that
      // is not written as the default is forgotten, and the app comes back on
      // the two-tab bar with the user reconnecting by hand every time.
      await serversProvider.setDefaultServer(server);
      statusProvider.setServerStatusData(
        data: status
      );
      serversProvider.checkServerUpdatesAvailable(
        server: server,
      );
      statusProvider.setServerStatusLoad(LoadStatus.loaded);
    }
    else {
      statusProvider.setServerStatusLoad(LoadStatus.error);
      process.close();

      // The credentials worked but the status call did not, so the sheet just
      // vanishes and the user is back where they started with nothing said.
      // Login failure is already reported below; this is the other half.
      if (context.mounted) {
        showSnackbar(
          appConfigProvider:
              Provider.of<AppConfigProvider>(context, listen: false),
          label: AppLocalizations.of(context)!.errorLoadServerStatus,
          color: ApplePalette.of(context).red,
        );
      }

      return;
    }
    process.close();
  }
  else {
    process.close();
    if (!context.mounted) return;
    final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);
    showSnackbar(
      appConfigProvider: appConfigProvider, 
      // The tile knows which of the four things went wrong; saying so is the
      // difference between fixing a typo and rebooting a working server.
      label: authErrorMessage(context, result), 
      color: ApplePalette.of(context).red
    );
  }
}

void setDefaultServer({
  required BuildContext context,
  required Server server
}) async {
  final serversProvider = Provider.of<ServersProvider>(context, listen: false);
  final result = await serversProvider.setDefaultServer(server);
  if (!context.mounted) return;
  final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);
  if (result == null) {
    showSnackbar(
      appConfigProvider: appConfigProvider, 
      label: AppLocalizations.of(context)!.connectionDefaultSuccessfully, 
      color: ApplePalette.of(context).green
    );
  }
  else {
    showSnackbar(
      appConfigProvider: appConfigProvider, 
      label: AppLocalizations.of(context)!.connectionDefaultFailed, 
      color: ApplePalette.of(context).red
    );
  }
}