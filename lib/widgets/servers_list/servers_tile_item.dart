// ignore_for_file: use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/servers_list/server_tile_functions.dart';

import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';

/// One saved AdGuard Home server, shown as a card on the connect and servers
/// screens: two side by side on wide layouts, full width on phones.
class ServersTileItem extends StatelessWidget {
  final Server server;
  final int index;
  final void Function(int) onChange;
  final double breakingWidth;

  const ServersTileItem({
    super.key,
    required this.server,
    required this.index,
    required this.onChange,
    required this.breakingWidth,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final serversProvider = Provider.of<ServersProvider>(context);
    final statusProvider = Provider.of<StatusProvider>(context);

    final width = MediaQuery.sizeOf(context).width;
    final wide = width > breakingWidth;

    final selected = serversProvider.selectedServer?.id == server.id;
    final connected = selected && statusProvider.serverStatus != null;
    final status = connected ? p.green : (selected ? p.orange : p.label3);

    final address =
        "${server.connectionMethod}://${server.domain}${server.path ?? ""}${server.port != null ? ':${server.port}' : ""}";

    return FractionallySizedBox(
      widthFactor: wide ? 0.5 : 1,
      child: Padding(
        padding: wide
            ? generateMargins(
                index: index,
                serversListLength: serversProvider.serversList.length)
            : const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: AppleCard(
          radius: BorderRadius.circular(14),
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      AppleIconBadge(
                        icon: CupertinoIcons.desktopcomputer,
                        color: status,
                        size: 34,
                        iconSize: 19,
                      ),
                      if (server.defaultServer == true)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              color: p.card,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.star_fill,
                              size: 9,
                              color: p.yellow,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: p.label,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          server.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: p.label2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: Icon(CupertinoIcons.ellipsis,
                        size: 20, color: p.label2),
                    onPressed: () => _openActions(
                      context,
                      width: width,
                      server: server,
                    ),
                  ),
                  const Spacer(),
                  if (selected)
                    ApplePill(
                      label: connected ? l.connected : l.selectedDisconnected,
                      color: status,
                      fontSize: 13,
                    )
                  else
                    AppleFormButton(
                      label: l.connect,
                      background: p.tint,
                      foreground: Colors.white,
                      width: 96,
                      onPressed: () =>
                          connectToServer(context: context, server: server),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openActions(
    BuildContext context, {
    required double width,
    required Server server,
  }) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final isDefault = server.defaultServer == true;

    showAppleActionSheet(
      context,
      title: server.name,
      cancelLabel: l.cancel,
      actions: [
        AppleSheetAction(
          label: isDefault ? l.defaultConnection : l.setDefault,
          icon: CupertinoIcons.star_fill,
          color: p.yellow,
          disabled: isDefault,
          onTap: () => setDefaultServer(context: context, server: server),
        ),
        AppleSheetAction(
          label: l.edit,
          icon: CupertinoIcons.pencil,
          onTap: () =>
              openServerModal(context: context, server: server, width: width),
        ),
        AppleSheetAction(
          label: l.delete,
          icon: CupertinoIcons.trash,
          color: p.red,
          destructive: true,
          onTap: () => showDeleteModal(context: context, server: server),
        ),
      ],
    );
  }
}
