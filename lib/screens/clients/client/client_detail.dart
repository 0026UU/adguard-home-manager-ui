// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/clients/client/client_screen_functions.dart';

import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/functions/copy_clipboard.dart';
import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/models/dns_statistics.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';

/// One device of the clients list, drawn as the pushed page of the design
/// layer: its name, the queries the server counted for it, the four switches
/// written on its entry and the identifiers it is known by.
///
/// The design layer also counts the queries a device had blocked and keeps an
/// allow and a block list per client. AdGuard Home answers neither for a single
/// client — the block totals only exist for the whole server and the access
/// lists belong to the server, not to a device — so those parts are left out
/// here instead of being filled with numbers that were never read.
class ClientDetailScreen extends StatelessWidget {
  final Client client;

  const ClientDetailScreen({super.key, required this.client});

  /// A value the server does not have. The design layer marks it with an em
  /// dash, which is punctuation rather than a word to translate.
  static const String _noValue = '—';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final clientsProvider = Provider.of<ClientsProvider>(context);
    final statusProvider = Provider.of<StatusProvider>(context);
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);

    // The provider holds the entry as the server just wrote it back, so a
    // switch saved from this page reads the state the server kept.
    final current = _stored(clientsProvider);
    final queries = _queries(statusProvider.serverStatus?.stats, current);

    void save(Client updated) async {
      final processModal = ProcessModal();
      processModal.open(l.savingChanges);

      final result = await clientsProvider.editClient(updated);

      processModal.close();

      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: result
          ? l.clientUpdatedSuccessfully
          : l.clientNotUpdated,
        color: result ? p.green : p.red,
      );
    }

    void remove() {
      openDeleteClientScreen(
        context: context,
        onDelete: () async {
          final processModal = ProcessModal();
          processModal.open(l.removingClient);

          final result = await clientsProvider.deleteClient(current);

          processModal.close();

          showSnackbar(
            appConfigProvider: appConfigProvider,
            label: result
              ? l.clientDeletedSuccessfully
              : l.clientNotDeleted,
            color: result ? p.green : p.red,
          );

          // The entry is gone, so there is nothing left to show here.
          if (result == true) Navigator.pop(context);
        },
      );
    }

    return AppleScreen(
      title: current.name,
      subtitle: current.ids.isEmpty ? null : current.ids.join(' · '),
      // A pushed route has a route to go back from, and the page behind it is
      // the device list. On the wide layout the same page is only a pane, so
      // it asks for no capsule.
      leading: Navigator.canPop(context)
        ? AppleBackButton(
            label: l.devices,
            onPressed: () => Navigator.pop(context),
          )
        : null,
      actions: [
        AppleHeaderAction(
          label: l.edit,
          onPressed: () => openClientFormModal(
            context: context,
            width: MediaQuery.sizeOf(context).width,
            client: current,
            onConfirm: save,
            onDelete: (_) => remove(),
          ),
        ),
      ],
      slivers: [
        // The card of the design layer: the initial of the device and what the
        // server counted for it. The blocked half of the card and its ring are
        // missing on purpose, there is no number to put in them.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: AppleCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  AppleAvatar(
                    text: current.name,
                    size: 52,
                    color: p.seeded(current.name),
                    gradientTo: p.seededAlt(current.name),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: AppleStatCard(
                      label: l.queries,
                      value: queries == null
                        ? _noValue
                        : intFormat(queries, Platform.localeName),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: AppleListSection(
            title: l.clientSettings,
            margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
            children: [
              AppleSwitchListTile(
                icon: CupertinoIcons.checkmark_alt,
                iconColor: p.tint,
                title: l.useGlobalSettings,
                subtitle: l.useGlobalSettingsHelper,
                value: current.useGlobalSettings,
                onChanged: (value) => save(
                  _written(current, useGlobalSettings: value),
                ),
              ),
              AppleSwitchListTile(
                icon: CupertinoIcons.nosign,
                iconColor: p.red,
                title: l.dnsFiltering,
                subtitle: l.dnsFilteringHelper,
                value: current.filteringEnabled,
                onChanged: (value) => save(
                  _written(current, filteringEnabled: value),
                ),
              ),
              AppleSwitchListTile(
                icon: CupertinoIcons.lock,
                iconColor: p.green,
                title: l.safeBrowsing,
                value: current.safebrowsingEnabled,
                onChanged: (value) => save(
                  _written(current, safebrowsingEnabled: value),
                ),
              ),
              AppleSwitchListTile(
                icon: CupertinoIcons.person_crop_square,
                iconColor: p.orange,
                title: l.parentalControl,
                value: current.parentalEnabled,
                onChanged: (value) => save(
                  _written(current, parentalEnabled: value),
                ),
              ),
            ],
          ),
        ),

        SliverToBoxAdapter(
          child: AppleListSection(
            title: l.identity,
            margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
            children: [
              if (current.ids.isEmpty)
                AppleListTile(title: l.noIdentifiers, showChevron: false)
              else
                for (final id in current.ids)
                  AppleListTile(
                    // A MAC address is the only identifier of a client that
                    // carries a colon; a CIDR, an address and a client ID are
                    // all read as addresses.
                    title: id.contains(':') ? l.macAddress : l.ipAddress,
                    value: id,
                    showChevron: false,
                    onTap: () => copyToClipboard(
                      value: id,
                      successMessage: l.copiedClipboard,
                    ),
                  ),
              AppleListTile(
                title: l.services,
                value: current.useGlobalBlockedServices
                  ? l.servicesSameAsServer
                  : current.blockedServices.isEmpty
                    ? l.noBlockedServicesSelected
                    : l.blockedServicesCount(current.blockedServices.length),
                showChevron: false,
              ),
            ],
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
            child: AppleButton(
              label: l.deleteThisDevice,
              color: p.red,
              onPressed: remove,
            ),
          ),
        ),
      ],
    );
  }

  /// The client as the clients provider holds it now, which is the edited copy
  /// once a write has come back.
  Client _stored(ClientsProvider provider) {
    for (final entry in provider.clients?.clients ?? const <Client>[]) {
      if (entry.name == client.name) return entry;
    }

    return client;
  }
}

