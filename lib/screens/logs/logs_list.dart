// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/logs/details/log_details_screen.dart';
import 'package:adguard_home_manager/screens/logs/filters/logs_filters_modal.dart';
import 'package:adguard_home_manager/screens/logs/log_tile.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/functions/retention_label.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/models/applied_filters.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/models/querylog_config.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/live_logs_provider.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';

class LogsListWidget extends StatefulWidget {
  final Log? selectedLog;
  final bool twoColumns;
  final void Function(Log) onLogSelected;

  /// Client ids to narrow the query log to before the first fetch, when the
  /// screen was pushed with a device already picked (the count on a device
  /// row). They go through the same applied filters the sheet edits, so the
  /// sheet opens showing them and can clear them.
  final List<String>? initialClients;

  const LogsListWidget({
    super.key,
    required this.twoColumns,
    required this.selectedLog,
    required this.onLogSelected,
    this.initialClients,
  });

  @override
  State<LogsListWidget> createState() => _LogsListWidgetState();
}

class _LogsListWidgetState extends State<LogsListWidget> {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Which half of the page is showing: the query log the server keeps (0) or
  /// the stream of queries as they arrive (1).
  int _view = 0;

  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  /// Kept so the stream can be stopped when this screen goes away.
  late final LiveLogsProvider _liveLogsProvider;

  /// How long the server keeps the queries below, shown under the title.
  String? retention;

  bool get _live {
    return _view == 1;
  }

  /// Asks the server for what this half of the page shows, which is what the
  /// bar button and the pull gesture both mean to do.
  Future<void> refreshLogs() async {
    if (_live) {
      await _liveLogsProvider.fetchOnce();
      return;
    }

    await Provider.of<LogsProvider>(context, listen: false)
        .fetchLogs(inOffset: 0);
  }

  Future<void> fetchRetention() async {
    final serversProvider = Provider.of<ServersProvider>(context, listen: false);

    if (serversProvider.apiClient2 == null) return;

    final result = await serversProvider.apiClient2!.getQueryLogInfo();
    if (!mounted || result.successful != true) return;

    final interval = (result.content as QueryLogConfig).interval ?? 0;
    if (interval <= 0) return;

    final localizations = AppLocalizations.of(context)!;
    setState(() {
      retention = localizations.retainedFor(
        retentionLabel(localizations, interval),
      );
    });
  }

  void fetchFilteringRules() async {
    final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);

