// ignore_for_file: use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/logs/details/log_details_screen.dart';
import 'package:adguard_home_manager/screens/logs/log_tile.dart';
import 'package:adguard_home_manager/screens/logs/logs_list_appbar.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';
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
    final logsProvider = Provider.of<LogsProvider>(context, listen: false);

    if (scrollNotification.metrics.extentAfter < 500 && logsProvider.isLoadingMore == false) {
      logsProvider.fetchLogs(loadingMore: true);
    }
    
    return false;
  }

  @override
  void initState() {
    final logsProvider = Provider.of<LogsProvider>(context, listen: false);

    logsProvider.fetchLogs(inOffset: 0);
    fetchFilteringRules();
    fetchClients();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final logsProvider = Provider.of<LogsProvider>(context);
    final localizations = AppLocalizations.of(context)!;
    final palette = ApplePalette.of(context);

    final logs = logsProvider.logsData?.data ?? [];

    Widget fill(Widget child) => SliverFillRemaining(
      hasScrollBody: false,
      child: child,
    );

    return ScaffoldMessenger(
      key: widget.twoColumns ? _scaffoldMessengerKey : null,
      child: Scaffold(
        backgroundColor: palette.card,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: LogsListAppBar(
                innerBoxIsScrolled: innerBoxIsScrolled, 
              )
            )
          ],
          body: Builder(
            builder: (context) {
              if (logsProvider.loadStatus == LoadStatus.loading) {
                return SafeArea(
                  top: false,
                  bottom: false,
                  child: Builder(
                    builder: (context) => CustomScrollView(
                      slivers: [
                        SliverOverlapInjector(
                          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                        ),
                        fill(AppleLoading(label: localizations.loadingLogs))
                      ],
                    ),
                  ),
                );
              }

              if (logsProvider.loadStatus == LoadStatus.error) {
                return SafeArea(
                  top: false,
                  bottom: false,
                  child: Builder(
                    builder: (context) => CustomScrollView(
                      slivers: [
                        SliverOverlapInjector(
                          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                        ),
                        fill(
                          AppleEmptyState(
                            icon: CupertinoIcons.exclamationmark_triangle,
                            title: localizations.logsNotLoaded,
                            color: palette.orange,
                          ),
                        )
                      ],
                    ),
                  ),
                );
              }

              return SafeArea(
                top: false,
                bottom: false,
                child: RefreshIndicator(
                  onRefresh: () async {
                    await logsProvider.fetchLogs(inOffset: 0);
                  },
                  displacement: 110,
                  child: NotificationListener(
                    onNotification: scrollListener,
                    child: CustomScrollView(
                      slivers: [
                        SliverOverlapInjector(
                          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                        ),
                        if (logs.isNotEmpty) SliverList.builder(
                          itemCount: logsProvider.isLoadingMore 
                            ? logs.length + 1 
                            : logs.length,
                          itemBuilder: (context, index) {
                            if (logsProvider.isLoadingMore == true && index == logs.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: CupertinoActivityIndicator(radius: 12),
                                ),
                              );
                            }
                            else if (logs[index].question.name != null) {
                              return LogTile(
                                log: logs[index],
                                index: index,
                                length: logs.length,
                                isLogSelected: widget.selectedLog != null && widget.selectedLog == logs[index],
                                onLogTap: (log) {
                                  if (!widget.twoColumns) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => LogDetailsScreen(
                                          log: log,
                                          dialog: false,
                                          twoColumns: widget.twoColumns,
                                        )
                                      )
                                    );
                                  }
                                  widget.onLogSelected(log);
                                },
                                twoColumns: widget.twoColumns,
                              );
                            }
                            else {
                              return null;
                            }
                          }
                        ),
                        if (logs.isEmpty) fill(
                          AppleEmptyState(
                            icon: CupertinoIcons.doc_text,
                            title: localizations.noLogsDisplay,
                            message: logsProvider.logsOlderThan != null
                              ? localizations.noLogsThatOld
                              : null,
                            color: palette.label3,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          )
        ),
      ),
    );
  }
}
