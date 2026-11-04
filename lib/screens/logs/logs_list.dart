// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/logs/details/log_details_screen.dart';
import 'package:adguard_home_manager/screens/logs/log_tile.dart';
import 'package:adguard_home_manager/screens/logs/logs_list_appbar.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
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

  const LogsListWidget({
    super.key,
    required this.twoColumns,
    required this.selectedLog,
    required this.onLogSelected,
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

  Future<void> fetchRetention() async {
    final serversProvider = Provider.of<ServersProvider>(context, listen: false);

    if (serversProvider.apiClient2 == null) return;

    final result = await serversProvider.apiClient2!.getQueryLogInfo();
    if (!mounted || result.successful != true) return;

    final interval = (result.content as QueryLogConfig).interval ?? 0;
    if (interval <= 0) return;

    final localizations = AppLocalizations.of(context)!;
    final hours = interval ~/ Duration.millisecondsPerHour;
    setState(() {
      retention = localizations.retainedFor(
        hours > 0 ? localizations.hours(hours) : localizations.minutes(1),
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
        color: Colors.red
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
        label: AppLocalizations.of(context)!.couldntGetFilteringStatus, 
        color: Colors.red
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

  @override
  void initState() {
    final logsProvider = Provider.of<LogsProvider>(context, listen: false);

    _liveLogsProvider = Provider.of<LiveLogsProvider>(context, listen: false);

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
    final query = logsProvider.searchText;
    final shown = _live
      ? liveLogsProvider.logs.where((log) => _matches(log, query)).toList()
      : logs;

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
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => LogDetailsScreen(
                log: value,
                dialog: false,
                twoColumns: widget.twoColumns,
              )
            )
          );
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

    List<Widget> rows(BuildContext context) {
      if (_live) {
        if (shown.isEmpty) {
          return [
            fill(
              AppleEmptyState(
                icon: CupertinoIcons.bolt,
                title: localizations.hereWillAppearRealtimeLogs,
                color: palette.label3,
              ),
            )
          ];
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
              message: logsProvider.logsOlderThan != null
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

    Widget scroll = Builder(
      builder: (context) => CustomScrollView(
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          controls(),
          ...rows(context),
        ],
      ),
    );

    // Only the stored log is paginated, and the stream needs a pull only when
    // it is not refreshing on its own.
    if (!_live ||
        !Provider.of<AppConfigProvider>(context, listen: false)
            .autoRefreshLiveLogs) {
      scroll = RefreshIndicator(
        onRefresh: () async {
          if (_live) {
            await _liveLogsProvider.fetchOnce();
          } else {
            await logsProvider.fetchLogs(inOffset: 0);
          }
        },
        displacement: 110,
        child: NotificationListener(
          onNotification: scrollListener,
          child: scroll,
        ),
      );
    }

    return ScaffoldMessenger(
      key: widget.twoColumns ? _scaffoldMessengerKey : null,
      child: Scaffold(
        backgroundColor: palette.window,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: LogsListAppBar(
                innerBoxIsScrolled: innerBoxIsScrolled, 
                subtitle: _live ? localizations.trackingQueries : retention,
                subtitleDot: _live ? palette.green : palette.tint,
              )
            )
          ],
          body: SafeArea(
            top: false,
            bottom: false,
            child: scroll,
          ),
        ),
      ),
    );
  }
}