    final result = await statusProvider.getFilteringRules();
    if (mounted && result == false) {
      showSnackbar(
        appConfigProvider: appConfigProvider, 
        label: AppLocalizations.of(context)!.couldntGetFilteringStatus, 
        color: ApplePalette.of(context).red
      );
    }
  }

  Future fetchClients() async {
    final clientsProvider = Provider.of<ClientsProvider>(context, listen: false);
    final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);

    final result = await clientsProvider.fetchClients();
    if (mounted && result == false) {
      showSnackbar(
        appConfigProvider: appConfigProvider, 
        label: AppLocalizations.of(context)!.clientsNotLoaded, 
        color: ApplePalette.of(context).red
      );
    }
  }

  bool scrollListener(ScrollUpdateNotification scrollNotification) {
    // Only the stored log is paginated; the stream keeps up on its own.
    if (_live) return false;

    final logsProvider = Provider.of<LogsProvider>(context, listen: false);

    if (scrollNotification.metrics.extentAfter < 500 && logsProvider.isLoadingMore == false) {
      logsProvider.fetchLogs(loadingMore: true);
    }
    
    return false;
  }

  void _setView(int index) {
    if (_view == index) return;
    setState(() => _view = index);

    if (!_live) {
      _liveLogsProvider.stopFetchLogs();
      return;
    }

    // The stream either keeps asking on its own, which is what the settings
    // page calls auto refresh, or it shows the queries up to now and waits
    // for a pull.
    _liveLogsProvider.clearLogs();

    if (Provider.of<AppConfigProvider>(context, listen: false)
        .autoRefreshLiveLogs) {
      _liveLogsProvider.startFetchLogs();
    } else {
      _liveLogsProvider.fetchOnce();
    }
  }

  /// The stream is filtered on the spot; the query log asks the server, but
  /// only once the typing stops.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;

      final logsProvider = Provider.of<LogsProvider>(context, listen: false);
      logsProvider.setSearchText(value.isEmpty ? null : value);
      if (!_live) logsProvider.filterLogs();
    });
  }

  bool _matches(Log log, String? query) {
    if (query == null || query.isEmpty) return true;

    final needle = query.toLowerCase();
    return (log.question.name ?? "").toLowerCase().contains(needle)
      || log.client.toLowerCase().contains(needle)
      || (log.clientInfo?.name ?? "").toLowerCase().contains(needle);
  }

  /// The chips and the field above the live rows are a promise the rows have
  /// to keep, so the stream is narrowed with the same rules the query log is:
  /// the reason the server gave, the device the query came from — by address
  /// or by the name it is known under — and the window.
  bool _streamMatches(Log log, AppliedFiters applied, String? query, DateTime? since) {
    if (applied.reasons.isNotEmpty && !applied.reasons.contains(log.reason)) {
      return false;
    }

    if (since != null && !log.time.isAfter(since)) return false;

    if (applied.clients.isNotEmpty
      && !applied.clients.contains(log.client)
      && !applied.clients.contains(log.clientInfo?.name)) {
      return false;
    }

    return _matches(log, query);
  }

  /// The stream narrows its own rows, so getting them back means clearing the
  /// field along with the chips.
  void _clearStreamFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();

    final logsProvider = Provider.of<LogsProvider>(context, listen: false);
    logsProvider.setSearchText(null);
    logsProvider.requestResetFilters();
  }

  @override
  void initState() {
    final logsProvider = Provider.of<LogsProvider>(context, listen: false);

    _liveLogsProvider = Provider.of<LiveLogsProvider>(context, listen: false);

    // The tab is rebuilt whenever it comes back but the provider keeps the
    // term, so the box has to start from it: otherwise the list stays
    // narrowed by a filter the user can neither see nor clear.
    final term = logsProvider.searchText;
    if (term != null && term.isNotEmpty) _searchController.text = term;

    // Pushed from a device row with a client already picked: prime the applied
    // filters before the first fetch, so the list narrows at once, the chip
    // under the title shows it, and the sheet opens with it selected. Priming
    // does not notify — this widget is mid-build — and the fetch below reads
    // what was primed.
    final initialClients = widget.initialClients;
    if (initialClients != null && initialClients.isNotEmpty) {
      logsProvider.primeClientFilter(initialClients);
    }
    logsProvider.fetchLogs(inOffset: 0);
    fetchFilteringRules();
    fetchClients();
    fetchRetention();
    super.initState();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _liveLogsProvider.stopFetchLogs();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsProvider = Provider.of<LogsProvider>(context);
    final liveLogsProvider = Provider.of<LiveLogsProvider>(context);
    final localizations = AppLocalizations.of(context)!;
    final palette = ApplePalette.of(context);

    final logs = logsProvider.logsData?.data ?? [];
    final applied = logsProvider.appliedFilters;
    final query = logsProvider.searchText;

    // The window is counted from the newest query the stream has read instead
    // of from the phone's clock, for the same reason the stream's anchor is:
    // the two clocks do not agree.
    final newest = liveLogsProvider.newestTime;
    final since = newest == null ? null : applied.since(newest);

    final shown = _live
      ? liveLogsProvider.logs
          .where((log) => _streamMatches(log, applied, query, since))
          .toList()
      : logs;

    // Something on screen is throwing rows away, which the empty state has to
    // admit instead of pretending nothing asked the server.
    final narrowed = applied.statuses.isNotEmpty
      || applied.clients.isNotEmpty
      || (query != null && query.isNotEmpty);

    Widget fill(Widget child) => SliverFillRemaining(
      hasScrollBody: false,
      child: child,
    );

    Widget header() => SliverToBoxAdapter(
      child: AppleGroupHeader(
        title: _live ? localizations.liveLogs : localizations.queryLog,
        trailing: localizations.loadedRecords(intFormat(shown.length, Platform.localeName)),
      ),
    );

    Widget row(Log log, int index, int length) => LogTile(
      log: log,
      index: index,
      length: length,
      isLogSelected: widget.selectedLog != null && widget.selectedLog == log,
      onLogTap: (value) {
        if (!widget.twoColumns) {
          showLogDetails(context, log: value);
        }
        widget.onLogSelected(value);
      },
      twoColumns: widget.twoColumns,
    );

    // One scroll view for the whole page: the segment and the field keep their
    // place while only the rows below change as the data arrives.
    Widget controls() => SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: AppleSegmented(
              labels: [localizations.historyLogs, localizations.liveLogs],
              selectedIndex: _view,
              large: true,
              onChanged: _setView,
            ),
          ),
          AppleSearchField(
            controller: _searchController,
            hint: localizations.searchDomainOrClient,
            onChanged: _onSearchChanged,
          ),
        ],
      ),
    );

    // The stream is quiet for two different reasons and the copy has to say
    // which: nothing has asked the server since the view opened, or the rows
    // it saw were thrown away by what is on screen.
    Widget liveEmpty() {
      if (narrowed) {
        return AppleEmptyState(
          icon: CupertinoIcons.line_horizontal_3_decrease,
          title: localizations.noLogsDisplay,
          message: localizations.noLiveLogsMatchingFilters,
          action: SizedBox(
            width: 180,
            child: AppleButton.secondary(
              label: localizations.resetFilters,
              onPressed: _clearStreamFilters,
            ),
          ),
          color: palette.label3,
        );
      }

      final statusProvider = Provider.of<StatusProvider>(context);
      // An answer the server never gave is not an answer of "paused": reading
      // a missing status as switched-off sends the user off to turn on a
      // protection the app has no evidence was ever turned off.
      final statusKnown = statusProvider.serverStatus != null &&
          statusProvider.loadStatus != LoadStatus.error;

      return AppleEmptyState(
        icon: CupertinoIcons.bolt,
        title: localizations.hereWillAppearRealtimeLogs,
        message: !statusKnown
          ? localizations.protectionUnknown
          : statusProvider.serverStatus!.generalEnabled
            ? localizations.protectionRunning
            : localizations.protectionPaused,
        color: palette.label3,
      );
    }

    List<Widget> rows(BuildContext context) {
      if (_live) {
        if (shown.isEmpty) {
          return [fill(liveEmpty())];
        }

        return [
          header(),
          ...AppleListCard.slivers(
            context,
            itemsCount: shown.length,
            row: (index) => row(shown[index], index, shown.length),
          ),
        ];
      }

      if (logsProvider.loadStatus == LoadStatus.loading) {
        return [fill(AppleLoading(label: localizations.loadingLogs))];
      }

      if (logsProvider.loadStatus == LoadStatus.error) {
        return [
          fill(
            AppleEmptyState(
              icon: CupertinoIcons.exclamationmark_triangle,
              title: localizations.logsNotLoaded,
              // A page that shows nothing else hides the pull gesture, so the
              // failure has to offer the way out on its own.
              action: AppleFormButton(
                label: localizations.refresh,
                background: palette.tint,
                foreground: onTint(palette.tint),
                onPressed: refreshLogs,
              ),
              color: palette.orange,
            ),
          )
        ];
      }

      if (logs.isEmpty) {
        return [
          fill(
            AppleEmptyState(
              icon: CupertinoIcons.doc_text,
              title: localizations.noLogsDisplay,
              // Same rule as the stream: say which of the two reasons left the
              // list empty, rather than making the user guess.
              message: narrowed
                ? localizations.noLogsMatchingFilters
                : logsProvider.logsOlderThan != null
                  ? localizations.noLogsThatOld
                  : null,
              color: palette.label3,
            ),
          )
        ];
      }

      return [
        header(),
        ...AppleListCard.slivers(
          context,
          itemsCount: logsProvider.isLoadingMore
            ? logs.length + 1
            : logs.length,
          row: (index) {
            if (logsProvider.isLoadingMore == true && index == logs.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CupertinoActivityIndicator(radius: 12),
                ),
              );
            }
            else if (logs[index].question.name != null) {
              return row(logs[index], index, logs.length);
            }
            else {
              return null;
            }
          },
        ),
      ];
    }

    final width = MediaQuery.of(context).size.width;

    // The filter sheet is how a failed load is fixed, so the way in stays open
    // even when the query log could not be read.
    void openFilersModal() {
      if (width > 700 || !(Platform.isAndroid || Platform.isIOS)) {
        showDialog(
          context: context,
          builder: (context) => const LogsFiltersModal(
            dialog: true,
          ),
          barrierDismissible: false,
        );
      } else {
        showModalBottomSheet(
          context: context,
          useRootNavigator: true,
          builder: (context) => const LogsFiltersModal(
            dialog: false,
          ),
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
        );
      }
    }

    // The search lives in the field under the title now, so only the filters
    // that have no home of their own get a chip.
    final hasFilters = applied.statuses.isNotEmpty || applied.clients.isNotEmpty;

    // Only the stored log is paginated, and the stream needs a pull only when
    // it is not refreshing on its own.
    final pullEnabled = !_live ||
        !Provider.of<AppConfigProvider>(context, listen: false)
            .autoRefreshLiveLogs;

    // One scroll view for the whole page: the collapsing large title comes from
    // [AppleScreen], and the segment, field and rows below keep their place
    // while only the rows change as the data arrives.
    return ScaffoldMessenger(
      key: widget.twoColumns ? _scaffoldMessengerKey : null,
      child: AppleScreen(
        // Pushed from a device row or the overview the page leaves the tab bar
        // behind, so the capsule is the only way home; as a tab it can't pop.
        leading: Navigator.canPop(context)
            ? AppleBackButton(
                label: localizations.back,
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: localizations.logs,
        subtitle: _live ? localizations.trackingQueries : retention,
        subtitleDot: _live ? palette.green : palette.tint,
        // The bar button always asks the server again, whatever half of the
        // page is showing; the pull gesture is added below only when the rows
        // are not already refreshing on their own.
        onRefresh: refreshLogs,
        actions: [
          IconButton(
            onPressed: openFilersModal,
            icon: const Icon(CupertinoIcons.slider_horizontal_3),
            tooltip: localizations.filters,
          ),
        ],
        header: hasFilters
          ? ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final status in applied.statuses)
                  AppleFilterChip(
                    color: logStatusColor(palette, status),
                    label: localizations.onlyStatus(
                      logStatusLabel(localizations, status),
                    ),
                    onDeleted: () => logsProvider.removeAppliedStatus(status),
                  ),
                if (applied.clients.isNotEmpty)
                  AppleFilterChip(
                    icon: CupertinoIcons.person_2,
                    label: applied.clients.length == 1
                      ? applied.clients[0]
                      : "${applied.clients.length} ${localizations.clients}",
                    onDeleted: () => logsProvider.removeAppliedClients(),
                  ),
              ],
            )
          : null,
        body: SafeArea(
          top: false,
          bottom: false,
          child: NotificationListener(
            onNotification: scrollListener,
            child: Builder(
              builder: (context) => CustomScrollView(
                slivers: [
                  SliverOverlapInjector(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  ),
                  if (pullEnabled)
                    CupertinoSliverRefreshControl(onRefresh: refreshLogs),
                  controls(),
                  ...rows(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
