import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:async/async.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/logs/log_tile.dart';
import 'package:adguard_home_manager/screens/logs/details/log_details_screen.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/services/api_client.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';

class LogsListClient extends StatefulWidget {
  final String ip;
  final String? name;
  final ServersProvider serversProvider;
  final AppConfigProvider appConfigProvider;
  final bool splitView;

  const LogsListClient({
    super.key,
    required this.ip,
    this.name,
    required this.serversProvider,
    required this.appConfigProvider,
    required this.splitView,
  });

  @override
  State<LogsListClient> createState() => _LogsListClientState();
}

class _LogsListClientState extends State<LogsListClient> {
  bool isLoadingMore = false;

  int logsQuantity = 100;
  int offset = 0;

  int loadStatus = 0;
  LogsData? logsData;

  CancelableOperation? cancelableRequest;

  Future fetchLogs({
    int? inOffset,
    bool? loadingMore,
  }) async {
    final serversProvider = Provider.of<ServersProvider>(context, listen: false);
    
    int offst = inOffset ?? offset;

    if (loadingMore != null && loadingMore == true) {
      setState(() => isLoadingMore = true);
    }

    if (cancelableRequest != null) cancelableRequest!.cancel(); 

    final operation = CancelableOperation.fromFuture(
      serversProvider.apiClient2!.getLogs(
        count: logsQuantity, 
        offset: offst,
        search: '"${widget.ip}"'
      )
    );
    cancelableRequest = operation;

    // The name is kept locally on purpose: a newer call overwrites the field
    // before this frame wakes up, and only this operation knows whether what
    // it waited on was called off or genuinely failed.
    final ApiResponse? result;
    try {
      result = await operation.value as ApiResponse?;
    } on Object {
      if (!operation.isCanceled) rethrow;
      // Backing out of the page calls the waiting request off. An answer that
      // was called off is not a fault the user can act on.
      return;
    }
    if (result == null || !mounted) return;

    if (loadingMore != null && loadingMore == true && mounted) {
      setState(() => isLoadingMore = false);
    }

    if (result.successful == true) {
      setState(() => offset = inOffset != null ? inOffset+logsQuantity : offset+logsQuantity);
      if (loadingMore != null && loadingMore == true && logsData != null) {
        LogsData newLogsData = result.content;
        newLogsData.data = [...logsData!.data, ...result.content.data];
        setState(() => logsData = newLogsData);
      }
      else {
        LogsData newLogsData = result.content;
        setState(() => logsData = newLogsData);
      }
      setState(() => loadStatus = 1);
    }
    else {
      setState(() => loadStatus = 2);
    }
  }


  /// Asks for the next page once the list runs close to its end, the way the
  /// other log lists of the design layer paginate.
  bool scrollListener(ScrollUpdateNotification scrollNotification) {
    if (scrollNotification.metrics.extentAfter < 500 && isLoadingMore == false) {
      fetchLogs(loadingMore: true);
    }

    return false;
  }

  @override
  void initState() {
    fetchLogs(inOffset: 0);
    super.initState();
  }

  @override
  void didUpdateWidget(LogsListClient oldWidget) {
    super.didUpdateWidget(oldWidget);

    // The wide layout keeps this widget alive while the user picks another
    // device, so the new address is the signal to start over. This used to be
    // noticed from inside build(), where a setState is not allowed.
    if (widget.ip != oldWidget.ip) {
      setState(() => loadStatus = 0);
      fetchLogs(inOffset: 0);
    }
  }

  @override
  void dispose() {
    // Every ordinary device tapped on the Devices page opens this screen, and
    // the request that is still on its way out would otherwise be left behind.
    cancelableRequest?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    final title = l.client;
    // The line under the title names the device the way the old bar did: the
    // configured name when there is one, the address otherwise.
    final subtitle = widget.name != null && widget.name != ''
      ? widget.name!
      : widget.ip;

    Widget fill(Widget child) => SliverFillRemaining(
      hasScrollBody: false,
      child: child,
    );

    Widget scroll = Builder(
      builder: (context) => CustomScrollView(
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          if (loadStatus == 0) fill(AppleLoading(label: l.loadingLogs)),
          if (loadStatus == 1 && logsData!.data.isNotEmpty)
            ...AppleListCard.slivers(
              context,
              itemsCount: isLoadingMore == true
                ? logsData!.data.length+1
                : logsData!.data.length,
              row: (index) {
                if (isLoadingMore == true && index == logsData!.data.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CupertinoActivityIndicator(radius: 12),
                    ),
                  );
                }
                return LogTile(
                  log: logsData!.data[index],
                  index: index,
                  length: logsData!.data.length,
                  useAlwaysNormalTile: true,
                  onLogTap: (log) => showLogDetails(context, log: log),
                  twoColumns: widget.splitView,
                );
              },
            ),
          if (loadStatus == 1 && logsData!.data.isEmpty)
            fill(
              AppleEmptyState(
                icon: CupertinoIcons.doc_text,
                title: l.noLogsDisplay,
                color: p.label3,
              ),
            ),
          if (loadStatus == 2)
            fill(
              AppleEmptyState(
                icon: CupertinoIcons.exclamationmark_triangle,
                title: l.logsNotLoaded,
                color: p.red,
              ),
            ),
        ],
      ),
    );

    scroll = RefreshIndicator(
      onRefresh: fetchLogs,
      displacement: 110,
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: scrollListener,
        child: scroll,
      ),
    );

    return Scaffold(
      backgroundColor: p.window,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: SliverAppBar.large(
              pinned: true,
              floating: true,
              centerTitle: true,
              titleSpacing: 20,
              forceElevated: innerBoxIsScrolled,
              title: Text(title),
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              foregroundColor: p.label,
              iconTheme: IconThemeData(color: p.label),
              actionsIconTheme: IconThemeData(color: p.tint),
              flexibleSpace: AppleLargeTitle(
                title: title,
                subtitle: subtitle,
              ),
              actions: [
                // The bar's own way to ask again lives on the pointers; a phone
                // pulls the list instead.
                if (!(Platform.isAndroid || Platform.isIOS)) ...[
                  AppleRefreshAction(
                    onRefresh: fetchLogs,
                    tooltip: l.refresh,
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          )
        ],
        body: SafeArea(
          top: false,
          bottom: false,
          child: scroll,
        ),
      ),
    );
  }
}