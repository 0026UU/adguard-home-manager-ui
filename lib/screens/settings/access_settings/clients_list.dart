// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/settings/access_settings/add_client_modal.dart';
import 'package:adguard_home_manager/screens/clients/client/remove_client_modal.dart';

import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/services/api_client.dart';

/// One of the three lists the server keeps under `/access`.
///
/// The rows are strings the server owns, so the group offers only the two
/// writes `/access/set` takes: add an entry, remove one. Both go through
/// [ClientsProvider], which redraws the card from `clientsAllowedBlocked` -
/// a write the server refused leaves the entry exactly where it was.
class ClientsList extends StatelessWidget {
  final AccessSettingsList type;
  final List<String> data;

  const ClientsList({
    super.key,
    required this.type,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final clientsProvider =
        Provider.of<ClientsProvider>(context, listen: false);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final width = MediaQuery.of(context).size.width;
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    final isClient = type != AccessSettingsList.domains;

    String title() {
      switch (type) {
        case AccessSettingsList.allowed:
          return l.allowedClients;
        case AccessSettingsList.disallowed:
          return l.disallowedClients;
        case AccessSettingsList.domains:
          return l.disallowedDomains;
      }
    }

    String description() {
      switch (type) {
        case AccessSettingsList.allowed:
          return l.allowedClientsDescription;
        case AccessSettingsList.disallowed:
          return l.blockedClientsDescription;
        case AccessSettingsList.domains:
          return l.disallowedDomainsDescription;
      }
    }

    String empty() {
      switch (type) {
        case AccessSettingsList.allowed:
          return l.noAllowedClients;
        case AccessSettingsList.disallowed:
          return l.noBlockedClients;
        case AccessSettingsList.domains:
          return l.noDisallowedDomains;
      }
    }

    // The answers one write can get, split by direction so a refused add never
    // reads as a refused removal, with the server's own "same identifier,
    // other list" refusal kept apart from a plain failure.
    void report(ApiResponse result, {required bool adding}) {
      final Color color;
      final String label;

      if (result.successful == true) {
        color = p.green;
        label = adding ? l.clientAddedSuccessfully : l.clientRemovedSuccessfully;
      } else if (result.successful == false &&
          result.content == 'client_another_list') {
        color = p.red;
        label = l.clientAnotherList;
      } else {
        color = p.red;
        label = adding
            ? (isClient ? l.clientNotAdded : l.domainNotAdded)
            : (isClient ? l.clientNotRemoved : l.domainNotAdded);
      }

      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: label,
        color: color,
      );
    }

    Future<void> add(String item) async {
      final processModal = ProcessModal();
      processModal.open(l.savingConfig);

      final result = await clientsProvider.addClientList(item, type);

      processModal.close();
      report(result, adding: true);
    }

    Future<void> remove(String item) async {
      final processModal = ProcessModal();
      processModal.open(l.savingConfig);

      final result = await clientsProvider.removeClientList(item, type);

      processModal.close();
      report(result, adding: false);
    }

    void openAddForm() {
      final asDialog = isDesktop(width) || !(Platform.isAndroid || Platform.isIOS);
      final form = AddClientModal(
        type: type,
        onConfirm: (item, _) => add(item),
        dialog: asDialog,
      );

      if (asDialog) {
        showDialog(context: context, builder: (context) => form);
      } else {
        showModalBottomSheet(
          context: context,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => form,
        );
      }
    }

    return AppleListSection(
      title: title(),
      footer: description(),
      headerTrailing: AppleHeaderAction(
        label: l.add,
        onPressed: openAddForm,
      ),
      children: [
        if (data.isEmpty)
          AppleListTile(
            title: empty(),
            showChevron: false,
            enabled: false,
          )
        else
          for (final entry in data)
            AppleListTile(
              title: entry,
              mono: true,
              showChevron: false,
              trailing: IconButton(
                tooltip: l.removeClient,
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => RemoveClientModal(
                    onConfirm: () => remove(entry),
                  ),
                ),
                icon: Icon(CupertinoIcons.trash, color: p.red),
              ),
            ),
      ],
    );
  }
}
