// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';
import 'package:adguard_home_manager/screens/logs/filters/clients_modal.dart';
import 'package:adguard_home_manager/screens/logs/filters/filter_status_modal.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Full list of query-log filters: client, quick status and response status.
class LogsFiltersModal extends StatelessWidget {
  final bool dialog;

  const LogsFiltersModal({super.key, required this.dialog});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AppleFormModal(
      title: l.filters,
      icon: CupertinoIcons.list_bullet,
      dialog: dialog,
      maxWidth: 420,
      body: const _FiltersList(),
    );
  }
}

class _FiltersList extends StatelessWidget {
  const _FiltersList();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final logsProvider = Provider.of<LogsProvider>(context);
    final clientsProvider = Provider.of<ClientsProvider>(context);

    final width = MediaQuery.of(context).size.width;

    final Map<String, String> translatedString = {
      "all": l.all,
      "filtered": l.filtered,
      "processed": l.processedRow,
      "whitelisted": l.processedWhitelistRow,
      "blocked": l.blocked,
      "blocked_safebrowsing": l.blockedSafeBrowsingRow,
      "blocked_parental": l.blockedParentalRow,
      "safe_search": l.blockedSafeSearchRow,
    };

    void openSelectFilterStatus() {
      if (width > 700 || !(Platform.isAndroid || Platform.isIOS)) {
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) => FilterStatusModal(
            value: logsProvider.selectedResultStatus,
            dialog: true,
          ),
        );
      } else {
        showModalBottomSheet(
            context: context,
            useRootNavigator: true,
            builder: (context) => FilterStatusModal(
                  value: logsProvider.selectedResultStatus,
                  dialog: false,
                ),
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            useSafeArea: true);
      }
    }

    void openSelectClients() {
      if (width > 700 || !(Platform.isAndroid || Platform.isIOS)) {
        showDialog(
            context: context,
            builder: (context) => ClientsModal(
                  value: logsProvider.selectedClients,
                  dialog: true,
                ),
            barrierDismissible: false);
      } else {
        showModalBottomSheet(
            context: context,
            useRootNavigator: true,
            builder: (context) => ClientsModal(
                  value: logsProvider.selectedClients,
                  dialog: false,
                ),
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent);
      }
    }

    final clientsLoaded = clientsProvider.loadStatus == LoadStatus.loaded;
    final status = logsProvider.selectedResultStatus;
    final quickFilter = status == "all"
        ? 0
        : (status == "processed" || status == "whitelisted" ? 1 : 2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppleListSection(
                  margin: const EdgeInsets.only(top: 4, bottom: 18),
                  children: [
                    AppleListTile(
                      title: l.client,
                      subtitle: logsProvider.selectedClients.isNotEmpty
                          ? "${logsProvider.selectedClients.length} ${l.clientsSelected}"
                          : l.all,
                      icon: CupertinoIcons.wifi,
                      enabled: clientsLoaded,
                      showChevron: clientsLoaded,
                      onTap: clientsLoaded ? openSelectClients : null,
                      trailing: clientsProvider.loadStatus == LoadStatus.loading
                          ? const CupertinoActivityIndicator(radius: 8)
                          : clientsProvider.loadStatus == LoadStatus.error
                              ? Icon(CupertinoIcons.exclamationmark_triangle,
                                  color: p.orange)
                              : null,
                    ),
                    AppleListTile(
                      title: l.responseStatus,
                      subtitle: "${translatedString[status]}",
                      icon: CupertinoIcons.shield,
                      onTap: openSelectFilterStatus,
                    ),
                  ],
                ),
                AppleListSection(
                  title: l.quickFilters,
                  margin: const EdgeInsets.only(bottom: 18),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: AppleSegmented(
                        labels: [l.all, l.allowed, l.blocked],
                        selectedIndex: quickFilter,
                        onChanged: (index) =>
                            logsProvider.setSelectedResultStatus(
                          value: const ["all", "processed", "blocked"][index],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        AppleFormFooter(
          confirmLabel: l.apply,
          cancelLabel: l.resetFilters,
          onCancel: () => logsProvider.requestResetFilters(),
          onConfirm: () {
            Navigator.pop(context);
            logsProvider.filterLogs();
          },
        ),
      ],
    );
  }
}
