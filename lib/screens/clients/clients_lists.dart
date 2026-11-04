import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/clients/clients.dart';
import 'package:adguard_home_manager/screens/clients/added_list.dart';
import 'package:adguard_home_manager/screens/clients/client/logs_list_client.dart';
import 'package:adguard_home_manager/screens/clients/clients_list.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';

class ClientsLists extends StatefulWidget {
  final bool splitView;

  const ClientsLists({
    super.key,
    required this.splitView,
  });

  @override
  State<ClientsLists> createState() => _ClientsListsState();
}

class _ClientsListsState extends State<ClientsLists> with TickerProviderStateMixin {
  late TabController tabController;
  final TextEditingController searchController = TextEditingController();

  AutoClient? _selectedAutoClient;
  Client? _selectedClient;

  @override
  void initState() {
    final clientsProvider = Provider.of<ClientsProvider>(context, listen: false);
    clientsProvider.fetchClients(updateLoading: true);

    super.initState();
    tabController = TabController(
      initialIndex: Provider.of<AppConfigProvider>(context, listen: false).selectedClientsTab,
      length: 2,
      vsync: this,
    );
    tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    Provider.of<AppConfigProvider>(context, listen: false)
      .setSelectedClientsTab(tabController.index);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final clientsProvider = Provider.of<ClientsProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final loaded = clientsProvider.loadStatus == LoadStatus.loaded;
    final palette = ApplePalette.of(context);

    void onAutoClientSelected(AutoClient client) {
      setState(() => _selectedAutoClient = client);
      final w = LogsListClient(
        ip: client.ip, 
        serversProvider: serversProvider, 
        appConfigProvider: appConfigProvider,
        splitView: widget.splitView,
      );
      if (widget.splitView) {
        Navigator.of(clientsNavigatorKey.currentContext!).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => w,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          )
        );
      }
      else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => w,
          )
        );
      }
    }
    
    void onClientSelected(Client client) {
      setState(() => _selectedClient = client);
      final w = LogsListClient(
        ip: client.ids[0], 
        serversProvider: serversProvider, 
        appConfigProvider: appConfigProvider,
        splitView: widget.splitView,
      );
      if (widget.splitView) {
        Navigator.of(clientsNavigatorKey.currentContext!).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => w,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          )
        );
      }
      else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => w,
          )
        );
      }
    }

    return AppleScreen(
      title: AppLocalizations.of(context)!.clients,
      subtitle: loaded
        ? "${clientsProvider.clients?.autoClients.length ?? 0} "
              "${AppLocalizations.of(context)!.activeClients} · "
              "${clientsProvider.clients?.clients.length ?? 0} "
              "${AppLocalizations.of(context)!.added}"
        : null,
      header: AppleSegmented(
        labels: [
          AppLocalizations.of(context)!.activeClients,
          AppLocalizations.of(context)!.added,
        ],
        selectedIndex: tabController.index,
        onChanged: (index) => tabController.index = index,
      ),
      searchbar: loaded
        ? AppleSearchField(
            controller: searchController,
            hint: AppLocalizations.of(context)!.searchClients,
            onChanged: (value) => clientsProvider.setSearchTermClients(
              value.isEmpty ? null : value
            ),
          )
        : null,
      body: ColoredBox(
        color: palette.card,
        child: TabBarView(
          controller: tabController,
          children: [
            ClientsList(
              data: loaded ? clientsProvider.filteredActiveClients : [],
              onClientSelected: onAutoClientSelected,
              selectedClient: _selectedAutoClient,
              splitView: widget.splitView,
            ),
            AddedList(
              data: loaded ? clientsProvider.filteredAddedClients : [], 
              onClientSelected: onClientSelected,
              selectedClient: _selectedClient,
              splitView: widget.splitView,
            ),
          ]
        ),
      ),
    );
  }
}
