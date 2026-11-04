// ignore_for_file: use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/clients/clients.dart';
import 'package:adguard_home_manager/screens/clients/client/client_detail.dart';
import 'package:adguard_home_manager/screens/clients/client/client_screen_functions.dart';
import 'package:adguard_home_manager/screens/clients/client/device_tile.dart';
import 'package:adguard_home_manager/screens/clients/client/logs_list_client.dart';
import 'package:adguard_home_manager/screens/clients/fab.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/tab_content_list.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';

class ClientsLists extends StatefulWidget {
  final bool splitView;

  const ClientsLists({
    super.key,
    required this.splitView,
  });

  @override
  State<ClientsLists> createState() => _ClientsListsState();
}

class _ClientsListsState extends State<ClientsLists> {
  final TextEditingController searchController = TextEditingController();

  /// Device the detail pane is showing, on the wide layout.
  String? _selectedAddress;

  /// 0: every device, 1: the ones with a client entry, 2: the ones without.
  /// Kept in the preference that used to remember the tab of the old list.
  late int _filter;

  @override
  void initState() {
    _filter = Provider.of<AppConfigProvider>(context, listen: false).selectedClientsTab;

    final clientsProvider = Provider.of<ClientsProvider>(context, listen: false);
    clientsProvider.fetchClients(updateLoading: true);

    super.initState();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  /// The one list the design layer draws, narrowed by the segment under the
  /// search field.
  List<DeviceRow> _devices(ClientsProvider clientsProvider) {
    final rows = mergeDevices(
      active: clientsProvider.filteredActiveClients,
      added: clientsProvider.filteredAddedClients,
    );

    if (_filter == 1) return rows.where((row) => row.configured).toList();
    if (_filter == 2) return rows.where((row) => !row.configured).toList();
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final clientsProvider = Provider.of<ClientsProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final statusProvider = Provider.of<StatusProvider>(context);
    final localizations = AppLocalizations.of(context)!;

    final loaded = clientsProvider.loadStatus == LoadStatus.loaded;
    final palette = ApplePalette.of(context);
    final width = MediaQuery.sizeOf(context).width;

    final all = clientsProvider.clients;
    final foot = all == null
      ? null
      : "${localizations.identifiedDevicesCount(all.autoClients.length)} · "
          "${localizations.customSettingsCount(all.clients.length)}";

    void openDevice(DeviceRow row) {
      setState(() => _selectedAddress = row.logKey);

      // A device with an entry written for it opens the page that reads that
      // entry. One the server only knows by address has no settings of its own,
      // so all there is to show is what it queried.
      final page = row.configured
        ? ClientDetailScreen(client: row.client!)
        : LogsListClient(
            ip: row.logKey,
            name: row.name,
            serversProvider: serversProvider,
            appConfigProvider: appConfigProvider,
            splitView: widget.splitView,
          );

      if (widget.splitView) {
        Navigator.of(clientsNavigatorKey.currentContext!).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => page,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          )
        );
      }
      else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => page),
        );
      }
    }

    void confirmEditClient(Client client) async {
      final processModal = ProcessModal();
      processModal.open(localizations.savingChanges);

      final result = await clientsProvider.editClient(client);

      if (!mounted) return;

      processModal.close();

      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: result == true
          ? localizations.clientUpdatedSuccessfully
          : localizations.clientNotUpdated,
        color: result == true ? Colors.green : Colors.red,
      );
    }

    void deleteClient(Client client) async {
      final processModal = ProcessModal();
      processModal.open(localizations.removingClient);

      final result = await clientsProvider.deleteClient(client);

      if (!mounted) return;

      processModal.close();

      if (result == true) {
        if (widget.splitView) {
          Navigator.of(clientsNavigatorKey.currentContext!).popUntil((route) => false);
        }
        setState(() => _selectedAddress = null);
      }

      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: result == true
          ? localizations.clientDeletedSuccessfully
          : localizations.clientNotDeleted,
        color: result == true ? Colors.green : Colors.red,
      );
    }

    void editDevice(Client client) {
      openClientFormModal(
        context: context,
        width: width,
        client: client,
        onConfirm: confirmEditClient,
        onDelete: deleteClient,
      );
    }

    final rows = loaded ? _devices(clientsProvider) : <DeviceRow>[];

    return AppleScreen(
      title: localizations.devices,
      subtitle: foot,
      searchbar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppleSearchField(
            controller: searchController,
            hint: localizations.searchClients,
            onChanged: (value) => clientsProvider.setSearchTermClients(
              value.isEmpty ? null : value
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppleSegmented(
              labels: [
                localizations.all,
                localizations.onlyCustom,
                localizations.onlyDefault,
              ],
              selectedIndex: _filter,
              onChanged: (index) {
                setState(() => _filter = index);
                appConfigProvider.setSelectedClientsTab(index);
              },
            ),
          ),
          AppleGroupHeader(
            title: localizations.identifiedDevices,
            trailing: localizations.shownDevices(rows.length),
          ),
        ],
      ),
      body: ColoredBox(
        color: palette.card,
        child: CustomTabContentList(
          insetCard: true,
          listPadding: widget.splitView ? const EdgeInsets.only(top: 8) : null,
          loadingGenerator: () => AppleLoading(
            label: localizations.loadingClients,
          ),
          itemsCount: rows.length,
          contentWidget: (index) => DeviceTile(
            row: rows[index],
            onTap: openDevice,
            selected: _selectedAddress != null && _selectedAddress == rows[index].logKey,
            onEdit: statusProvider.serverStatus != null ? editDevice : null,
            onDelete: statusProvider.serverStatus != null
              ? (client) => openDeleteClientScreen(
                  context: context,
                  onDelete: () => deleteClient(client),
                )
              : null,
            splitView: widget.splitView,
            showSeparator: index != rows.length - 1,
          ),
          noData: Center(
            child: AppleEmptyState(
              icon: CupertinoIcons.person_2,
              title: clientsProvider.searchTermClients != null
                ? localizations.noClientsSearch
                : localizations.noClientsList,
              color: palette.label3,
              action: SizedBox(
                width: 180,
                child: AppleButton.secondary(
                  label: localizations.refresh,
                  icon: CupertinoIcons.arrow_2_circlepath,
                  onPressed: () => clientsProvider.fetchClients(updateLoading: false),
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
          loadStatus: clientsProvider.loadStatus,
          onRefresh: () => clientsProvider.fetchClients(updateLoading: false),
          fab: const ClientsFab(),
          fabVisible: true,
        ),
      ),
    );
  }
}
