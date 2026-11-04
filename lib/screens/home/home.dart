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

    // The status line under the title, as the design layer draws it. The
    // protection word differs from the one the hero card uses, so the two
    // lines do not read as the same sentence twice.
    final subtitle = [
      server?.name,
      if (!appConfigProvider.hideServerAddress) address,
      protectedOn
          ? AppLocalizations.of(context)!.enabled
          : AppLocalizations.of(context)!.disabled,
    ].where((part) => part != null && part.isNotEmpty).join(' · ');

    return AppleScreen(
      title: AppLocalizations.of(context)!.home,
      subtitle: subtitle,
      subtitleDot: protectedOn ? p.green : p.red,
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
            child: _StatGrid(
              stats: stats,
              onOpenLogs: () => _openLogs('all'),
            ),
          ),

          // The server status card titles itself, so no caption here.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ServerStatusWidget(
                serverStatus: statusProvider.serverStatus!,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: AppleFormGroupLabel(
              AppLocalizations.of(context)!.statistics,
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 7),
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
  final bool protectionOn;
  final String protectionLabel;
  final VoidCallback onManage;
  final VoidCallback onOpenLogs;

  const _HeroCard({
    required this.stats,
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
      child: AppleHero(
        active: protectionOn,
        icon: protectionOn
            ? CupertinoIcons.checkmark_shield
            : CupertinoIcons.pause_circle,
        onTapIcon: onManage,
        title: protectionOn
            ? AppLocalizations.of(context)!.protectionEnabled
            : AppLocalizations.of(context)!.disabled,
        description:
            "${AppLocalizations.of(context)!.blocked} "
            "${intFormat(stats.numBlockedFiltering, Platform.localeName)} / "
            "${intFormat(stats.numDnsQueries, Platform.localeName)}",
        trailing: AppleDonut(
          percent: rate,
          size: 58,
          stroke: 7,
          color: p.red,
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: p.label,
              ),
              children: [
                TextSpan(text: rate.toStringAsFixed(0)),
                TextSpan(
                  text: '%',
                  style: TextStyle(fontSize: 10, letterSpacing: 0),
                ),
              ],
            ),
          ),
        ),
        actions: [
          AppleButton.secondary(
            label: protectionLabel,
            onPressed: onManage,
          ),
          AppleButton(
            label: AppLocalizations.of(context)!.logs,
            onPressed: onOpenLogs,
          ),
        ],
      ),
    );
  }
}

/// The four headline numbers of the overview, as the design layer grids them.
class _StatGrid extends StatelessWidget {
  final DnsStatistics stats;
  final VoidCallback onOpenLogs;

  const _StatGrid({
    required this.stats,
    required this.onOpenLogs,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final l = AppLocalizations.of(context)!;

    final double rate = stats.numDnsQueries > 0
      ? (stats.numBlockedFiltering / stats.numDnsQueries) * 100
      : 0;

    List<double> series(List<int> values) =>
        values.map((value) => value.toDouble()).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AppleStatGrid(
        tiles: [
          AppleStatTile(
            label: l.queries,
            value: intFormat(stats.numDnsQueries, Platform.localeName),
            sparkline: AppleSparkline(
              values: series(stats.dnsQueries),
              color: p.tint,
              width: 74,
              height: 28,
            ),
            onTap: onOpenLogs,
          ),
          AppleStatTile(
            label: l.blocked,
            value: intFormat(stats.numBlockedFiltering, Platform.localeName),
            caption: "${doubleFormat(rate, Platform.localeName)}%",
            captionColor: p.red,
            sparkline: AppleSparkline(
              values: series(stats.blockedFiltering),
              color: p.red,
              width: 74,
              height: 28,
            ),
          ),
          AppleStatTile(
            label: l.elapsedTime,
            value: doubleFormat(
              stats.avgProcessingTime * 1000,
              Platform.localeName,
            ),
            unit: 'ms',
          ),
          AppleStatTile(
            label: l.malwarePhishingBlocked,
            value: intFormat(stats.numReplacedSafebrowsing, Platform.localeName),
            sparkline: AppleSparkline(
              values: series(stats.replacedSafebrowsing),
              color: p.orange,
              width: 74,
              height: 28,
            ),
          ),
        ],
      ),
    );
  }
}
