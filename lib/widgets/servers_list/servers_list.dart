// ignore_for_file: use_build_context_synchronously
import 'package:flutter/cupertino.dart';
import 'package:expandable/expandable.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/servers_list/servers_tile_item.dart';

import 'package:adguard_home_manager/providers/servers_provider.dart';

class ServersList extends StatelessWidget {
  final BuildContext context;
  final List<ExpandableController> controllers;
  final Function(int) onChange;
  final ScrollController scrollController;
  final double breakingWidth;

  const ServersList({
    super.key,
    required this.context,
    required this.controllers,
    required this.onChange,
    required this.scrollController,
    required this.breakingWidth
  });

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    
    if (serversProvider.serversList.isNotEmpty) {
      return ListView(
        children: [
          Wrap(
            children: serversProvider.serversList.asMap().entries.map(
              (s) => ServersTileItem(
                breakingWidth: breakingWidth,
                server: serversProvider.serversList[s.key], 
                index: s.key, 
                onChange: onChange
              )
            ).toList(),
          ),
          const SizedBox(height: 8)
        ],
      );
    }

    return Center(
      child: AppleEmptyState(
        icon: CupertinoIcons.desktopcomputer,
        title: AppLocalizations.of(context)!.noSavedConnections,
        color: ApplePalette.of(context).label3,
      ),
    );
  }
}