/// The queries this device brought to the server in the statistics window.
///
/// `top_clients` names a device either by the label the administrator wrote or
/// by the address the query came from, so every identifier is asked for. A null
/// answers that the device is not in the window at all, which is not the same
/// thing as no queries.
int? _queries(DnsStatistics? stats, Client client) {
  if (stats == null) return null;

  for (final entry in stats.topClients) {
    for (final name in [client.name, ...client.ids]) {
      if (entry.containsKey(name)) return entry[name];
    }
  }

  return null;
}

/// [client] with its switches moved, ready for the whole-entry update the
/// server expects. Everything the page does not show is sent back as it was.
Client _written(
  Client client, {
  bool? useGlobalSettings,
  bool? filteringEnabled,
  bool? safebrowsingEnabled,
  bool? parentalEnabled,
}) =>
    Client(
      name: client.name,
      blockedServices: client.blockedServices,
      ids: client.ids,
      tags: client.tags,
      upstreams: client.upstreams,
      filteringEnabled: filteringEnabled ?? client.filteringEnabled,
      parentalEnabled: parentalEnabled ?? client.parentalEnabled,
      safebrowsingEnabled: safebrowsingEnabled ?? client.safebrowsingEnabled,
      useGlobalBlockedServices: client.useGlobalBlockedServices,
      useGlobalSettings: useGlobalSettings ?? client.useGlobalSettings,
      safeSearch: client.safeSearch,
      ignoreQuerylog: client.ignoreQuerylog,
      ignoreStatistics: client.ignoreStatistics,
      upstreamsCacheEnabled: client.upstreamsCacheEnabled,
      upstreamsCacheSize: client.upstreamsCacheSize,
      blockedServicesSchedule: client.blockedServicesSchedule,
    );
