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
import 'package:adguard_home_manager/screens/logs/logs.dart';

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

    // The provider keeps the term across tab switches even though this widget
    // does not, so the box starts from it rather than showing a narrowed list
    // with nothing in the field that narrowed it.
    final term = clientsProvider.searchTermClients;
    if (term != null && term.isNotEmpty) searchController.text = term;

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

    final rows = loaded ? _devices(clientsProvider, stats) : <DeviceRow>[];

    // The header counts the rows the page lists, so a search or a segment
    // narrows the number and the list together. What is left for this line is
    // the one number that counts something else: the addresses the statistics
    // window saw talk, which comes from the log, not from the client list.
    final foot = loaded && stats != null
      ? localizations.devicesSeenInStatistics(stats.topClients.length)
      : null;

    // The note promises the order of the list, which is only true once one of
    // its devices has a query to be sorted by.
    final sortedByQueries = stats != null &&
        rows.any((row) => (queriesForDevice(stats, row) ?? 0) > 0);

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

    // The count on a row is its own way into the query log of that device,
    // and it has to work the same for a device with custom settings as for one
    // without: the row tap still opens the device (the edit form when it has
    // an entry), but this pushes the Logs screen with the client id pre-applied
    // to the filter, so the list narrows to that device at once and the filter
    // sheet shows it already selected.
    void openDeviceLog(DeviceRow row) {
      // A log row names its client the way the server does — the configured
      // label, else the one the network gave, else the address — while
      // `logKey` may be a MAC the log never carries, so the narrowing keys on
      // the row's own label.
      final page = Logs(initialClients: [row.name]);

      if (widget.splitView) {
        Navigator.of(clientsNavigatorKey.currentContext!).push(
          MaterialPageRoute(builder: (context) => page),
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

      var added = false;
      String? reason;
      try {
        final result = await clientsProvider.addClient(client);
        added = result.successful == true;
        reason = result.message;
      } on Object {
        // Building the body used to throw for a device carrying safe search,
        // which left the undismissable "Adding client…" sheet over the app.
      } finally {
        // The sheet lives on the global navigator, so it outlives this page:
        // leaving it open when the tab is swapped mid-request — or when the
        // request throws — would strand an "Adding client…" dialog nobody can
        // dismiss.
        processModal.close();
      }

      if (!mounted) return;

      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: added
          ? localizations.clientAddedSuccessfully
          : reason ?? localizations.clientNotAdded,
        color: added ? palette.green : palette.red,
      );
    }

    void openAddClient() {
      openClientFormModal(
        context: context,
        width: width,
        onConfirm: confirmAddClient,
      );
    }

    // A device removed from the server is gone from these rows, but the
    // address this page remembered is not; highlighting nothing for it stops
    // the wide pane from pointing at a row that no longer exists.
    final selectedIsListed = _selectedAddress != null &&
        rows.any((row) => row.logKey == _selectedAddress);

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
                onQueriesTap: openDeviceLog,
                selected: selectedIsListed &&
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
          // This is the device list that did not load, not the server status,
          // and the line under it has to offer the one thing that can help.
          title: localizations.clientsNotLoaded,
          color: palette.orange,
          action: AppleFormButton(
            label: localizations.refresh,
            background: palette.tint,
            foreground: onTint(palette.tint),
            onPressed: () => clientsProvider.fetchClients(updateLoading: true),
          ),
        ),
      );
    }
    else if (rows.isEmpty) {
      final bySegment = clientsProvider.searchTermClients == null && _filter != 0;
      deviceList = placeholder(
        AppleEmptyState(
          icon: CupertinoIcons.person_2,
          // A segment that hides every device has not emptied the network, so
          // the headline says which of the two left nothing to show.
          title: clientsProvider.searchTermClients != null
            ? localizations.noClientsSearch
            : bySegment
              ? localizations.noDevicesInSegment
              : localizations.noClientsList,
          message: bySegment ? localizations.switchDeviceSegment : null,
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
            trailing: loaded
              ? [
                  localizations.shownDevices(
                    rows.length,
                    intFormat(rows.length, Platform.localeName),
                  ),
                  if (sortedByQueries) localizations.sortedByQueries,
                ].join(' · ')
              : null,
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
