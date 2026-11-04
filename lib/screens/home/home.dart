// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/home/server_status.dart';
import 'package:adguard_home_manager/screens/home/top_items/top_items_lists.dart';
import 'package:adguard_home_manager/screens/home/combined_chart.dart';
import 'package:adguard_home_manager/screens/home/fab.dart';
import 'package:adguard_home_manager/screens/home/chart.dart';
import 'package:adguard_home_manager/screens/home/management_modal/management_modal.dart';
import 'package:adguard_home_manager/screens/servers/servers.dart';

import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';
import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/functions/open_url.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/models/dns_statistics.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  initState() {
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    statusProvider.getServerStatus(
      withLoadingIndicator: statusProvider.serverStatus != null ? false : true
    );

    final clientsProvider = Provider.of<ClientsProvider>(context, listen: false);
    clientsProvider.fetchClients(updateLoading:  false);

    super.initState();
  }

  Future<void> _refresh() async {
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);

    final result = await statusProvider.getServerStatus();
    if (!mounted || result) return;

    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: AppLocalizations.of(context)!.serverStatusNotRefreshed,
      color: AppleColors.red(Theme.of(context).brightness)
    );
  }

  void _openLogs(String value) {
    final logsProvider = Provider.of<LogsProvider>(context, listen: false);
    final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);

    logsProvider.setSelectedResultStatus(value: value, refetch: true);
    logsProvider.filterLogs();
    appConfigProvider.setSelectedScreen(2);
  }

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<StatusProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final serversProvider = Provider.of<ServersProvider>(context);

    final p = ApplePalette.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final bool wide = width > 700;

    final Server? server = serversProvider.selectedServer;
    final stats = statusProvider.serverStatus?.stats;
    final bool protectedOn = statusProvider.serverStatus?.generalEnabled == true;

    final address = server == null
      ? ''
      : "${server.connectionMethod}://${server.domain}${server.path ?? ""}${server.port != null ? ':${server.port}' : ""}";

    return AppleScreen(
      title: server?.name ?? AppLocalizations.of(context)!.noServerSelected,
      onRefresh: _refresh,
      floatingActionButton: const HomeFab(),
      actions: [
        if (!Platform.isAndroid && !Platform.isIOS)
          IconButton(
            onPressed: statusProvider.getServerStatus,
            icon: const Icon(CupertinoIcons.arrow_clockwise),
            tooltip: AppLocalizations.of(context)!.refresh,
          ),
        PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const Servers())
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.desktopcomputer),
                  const SizedBox(width: 10),
                  Text(AppLocalizations.of(context)!.servers)
                ],
              ),
            ),
            if (server != null && statusProvider.loadStatus == LoadStatus.loaded)
              PopupMenuItem(
                onTap: () => openUrl(address),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.globe),
                    const SizedBox(width: 10),
                    Text(AppLocalizations.of(context)!.webAdminPanel)
                  ],
                ),
              )
          ]
        ),
        const SizedBox(width: 4),
      ],
      slivers: [
        if (statusProvider.loadStatus == LoadStatus.loading)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppleEmptyState(
              icon: CupertinoIcons.hourglass,
              title: AppLocalizations.of(context)!.loadingStatus,
              color: p.label3,
            ),
          ),

        if (statusProvider.loadStatus == LoadStatus.error)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppleEmptyState(
              icon: CupertinoIcons.exclamationmark_triangle,
              title: AppLocalizations.of(context)!.errorLoadServerStatus,
              color: p.red,
            ),
          ),

        if (statusProvider.loadStatus == LoadStatus.loaded && stats != null) ...[
          SliverToBoxAdapter(
            child: _HeroCard(
              stats: stats,
              address: appConfigProvider.hideServerAddress ? null : address,
              protectionOn: protectedOn,
              protectionLabel: AppLocalizations.of(context)!.allProtections,
              onManage: () => showAppleSheet(
                context,
                title: AppLocalizations.of(context)!.allProtections,
                initialFraction: 0.65,
                body: const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ManagementModal(dialog: false),
                ),
              ),
              onOpenLogs: () => _openLogs('all'),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 7),
              child: Text(
                AppLocalizations.of(context)!.serverStatus.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.08,
                  color: p.label2,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ServerStatusWidget(
                serverStatus: statusProvider.serverStatus!,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 7),
              child: Text(
                AppLocalizations.of(context)!.statistics.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.08,
                  color: p.label2,
                ),
              ),
            ),
          ),

          if (appConfigProvider.combinedChartHome == false)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 0,
                  children: [
                    _chart(
                      width: width,
                      wide: wide,
                      child: HomeChart(
                        data: stats.dnsQueries,
                        label: AppLocalizations.of(context)!.dnsQueries,
                        primaryValue: intFormat(stats.numDnsQueries, Platform.localeName),
                        secondaryValue: "${doubleFormat(stats.avgProcessingTime*1000, Platform.localeName)} ms",
                        color: p.tint,
                        hoursInterval: stats.timeUnits == "days" ? 24 : 1,
                        onTapTitle: () => _openLogs('all'),
                        isDesktop: wide,
                      ),
                    ),
                    _chart(
                      width: width,
                      wide: wide,
                      child: HomeChart(
                        data: stats.blockedFiltering,
                        label: AppLocalizations.of(context)!.blockedFilters,
                        primaryValue: intFormat(stats.numBlockedFiltering, Platform.localeName),
                        secondaryValue: "${stats.numDnsQueries > 0 ? doubleFormat((stats.numBlockedFiltering/stats.numDnsQueries)*100, Platform.localeName) : 0}%",
                        color: p.red,
                        hoursInterval: stats.timeUnits == "days" ? 24 : 1,
                        onTapTitle: () => _openLogs('blocked'),
                        isDesktop: wide,
                      ),
                    ),
                    _chart(
                      width: width,
                      wide: wide,
                      child: HomeChart(
                        data: stats.replacedSafebrowsing,
                        label: AppLocalizations.of(context)!.malwarePhishingBlocked,
                        primaryValue: intFormat(stats.numReplacedSafebrowsing, Platform.localeName),
                        secondaryValue: "${stats.numDnsQueries > 0 ? doubleFormat((stats.numReplacedSafebrowsing/stats.numDnsQueries)*100, Platform.localeName) : 0}%",
                        color: p.orange,
                        hoursInterval: stats.timeUnits == "days" ? 24 : 1,
                        onTapTitle: () => _openLogs('blocked_safebrowsing'),
                        isDesktop: wide,
                      ),
                    ),
                    _chart(
                      width: width,
                      wide: wide,
                      child: HomeChart(
                        data: stats.replacedParental,
                        label: AppLocalizations.of(context)!.blockedAdultWebsites,
                        primaryValue: intFormat(stats.numReplacedParental, Platform.localeName),
                        secondaryValue: "${stats.numDnsQueries > 0 ? doubleFormat((stats.numReplacedParental/stats.numDnsQueries)*100, Platform.localeName) : 0}%",
                        color: p.purple,
                        hoursInterval: stats.timeUnits == "days" ? 24 : 1,
                        onTapTitle: () => _openLogs('blocked_parental'),
                        isDesktop: wide,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (appConfigProvider.combinedChartHome == true)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: CombinedHomeChart(),
              ),
            ),

          SliverToBoxAdapter(
            child: TopItemsLists(order: appConfigProvider.homeTopItemsOrder),
          ),
        ],
      ],
    );
  }

  Widget _chart({
    required Widget child,
    required double width,
    required bool wide,
  }) {
    return SizedBox(width: wide ? (width - 44) / 2 : width - 32, child: child);
  }
}

