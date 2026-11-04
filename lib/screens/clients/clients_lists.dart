// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/clients/clients.dart';
import 'package:adguard_home_manager/screens/clients/client/client_detail.dart';
import 'package:adguard_home_manager/screens/clients/client/client_screen_functions.dart';
import 'package:adguard_home_manager/screens/clients/client/device_tile.dart';
import 'package:adguard_home_manager/screens/clients/client/logs_list_client.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/models/dns_statistics.dart';
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
  /// search field and read busiest device first.
  List<DeviceRow> _devices(
    ClientsProvider clientsProvider,
    DnsStatistics? stats,
  ) {
    final rows = mergeDevices(
      active: clientsProvider.filteredActiveClients,
      added: clientsProvider.filteredAddedClients,
    ).where((row) {
      if (_filter == 1) return row.configured;
      if (_filter == 2) return !row.configured;
      return true;
    }).toList();

    if (stats == null) return rows;

    final counted = {
      for (final row in rows) row: queriesForDevice(stats, row) ?? -1,
    };

    rows.sort((a, b) {
      final byCount = counted[b]!.compareTo(counted[a]!);
      return byCount != 0
        ? byCount
        : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

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

    final stats = statusProvider.serverStatus?.stats;

    // The footer counts the devices the page lists, not the raw API arrays, so
    // a search narrowing the rows does not change what the page says the
    // server knows.
    final clients = clientsProvider.clients;
    final identified = clients == null
      ? null
      : mergeDevices(
          active: clients.autoClients,
          added: clients.clients,
        ).length;

    // The statistics window is what tells the page which devices have been
    // talking at all; the identified ones come from the client list.
    final foot = loaded
      ? [
          localizations.identifiedDevicesCount(
            intFormat(identified ?? 0, Platform.localeName),
          ),
          if (stats != null)
            localizations.devicesQueriedLastDay(
              intFormat(stats.topClients.length, Platform.localeName),
            ),
        ].join(' · ')
      : null;

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

    void confirmAddClient(Client client) async {
      final processModal = ProcessModal();
      processModal.open(localizations.addingClient);

      final result = await clientsProvider.addClient(client);

      if (!mounted) return;

      processModal.close();

      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: result == true
          ? localizations.clientAddedSuccessfully
          : localizations.clientNotAdded,
        color: result == true ? palette.green : palette.red,
      );
    }

    void openAddClient() {
      openClientFormModal(
        context: context,
        width: width,
        onConfirm: confirmAddClient,
      );
    }

    final rows = loaded ? _devices(clientsProvider, stats) : <DeviceRow>[];

    Widget card() => ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: palette.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < rows.length; index++)
              DeviceTile(
                row: rows[index],
                queries: queriesForDevice(stats, rows[index]),
                onTap: openDevice,
                selected: _selectedAddress != null &&
                    _selectedAddress == rows[index].logKey,
                splitView: widget.splitView,
                showSeparator: index != rows.length - 1,
              ),
          ],
        ),
      ),
    );

    Widget placeholder(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: child,
    );

    Widget deviceList;

    if (clientsProvider.loadStatus == LoadStatus.loading) {
      deviceList = placeholder(
        AppleLoading(label: localizations.loadingClients),
      );
    }
    else if (clientsProvider.loadStatus == LoadStatus.error) {
      deviceList = placeholder(
        AppleEmptyState(
          icon: CupertinoIcons.exclamationmark_triangle,
          title: localizations.errorLoadServerStatus,
          color: palette.orange,
        ),
      );
    }
    else if (rows.isEmpty) {
      deviceList = placeholder(
        AppleEmptyState(
          icon: CupertinoIcons.person_2,
          title: clientsProvider.searchTermClients != null
            ? localizations.noClientsSearch
            : localizations.noClientsList,
          color: palette.label3,
        ),
      );
    }
    else {
      deviceList = card();
    }

    return AppleScreen(
      title: localizations.devices,
      subtitle: foot,
      actions: [
        if (statusProvider.serverStatus != null) IconButton(
          onPressed: openAddClient,
          icon: const Icon(CupertinoIcons.plus),
          tooltip: localizations.addDeviceManually,
        ),
        const SizedBox(width: 8),
      ],
      searchbar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppleSearchField(
            controller: searchController,
            hint: localizations.searchDevicesHint,
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
            trailing: stats != null ? localizations.sortedByQueries : null,
          ),
        ],
      ),
      onRefresh: () => clientsProvider.fetchClients(updateLoading: false),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(top: widget.splitView ? 8 : 0),
          sliver: SliverToBoxAdapter(child: deviceList),
        ),
        SliverToBoxAdapter(
          child: AppleListSection(
            title: localizations.actionsGroup,
            children: [
              AppleListTile(
                icon: CupertinoIcons.plus,
                iconColor: palette.tint,
                title: localizations.addDeviceManually,
                subtitle: localizations.addDeviceManuallyHelper,
                showChevron: false,
                onTap: statusProvider.serverStatus != null
                  ? openAddClient
                  : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
