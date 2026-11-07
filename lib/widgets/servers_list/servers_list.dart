import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/add_server/add_server_functions.dart';
import 'package:adguard_home_manager/widgets/servers_list/servers_tile_item.dart';

import 'package:adguard_home_manager/providers/servers_provider.dart';

/// The saved connections, as the connect and servers screens show them.
class ServersList extends StatelessWidget {
  final double breakingWidth;

  const ServersList({
    super.key,
    required this.breakingWidth,
  });

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);

    // Both screens that show this list hand it to [AppleScreen] as its own
    // scrolling body, which parks the content under the pinned bar unless the
    // inner scroll view gives the bar's overlap back first.
    return Builder(
      builder: (context) => CustomScrollView(
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          if (serversProvider.serversList.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Wrap(
                children: serversProvider.serversList.asMap().entries.map(
                  (s) => ServersTileItem(
                    breakingWidth: breakingWidth,
                    server: serversProvider.serversList[s.key],
                    index: s.key,
                  ),
                ).toList(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ]
          else
            // The first screen a new user sees has to say what to do next, not
            // just that something is missing: the only other way in was an
            // unlabelled floating button that hid as soon as they scrolled.
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: AppleEmptyState(
                  icon: CupertinoIcons.desktopcomputer,
                  title: AppLocalizations.of(context)!.noSavedConnections,
                  message: AppLocalizations.of(context)!.noSavedConnectionsHint,
                  color: ApplePalette.of(context).label3,
                  action: AppleButton(
                    label: AppLocalizations.of(context)!.createConnection,
                    icon: CupertinoIcons.plus,
                    onPressed: () => openServerFormModal(
                      context: context,
                      width: MediaQuery.sizeOf(context).width,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
