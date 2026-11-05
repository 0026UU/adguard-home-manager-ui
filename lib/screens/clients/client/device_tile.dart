import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/models/dns_statistics.dart';

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

/// The queries a device brought to the server inside the statistics window.
///
/// `top_clients` names a device either by the label the administrator wrote or
/// by the address the query came from, so every identifier of the row is asked
/// for. A null answers that the window does not know this device at all, which
/// is not the same thing as no queries.
int? queriesForDevice(DnsStatistics? stats, DeviceRow row) {
  if (stats == null) return null;

  final names = <String>{
    row.name,
    row.address,
    row.logKey,
    if (row.client != null) row.client!.name,
    if (row.client != null) ...row.client!.ids,
  };

  for (final entry in stats.topClients) {
    for (final name in names) {
      if (entry.containsKey(name)) return entry[name];
    }
  }

  return null;
}

/// One row of the devices list, as the design layer draws it: an initial on a
/// seeded gradient, the address and its configuration state, then how many
/// queries the device brought to the server.
class DeviceTile extends StatelessWidget {
  final DeviceRow row;
  final void Function(DeviceRow) onTap;
  final bool selected;
  final bool splitView;

  /// Queries of the statistics window, or null while the server has none to
  /// report for this device.
  final int? queries;

  /// Trailing hairline; disabled for the last row of a list.
  final bool showSeparator;

  const DeviceTile({
    super.key,
    required this.row,
    required this.onTap,
    this.queries,
    this.selected = false,
    required this.splitView,
    this.showSeparator = true,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final palette = ApplePalette.of(context);

    final counted = queries != null;
    final count = counted ? compactFormat(queries!, Platform.localeName) : null;

    final state = row.configured
      ? localizations.hasCustomSettings
      : localizations.hasDefaultSettings;

    final subtitle = counted
      ? '${row.address} · $state · ${localizations.deviceQueries(count!)}'
      : '${row.address} · $state';

    final tile = AppleListTile(
      title: row.name,
      leading: AppleAvatar(
        text: row.name,
        size: 40,
        color: palette.seeded(row.name),
        gradientTo: palette.seededAlt(row.name),
      ),
      subtitle: subtitle,
      subtitleMaxLines: 1,
      value: count,
      onTap: () => onTap(row),
      showChevron: !splitView,
      selected: splitView && selected,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leadingWidth: 40,
    );

    return Column(
      children: [
        tile,
        if (showSeparator) AppleSeparator(indent: tile.separatorIndent),
      ],
    );
  }
}
