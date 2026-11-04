import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/options_menu.dart';

import 'package:adguard_home_manager/models/menu_option.dart';
import 'package:adguard_home_manager/functions/copy_clipboard.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';

/// A device as the merged list shows it: an address the server has seen, with
/// the client entry configured for it when the administrator added one.
class DeviceRow {
  final String name;

  /// Address, or the whole identifier list of a manually added client.
  final String address;

  /// Address to look the device up in the query log.
  final String logKey;

  /// How the server found the device (dns, dhcp, manual…).
  final String? source;

  /// The configured client, when there is one.
  final Client? client;

  const DeviceRow({
    required this.name,
    required this.address,
    required this.logKey,
    this.source,
    this.client,
  });

  bool get configured => client != null;
}

/// The one list the design layer draws: every address the server has seen,
/// each carrying the client entry written for it, plus the entries no query
/// has come from yet. Sorted by name, the way the page reads top to bottom.
List<DeviceRow> mergeDevices({
  required List<AutoClient> active,
  required List<Client> added,
}) {
  final claimed = <Client>{};
  final rows = <DeviceRow>[];

  for (final auto in active) {
    Client? match;
    for (final client in added) {
      if (client.ids.contains(auto.ip)) {
        match = client;
        break;
      }
    }
    if (match != null) claimed.add(match);

    final named = auto.name != null && auto.name!.isNotEmpty;
    rows.add(DeviceRow(
      // The label the administrator wrote wins over the one the network gave.
      name: match?.name ?? (named ? auto.name! : auto.ip),
      address: auto.ip,
      logKey: auto.ip,
      source: auto.source,
      client: match,
    ));
  }

  for (final client in added) {
    if (claimed.contains(client)) continue;

    rows.add(DeviceRow(
      name: client.name,
      address: client.ids.join(', '),
      logKey: client.ids.isNotEmpty ? client.ids.first : '',
      client: client,
    ));
  }

  rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return rows;
}

/// One row of the devices list, as the design layer draws it: an initial on a
/// seeded gradient, the address and its configuration state, then the source.
class DeviceTile extends StatelessWidget {
  final DeviceRow row;
  final void Function(DeviceRow) onTap;
  final void Function(Client)? onEdit;
  final void Function(Client)? onDelete;
  final bool selected;
  final bool splitView;

  /// Trailing hairline; disabled for the last row of a list.
  final bool showSeparator;

  const DeviceTile({
    super.key,
    required this.row,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.selected = false,
    required this.splitView,
    this.showSeparator = true,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final palette = ApplePalette.of(context);

    final configured = row.configured;
    final state = configured
      ? localizations.hasCustomSettings
      : localizations.hasDefaultSettings;

    final tile = AppleListTile(
      title: row.name,
      leading: AppleAvatar(
        text: row.name,
        size: 40,
        color: palette.seeded(row.name),
        gradientTo: palette.seededAlt(row.name),
      ),
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${row.address} · $state",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (configured) ...[
            const SizedBox(height: 6),
            ClientStatusIcons(client: row.client!),
          ],
        ],
      ),
      value: row.source,
      onTap: () => onTap(row),
      showChevron: !splitView,
      selected: splitView && selected,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leadingWidth: 40,
    );

    return OptionsMenu(
      options: (_) => [
        if (configured && onEdit != null)
          MenuOption(
            title: localizations.seeDetails,
            icon: CupertinoIcons.pencil,
            action: () => onEdit!(row.client!),
          ),
        if (configured && onDelete != null)
          MenuOption(
            title: localizations.removeClient,
            icon: CupertinoIcons.trash,
            action: () => onDelete!(row.client!),
          ),
        MenuOption(
          icon: CupertinoIcons.doc_on_clipboard,
          title: localizations.copyClipboard,
          action: () => copyToClipboard(
            value: row.address,
            successMessage: localizations.copiedClipboard,
          ),
        ),
      ],
      child: Column(
        children: [
          tile,
          if (showSeparator) AppleSeparator(indent: tile.separatorIndent),
        ],
      ),
    );
  }
}

/// Filtering / safe browsing / parental / safe search state of a client.
class ClientStatusIcons extends StatelessWidget {
  final Client client;

  const ClientStatusIcons({
    super.key,
    required this.client,
  });

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final p = ApplePalette.of(context);

    Color colorFor(bool enabled) {
      if (appConfigProvider.useThemeColorForStatus == true) {
        return enabled ? p.tint : p.label3;
      }
      return enabled ? p.green : p.red;
    }

    Widget icon(IconData iconData, bool enabled) => Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Icon(
        iconData,
        size: 16,
        color: colorFor(enabled),
      ),
    );

    return Row(
      children: [
        icon(CupertinoIcons.line_horizontal_3_decrease, client.filteringEnabled),
        icon(CupertinoIcons.checkmark_shield, client.safebrowsingEnabled),
        icon(CupertinoIcons.lock, client.parentalEnabled),
        icon(
          CupertinoIcons.search,
          client.safeSearch != null && client.safeSearch!.enabled == true,
        ),
      ],
    );
  }
}
