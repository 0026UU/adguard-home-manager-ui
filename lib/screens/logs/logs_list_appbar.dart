// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/logs/live/live_logs_screen.dart';
import 'package:adguard_home_manager/screens/logs/filters/logs_filters_modal.dart';
import 'package:adguard_home_manager/widgets/floating_search_bar.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/live_logs_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/models/applied_filters.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';

final GlobalKey _searchButtonKey = GlobalKey();

class LogsListAppBar extends StatelessWidget {
  final bool innerBoxIsScrolled;

  /// Status line under the title, e.g. how long the server keeps its logs.
  final String? subtitle;

  const LogsListAppBar({
    super.key,
    required this.innerBoxIsScrolled,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final logsProvider = Provider.of<LogsProvider>(context);

    final width = MediaQuery.of(context).size.width;
    final localizations = AppLocalizations.of(context)!;
    final palette = ApplePalette.of(context);

    void openFilersModal() {
      if (width > 700 || !(Platform.isAndroid || Platform.isIOS)) {
        showDialog(
          context: context, 
          builder: (context) => const LogsFiltersModal(
            dialog: true,
          ),
          barrierDismissible: false
        );
      }
      else {
        showModalBottomSheet(
          context: context, 
          useRootNavigator: true,
          builder: (context) => const LogsFiltersModal(
            dialog: false,
          ),
          backgroundColor: Colors.transparent,
          isScrollControlled: true
        );
      }
    }

    void showSearchDialog() {
      showDialog(
        context: context, 
        builder: (context) => FloatingSearchBar(
          existingSearchValue: logsProvider.appliedFilters.searchText ?? "",
          searchButtonRenderBox: _searchButtonKey.currentContext?.findRenderObject() as RenderBox?,
          onSearchCompleted: (v) {
            logsProvider.setAppliedFilters(
              AppliedFiters(
                selectedResultStatus: logsProvider.appliedFilters.selectedResultStatus, 
                searchText: v != "" ? v : null, 
                clients: logsProvider.appliedFilters.clients
              )
            );
            logsProvider.filterLogs();
          },
          onSearchFieldUpdated: (v) {
            if (v == "") {
              logsProvider.setSearchText(null);
              return;
            }
            logsProvider.setSearchText(v);
          },
        ),
      );
    }

    void openLiveLogsScreen() {
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MultiProvider(
            providers: [
              ChangeNotifierProxyProvider<ServersProvider, LiveLogsProvider>(
                create: (context) => LiveLogsProvider(), 
                update: (context, servers, logs) => logs!..update(servers),
              ),
            ],
            child: const LiveLogsScreen()
          )
        )
      );
    }

    final Map<String, String> translatedString = {
      "all": localizations.all, 
      "filtered": localizations.filtered, 
      "processed": localizations.processedRow, 
      "whitelisted": localizations.processedWhitelistRow, 
      "blocked": localizations.blocked, 
      "blocked_safebrowsing": localizations.blockedSafeBrowsingRow, 
      "blocked_parental": localizations.blockedParentalRow, 
      "safe_search": localizations.safeSearch, 
    };

    final applied = logsProvider.appliedFilters;
    final hasFilters = applied.searchText != null
      || applied.selectedResultStatus != 'all'
      || applied.clients.isNotEmpty;

    return SliverAppBar.large(
      pinned: true,
      floating: true,
      centerTitle: true,
      titleSpacing: 20,
      forceElevated: innerBoxIsScrolled,
      title: Text(localizations.logs),
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      foregroundColor: palette.label,
      iconTheme: IconThemeData(color: palette.label),
      actionsIconTheme: IconThemeData(color: palette.tint),
      flexibleSpace: AppleLargeTitle(
        title: localizations.logs,
        subtitle: subtitle,
        subtitleDot: subtitle == null ? null : palette.tint,
        bottomHeight: hasFilters ? 46 : 0,
      ),
      actions: [
        if (!(Platform.isAndroid || Platform.isIOS)) IconButton(
          onPressed: () => logsProvider.fetchLogs(inOffset: 0), 
          icon: const Icon(CupertinoIcons.arrow_clockwise),
          tooltip: localizations.refresh,
        ),
        if (logsProvider.loadStatus == LoadStatus.loaded) IconButton(
          key: _searchButtonKey,
          onPressed: showSearchDialog,
          icon: const Icon(CupertinoIcons.search),
          tooltip: localizations.search,
        ),
        if (logsProvider.loadStatus == LoadStatus.loaded) PopupMenuButton(
          tooltip: localizations.filters,
          itemBuilder: (context) => [
            PopupMenuItem(
              onTap: openFilersModal,
              child: Row(
                children: [
                  const Icon(CupertinoIcons.slider_horizontal_3),
                  const SizedBox(width: 10),
                  Text(localizations.filters)
                ],
              )
            ),
            PopupMenuItem(
              onTap: openLiveLogsScreen,
              child: Row(
                children: [
                  const Icon(CupertinoIcons.bolt),
                  const SizedBox(width: 10),
                  Text(localizations.liveLogs)
                ],
              )
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
      bottom: hasFilters
        ? AppleHeaderBar(
            height: 46,
            padding: const EdgeInsets.fromLTRB(16, 2, 12, 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (applied.searchText != null)
                  AppleFilterChip(
                    icon: CupertinoIcons.search,
                    label: applied.searchText!,
                    onDeleted: () {
                      logsProvider.setAppliedFilters(
                        AppliedFiters(
                          selectedResultStatus: applied.selectedResultStatus, 
                          searchText: null,
                          clients: applied.clients
                        )
                      );
                      logsProvider.setSearchText(null);
                      logsProvider.fetchLogs(
                        inOffset: 0,
                        searchText: ''
                      );
                    },
                  ),
                if (applied.selectedResultStatus != 'all')
                  AppleFilterChip(
                    icon: CupertinoIcons.checkmark_shield,
                    color: palette.tint,
                    label: translatedString[applied.selectedResultStatus]!,
                    onDeleted: () {
                      logsProvider.setAppliedFilters(
                        AppliedFiters(
                          selectedResultStatus: 'all', 
                          searchText: applied.searchText,
                          clients: applied.clients
                        )
                      );
                      logsProvider.setSelectedResultStatus(value: 'all');
                      logsProvider.fetchLogs(
                        inOffset: 0,
                        responseStatus: 'all'
                      );
                    },
                  ),
                if (applied.clients.isNotEmpty)
                  AppleFilterChip(
                    icon: CupertinoIcons.person_2,
                    label: applied.clients.length == 1
                      ? applied.clients[0]
                      : "${applied.clients.length} ${localizations.clients}",
                    onDeleted: () {
                      logsProvider.setAppliedFilters(
                        AppliedFiters(
                          selectedResultStatus: applied.selectedResultStatus, 
                          searchText: applied.searchText,
                          clients: []
                        )
                      );
                      logsProvider.setSelectedClients(null);
                      logsProvider.fetchLogs(
                        inOffset: 0,
                        responseStatus: applied.selectedResultStatus
                      );
                    },
                  ),
              ],
            ),
          )
        : null,
    );
  }
}