/// Green/red status card at the top of the overview.
class _HeroCard extends StatelessWidget {
  final DnsStatistics stats;
  final String? address;
  final bool protectionOn;
  final String protectionLabel;
  final VoidCallback onManage;
  final VoidCallback onOpenLogs;

  const _HeroCard({
    required this.stats,
    required this.address,
    required this.protectionOn,
    required this.protectionLabel,
    required this.onManage,
    required this.onOpenLogs,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    final double rate = stats.numDnsQueries > 0
      ? (stats.numBlockedFiltering / stats.numDnsQueries) * 100
      : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: AppleCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppleIconBadge(
                  icon: protectionOn ? CupertinoIcons.checkmark_shield : CupertinoIcons.slash_circle,
                  color: protectionOn ? p.green : p.red,
                  size: 34,
                  iconSize: 21,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        protectionLabel,
                        style: TextStyle(fontSize: 13, color: p.label2),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        protectionOn
                          ? AppLocalizations.of(context)!.protectionEnabled
                          : AppLocalizations.of(context)!.disabled,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: protectionOn ? p.label : p.red,
                        ),
                      ),
                    ],
                  ),
                ),
                AppleDonut(
                  percent: rate,
                  size: 56,
                  stroke: 7,
                  color: p.red,
                  child: Text(
                    '${rate.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: p.red,
                    ),
                  ),
                ),
              ],
            ),
            if (address != null) ...[
              const SizedBox(height: 10),
              Text(
                address!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontFamily: 'monospace',
                  color: p.label3,
                ),
              ),
            ],
            const SizedBox(height: 14),
            AppleSeparator(indent: 0, color: p.separatorSoft),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: AppleStatCard(
                      label: AppLocalizations.of(context)!.queries,
                      value: intFormat(stats.numDnsQueries, Platform.localeName),
                    ),
                  ),
                  Expanded(
                    child: AppleStatCard(
                      label: AppLocalizations.of(context)!.blocked,
                      value: intFormat(stats.numBlockedFiltering, Platform.localeName),
                      valueColor: p.red,
                    ),
                  ),
                  Expanded(
                    child: AppleStatCard(
                      label: AppLocalizations.of(context)!.elapsedTime,
                      value: "${doubleFormat(stats.avgProcessingTime*1000, Platform.localeName)} ms",
                    ),
                  ),
                ],
              ),
            ),
            AppleSeparator(indent: 0, color: p.separatorSoft),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppleButton.secondary(
                    label: protectionLabel,
                    icon: CupertinoIcons.slider_horizontal_3,
                    onPressed: onManage,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppleButton(
                    label: AppLocalizations.of(context)!.queryLogsAndStatistics,
                    icon: CupertinoIcons.doc_text,
                    onPressed: onOpenLogs,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
