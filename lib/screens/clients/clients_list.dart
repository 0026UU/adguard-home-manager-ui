import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/clients/client/active_client_tile.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/tab_content_list.dart';

import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/models/clients.dart';

class ClientsList extends StatelessWidget {
  final List<AutoClient> data;
  final void Function(AutoClient) onClientSelected;
  final AutoClient? selectedClient;
  final bool splitView;

  const ClientsList({
    super.key,
    required this.data,
    required this.onClientSelected,
    this.selectedClient,
    required this.splitView,
  });

  @override
  Widget build(BuildContext context) {
    final clientsProvider = Provider.of<ClientsProvider>(context);
    final localizations = AppLocalizations.of(context)!;
    final palette = ApplePalette.of(context);

    return CustomTabContentList(
      listPadding: splitView == true 
        ? const EdgeInsets.only(top: 8)
        : null,
      loadingGenerator: () => AppleLoading(
        label: localizations.loadingStatus,
      ), 
      itemsCount: data.length, 
      contentWidget: (index) => ActiveClientTile(
        client: data[index], 
        onTap: onClientSelected,
        splitView: splitView,
        selectedClient: selectedClient,
        showSeparator: index != data.length - 1,
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
    );
  }
}
