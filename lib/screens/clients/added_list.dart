// ignore_for_file: use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/clients/clients.dart';
import 'package:adguard_home_manager/screens/clients/client/client_screen_functions.dart';
import 'package:adguard_home_manager/screens/clients/client/added_client_tile.dart';
import 'package:adguard_home_manager/screens/clients/client/remove_client_modal.dart';
import 'package:adguard_home_manager/screens/clients/fab.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/tab_content_list.dart';

import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';

class AddedList extends StatelessWidget {
  final List<Client> data;
  final void Function(Client) onClientSelected;
  final Client? selectedClient;
  final bool splitView;

  const AddedList({
    super.key,
    required this.data,
    required this.onClientSelected,
    this.selectedClient,
    required this.splitView
  });

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<StatusProvider>(context);
    final clientsProvider = Provider.of<ClientsProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final localizations = AppLocalizations.of(context)!;
    final palette = ApplePalette.of(context);

    final width = MediaQuery.of(context).size.width;

    void confirmEditClient(Client client) async {
      ProcessModal processModal = ProcessModal();
      if (context.mounted) {
        processModal.open(localizations.savingChanges);
      }
      
      final result = await clientsProvider.editClient(client);

      if (!context.mounted) return;

      processModal.close();
      
      if (result == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: localizations.clientUpdatedSuccessfully, 
          color: Colors.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: localizations.clientNotUpdated, 
          color: Colors.red
        );
      }
    }

    void deleteClient(Client client) async {
      ProcessModal processModal = ProcessModal();
      processModal.open(localizations.removingClient);
      
      final result = await clientsProvider.deleteClient(client);
    
      processModal.close();

      if (result == true) {
        if (splitView == true) {
          Navigator.of(clientsNavigatorKey.currentContext!).popUntil((route) => false);
        }
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: localizations.clientDeletedSuccessfully, 
          color: Colors.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: localizations.clientNotDeleted, 
          color: Colors.red
        );
      }
    }  

    void openClientModal(Client client) {
      openClientFormModal(
        context: context, 
        width: width, 
        client: client,
        onConfirm: confirmEditClient,
        onDelete: deleteClient
      );
    }

    void openDeleteModal(Client client) {
      showModal(
        context: context, 
        builder: (ctx) => RemoveClientModal(
          onConfirm: () => deleteClient(client)
        )
      );
    }

    // The provider already filters by the search term; this keeps the added
    // list in sync with names and ids as before.
    final clientsDisplay = clientsProvider.searchTermClients != null && clientsProvider.searchTermClients != ""
      ? data.where(
          (c) => c.name.toLowerCase().contains(clientsProvider.searchTermClients.toString()) || c.ids.where((id) => id.contains(clientsProvider.searchTermClients.toString())).isNotEmpty
        ).toList()
      : data;

    return CustomTabContentList(
      insetCard: true,
      listPadding: splitView == true 
        ? const EdgeInsets.only(top: 8)
        : null,
      loadingGenerator: () => AppleLoading(
        label: localizations.loadingStatus,
      ),
      itemsCount: clientsDisplay.length,
      contentWidget: (index) => AddedClientTile(
        selectedClient: selectedClient,
        client: clientsDisplay[index], 
        onTap: onClientSelected,
        onEdit: statusProvider.serverStatus != null
          ? (c) => openClientModal(c)
          : null,
        onDelete: openDeleteModal,
        splitView: splitView,
        showSeparator: index != clientsDisplay.length - 1,
      ),
      noData: Center(
        child: AppleEmptyState(
          icon: CupertinoIcons.person_2,
          title: localizations.noClientsList,
          color: palette.label3,
          action: SizedBox(
            width: 180,
            child: AppleButton.secondary(
              label: localizations.refresh,
              icon: CupertinoIcons.arrow_2_circlepath,
              onPressed: () => clientsProvider.fetchClients(updateLoading: true),
            ),
          ),
        ),
      ), 
      errorGenerator: () => Center(
        child: AppleEmptyState(
          icon: CupertinoIcons.exclamationmark_triangle,
          title: localizations.errorLoadServerStatus,
          color: palette.orange,
        ),
      ), 
      loadStatus: statusProvider.loadStatus == LoadStatus.loading || clientsProvider.loadStatus == LoadStatus.loading
        ? LoadStatus.loading
        : clientsProvider.loadStatus, 
      onRefresh: () => clientsProvider.fetchClients(updateLoading: false),
      fab: const ClientsFab(),
      fabVisible: true,
    );
  }
}
