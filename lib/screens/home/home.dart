// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/home/management_modal/management_modal.dart';
import 'package:adguard_home_manager/screens/settings/dhcp/dhcp.dart';
import 'package:adguard_home_manager/screens/settings/dns_rewrites/dns_rewrites.dart';
import 'package:adguard_home_manager/screens/settings/encryption/encryption.dart';
import 'package:adguard_home_manager/screens/settings/server_info/server_info.dart';

import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/format_time.dart';
import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/functions/update_blocking.dart';
import 'package:adguard_home_manager/models/dns_statistics.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/models/encryption.dart';
import 'package:adguard_home_manager/models/rewrite_rules.dart';
import 'package:adguard_home_manager/models/server.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  /// The windows the trend card offers, in milliseconds: a day, a week, a month.
  static const List<int> _rangesMs = [
    24 * 60 * 60 * 1000,
    7 * 24 * 60 * 60 * 1000,
    30 * 24 * 60 * 60 * 1000,
  ];

  /// The processing time the design layer measures the average against.
  static const int _referenceMs = 40;

  /// Which trend window and which ranking list are showing.
  int _range = 0;
  int _rank = 0;

  /// Bucket of the trend chart the user touched, or -1 for none.
  int _tip = -1;

  // The two service rows the status call does not answer: whether DoT is on
  // and how many rewrites the server holds.
  bool? _tlsEnabled;
  int? _rewriteCount;

  @override
  initState() {
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    final clientsProvider = Provider.of<ClientsProvider>(context, listen: false);

    clientsProvider.fetchClients(updateLoading: false);

    _load(
      withLoadingIndicator: statusProvider.serverStatus == null,
    );

    super.initState();
  }

  /// Asks for everything the page shows, one call after another because
  /// AdGuard Home caps the connections it will serve at once.
  Future<bool> _load({
    bool withLoadingIndicator = false,
  }) async {
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);

    final result = await statusProvider.getServerStatus(
      withLoadingIndicator: withLoadingIndicator,
    );

    // Refreshing is silent about everything but the status itself, which is
    // the only part a pull-to-refresh gesture can be expected to answer for.
    if (!mounted) return result;

    await statusProvider.getStatisticsConfig();
    if (!mounted) return result;
    await statusProvider.getTrend(recentMs: _rangesMs[_range]);
    if (!mounted) return result;
    await _loadServiceStates();

    return result;
  }

  Future<void> _loadServiceStates() async {
    final api = Provider.of<ServersProvider>(context, listen: false).apiClient2;
    if (api == null) return;

    final tls = await api.getEncryptionSettings();
    final rewrites = await api.getDnsRewriteRules();

    if (!mounted) return;

    setState(() {
      _tlsEnabled = tls.successful == true
        ? (tls.content as EncryptionData).enabled
        : null;
      _rewriteCount = rewrites.successful == true
        ? (rewrites.content as List<RewriteRules>).length
        : null;
    });
  }

  Future<void> _refresh() async {
    final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);

    final result = await _load();
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

  /// The trend of another window: a real request, not a rescaled answer.
  void _setRange(int index) {
    if (index == _range) return;

    setState(() {
      _range = index;
      _tip = -1;
    });

    Provider.of<StatusProvider>(context, listen: false)
      .getTrend(recentMs: _rangesMs[index]);
  }

  /// The shield button. Running, it asks what to do about the protection;
  /// paused, it simply resumes it, which is what the design layer does.
  void _toggleProtection() {
    final l = AppLocalizations.of(context)!;
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);

    if (statusProvider.serverStatus?.generalEnabled != true) {
      toggleProtection(context: context, filter: 'general', value: true);
      return;
    }

    showAppleActionSheet(
      context,
      title: l.protectionRunningNote(
        intFormat(statusProvider.serverStatus?.stats.numBlockedFiltering ?? 0, Platform.localeName),
      ),
      actions: [
        AppleSheetAction(
          label: l.pauseProtection,
          onTap: _pauseProtection,
        ),
        AppleSheetAction(
          label: l.manageProtection,
          onTap: _openProtectionSheet,
        ),
      ],
    );
  }

  Future<void> _pauseProtection() async {
    final l = AppLocalizations.of(context)!;

    // AdGuard Home counts a pause from the moment it stops, so each choice is
    // offered a second short of the round figure the label names.
    final durations = <String, int?>{
      l.seconds(30): 29000,
      l.minute(1): 59000,
      l.minutes(10): 599000,
      l.hour(1): 3599000,
      l.pauseForever: null,
    };

    await showAppleActionSheet(
      context,
      title: l.pauseProtection,
      actions: [
        for (final entry in durations.entries)
          AppleSheetAction(
            label: entry.key,
            destructive: entry.value == null,
            onTap: () => toggleProtection(
              context: context,
              filter: 'general',
              value: false,
              time: entry.value,
            ),
          ),
      ],
    );
  }

  void _openProtectionSheet() {
    showAppleSheet(
      context,
      title: AppLocalizations.of(context)!.manageProtection,
      initialFraction: 0.65,
      body: const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ManagementModal(dialog: false),
      ),
    );
  }

  void _openAllRankings() {
    showAppleSheet(
      context,
      title: AppLocalizations.of(context)!.topRanking,
      initialFraction: 0.85,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: _RankingSheet(rank: _rank),
      ),
      actions: [
        AppleButton(
          label: AppLocalizations.of(context)!.close,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<StatusProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final serversProvider = Provider.of<ServersProvider>(context);
    final clientsProvider = Provider.of<ClientsProvider>(context);

    final p = ApplePalette.of(context);
    final l = AppLocalizations.of(context)!;

    final Server? server = serversProvider.selectedServer;
    final stats = statusProvider.serverStatus?.stats;
    final bool protectedOn = statusProvider.serverStatus?.generalEnabled == true;

    final address = server == null
      ? ''
      : "${server.connectionMethod}://${server.domain}${server.path ?? ""}${server.port != null ? ':${server.port}' : ""}";

    // The line the design layer hangs under every page title: which server this
    // is, where it lives, and whether it is still protecting.
    final subtitle = [
      server?.name,
      if (!appConfigProvider.hideServerAddress) address,
      protectedOn ? l.protectionRunning : l.protectionPaused,
    ].where((part) => part != null && part.isNotEmpty).join(' · ');

    return AppleScreen(
      title: l.overview,
      subtitle: subtitle,
      subtitleDot: protectedOn ? p.green : p.red,
      onRefresh: _refresh,
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
              devices: clientsProvider.clients?.autoClients.length ?? 0,
              onToggleProtection: _toggleProtection,
              onManage: _openProtectionSheet,
              onOpenLogs: () => _openLogs('all'),
            ),
          ),

          SliverToBoxAdapter(
            child: _StatGrid(
              stats: stats,
              filtering: statusProvider.serverStatus!.filteringStatus,
              onOpenLogs: () => _openLogs('all'),
              onOpenBlockedLogs: () => _openLogs('blocked'),
            ),
          ),

          SliverToBoxAdapter(
            child: _TrendCard(
              trend: statusProvider.trend,
              loading: statusProvider.trendLoading,
              failed: statusProvider.trendFailed,
              range: _range,
              tip: _tip,
              timezone: _timezoneLabel(),
              onRange: _setRange,
              onTip: (index) => setState(() => _tip = index),
            ),
          ),

          SliverToBoxAdapter(
            child: _RankCard(
              stats: stats,
              rank: _rank,
              onRank: (index) => setState(() => _rank = index),
              onSeeAll: _openAllRankings,
            ),
          ),

          SliverToBoxAdapter(
            child: _ServicesGroup(
              server: server,
              status: statusProvider.serverStatus!,
              tlsEnabled: _tlsEnabled,
              rewriteCount: _rewriteCount,
              onServerInfo: () => _push(const ServerInformation()),
              onDhcp: () => _push(const DhcpScreen()),
              onEncryption: () => _push(const EncryptionSettings()),
              onRewrites: () => _push(const DnsRewritesScreen()),
            ),
          ),
        ],
      ],
    );
  }
}

/// The device's own clock offset, which is what the buckets of the trend chart
/// are counted against.
String _timezoneLabel() {
  final offset = DateTime.now().timeZoneOffset.abs();
  final hours = offset.inHours.toString().padLeft(2, '0');
  final minutes = (offset.inMinutes % 60).toString().padLeft(2, '0');
  final negative = DateTime.now().timeZoneOffset.isNegative;

  return 'UTC${negative ? '-' : '+'}$hours:$minutes';
}

/// One label per bucket of [s].
///
/// The statistics reply holds no timestamps of its own, only the size of a
/// bucket in `time_units`, so the axis is counted back from now the same way
/// the charts under `lib/screens/home` have always done it.
List<String> _bucketLabels(AppLocalizations l, DnsStatistics s) {
  final count = s.dnsQueries.length;
  if (count == 0) return const [];

  final bool daily = s.timeUnits == 'days';
  final now = DateTime.now();
  final labels = <String>[
    for (var i = 0; i < count; i++)
      formatTimestamp(
        now.subtract(Duration(hours: (count - 1 - i) * (daily ? 24 : 1))),
        daily ? (count <= 8 ? 'EEEE' : 'd') : 'HH',
      ),
  ];

  // The newest bucket covers the current hour or day, not a finished one.
  labels[count - 1] = daily ? l.todayLabel : l.nowLabel;

  return labels;
}

/// The card the design layer opens the overview with: the shield, what the
/// server is doing, how much it has stopped and the two ways in.
class _HeroCard extends StatelessWidget {
  final DnsStatistics stats;
  final bool protectionOn;

  /// Devices the server knows about, shown on the first line of the card.
  final int devices;
  final VoidCallback onToggleProtection;
  final VoidCallback onManage;
  final VoidCallback onOpenLogs;

  const _HeroCard({
    required this.stats,
    required this.protectionOn,
    required this.devices,
    required this.onToggleProtection,
    required this.onManage,
    required this.onOpenLogs,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final l = AppLocalizations.of(context)!;

    final double rate = stats.numDnsQueries > 0
      ? (stats.numBlockedFiltering / stats.numDnsQueries) * 100
      : 0;

    // Two lines, like the design layer: what the server is doing right now,
    // then how much of the traffic the blocking accounts for.
    final status = protectionOn
      ? l.protectingDevices(devices)
      : l.allQueriesAllowedDirectly;
    final counts = l.blockedOfQueries(
      intFormat(stats.numBlockedFiltering, Platform.localeName),
      intFormat(stats.numDnsQueries, Platform.localeName),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: AppleHero(
        active: protectionOn,
        icon: protectionOn
            ? CupertinoIcons.checkmark_shield
            : CupertinoIcons.pause_circle,
        onTapIcon: onToggleProtection,
        title: protectionOn ? l.protectionOn : l.protectionPaused,
        description: "$status\n$counts",
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
            label: l.manageProtection,
            onPressed: onManage,
          ),
          AppleButton(
            label: l.viewLogs,
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
  final FilteringStatus filtering;
  final VoidCallback onOpenLogs;
  final VoidCallback onOpenBlockedLogs;

  const _StatGrid({
    required this.stats,
    required this.filtering,
    required this.onOpenLogs,
    required this.onOpenBlockedLogs,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final l = AppLocalizations.of(context)!;
    final locale = Platform.localeName;

    final double rate = stats.numDnsQueries > 0
      ? (stats.numBlockedFiltering / stats.numDnsQueries) * 100
      : 0;

    final double millis = stats.avgProcessingTime * 1000;
    final bool fast = millis <= _HomeState._referenceMs;

    // The rules that are actually in force: what the enabled lists hold, plus
    // the server's own user rules.
    final int rules = filtering.filters
      .where((filter) => filter.enabled)
      .fold<int>(0, (sum, filter) => sum + filter.rulesCount) + filtering.userRules.length;
    final int lists = filtering.filters.where((filter) => filter.enabled).length;

    List<double> series(List<int> values) =>
        values.map((value) => value.toDouble()).toList();

    // Yesterday's comparison: the newest bucket against the one a day earlier,
    // both from the series the server already sent. It needs a day of history
    // on both sides, so a server that keeps less shows no caption.
    final deltas = stats.dnsQueries;
    final int back = stats.timeUnits == 'days' ? 2 : 25;
    final int previous = deltas.length >= back ? deltas[deltas.length - back] : 0;
    final int latest = deltas.isNotEmpty ? deltas[deltas.length - 1] : 0;
    final String? versus = deltas.length < back || previous == 0
      ? null
      : l.vsYesterday(
          '${(latest - previous) > 0 ? '▲ ' : '▼ '}${percentFormat(((latest - previous) / previous).abs() * 100, locale)}%');

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: AppleStatGrid(
        tiles: [
          AppleStatTile(
            label: l.totalQueries,
            value: compactFormat(stats.numDnsQueries, locale),
            caption: versus,
            captionColor: versus == null
              ? null
              : (latest >= previous ? p.green : p.red),
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
            value: compactFormat(stats.numBlockedFiltering, locale),
            caption: l.blockRate("${percentFormat(rate, locale)}%"),
            captionColor: p.red,
            sparkline: AppleSparkline(
              values: series(stats.blockedFiltering),
              color: p.red,
              width: 74,
              height: 28,
            ),
            onTap: onOpenBlockedLogs,
          ),
          AppleStatTile(
            label: l.avgProcessingTime,
            value: doubleFormat(millis, locale),
            unit: 'ms',
            caption: fast
              ? l.belowReference('${_HomeState._referenceMs}')
              : l.aboveReference('${_HomeState._referenceMs}'),
            captionColor: p.label2,
          ),
          AppleStatTile(
            label: l.activeRules,
            value: compactFormat(rules, locale),
            caption: l.filterListsCount(intFormat(lists, locale)),
            captionColor: p.label2,
          ),
        ],
      ),
    );
  }
}

/// 流量趋势: one card, one window at a time, asked for from the server.
class _TrendCard extends StatelessWidget {
  final DnsStatistics? trend;
  final bool loading;
  final bool failed;
  final int range;
  final int tip;
  final String timezone;
  final ValueChanged<int> onRange;
  final ValueChanged<int> onTip;

  const _TrendCard({
    required this.trend,
    required this.loading,
    required this.failed,
    required this.range,
    required this.tip,
    required this.timezone,
    required this.onRange,
    required this.onTip,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final l = AppLocalizations.of(context)!;
    final locale = Platform.localeName;

    final t = trend;
    final labels = t == null ? const <String>[] : _bucketLabels(l, t);
    final queries = t == null ? const <double>[] : [for (final v in t.dnsQueries) v.toDouble()];
    final blocked = t == null ? const <double>[] : [for (final v in t.blockedFiltering) v.toDouble()];
    final total = t == null ? 0 : t.dnsQueries.fold<int>(0, (a, b) => a + b);

    final bool drawn = queries.length > 1;

    final String note;
    if (tip >= 0 && tip < queries.length) {
      final asked = queries[tip];
      final stopped = blocked[tip];
      // gen-l10n hands the placeholders of a message to the method in
      // alphabetical order, not in the order the sentence reads them.
      note = l.chartTipPoint(
        intFormat(stopped.round(), locale),
        labels[tip],
        "${wholePercentFormat(asked > 0 ? stopped / asked * 100 : 0, locale)}%",
        intFormat(asked.round(), locale),
      );
    }
    else {
      note = l.chartTipHint;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppleGroupHeader(
          title: l.trafficTrend,
          trailing: timezone,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 7),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppleCard(
            radius: BorderRadius.circular(20),
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: AppleSegmented(
                    labels: [l.hours24, l.days7, l.days30],
                    selectedIndex: range,
                    onChanged: onRange,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                  child: Row(
                    children: [
                      Flexible(child: _legend(p.tint, l.queries)),
                      const SizedBox(width: 14),
                      Flexible(child: _legend(p.red, l.blocked)),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          l.queriesTotal(compactFormat(total, locale)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: p.label,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (loading)
                  const SizedBox(
                    height: 170,
                    child: AppleLoading(),
                  )
                else if (drawn)
                  AppleTrendChart(
                    queries: queries,
                    blocked: blocked,
                    labels: labels,
                    selectedIndex: tip,
                    onSelect: onTip,
                  )
                else
                  SizedBox(
                    height: 170,
                    child: Center(
                      child: Text(
                        failed ? l.errorLoadServerStatus : l.noDataChart,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: p.label3),
                      ),
                    ),
                  ),
                Container(
                  constraints: const BoxConstraints(minHeight: 18),
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                  child: Text(
                    note,
                    style: TextStyle(fontSize: 12, color: p.label2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

/// 热门排行: the five busiest entries of one list, with the whole list behind
/// the 全部 action.
class _RankCard extends StatelessWidget {
  final DnsStatistics stats;
  final int rank;
  final ValueChanged<int> onRank;
  final VoidCallback onSeeAll;

  const _RankCard({
    required this.stats,
    required this.rank,
    required this.onRank,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // The card keeps five; the sheet behind 全部 keeps the whole reply.
    final rows = _rankEntries(stats, rank).take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppleGroupHeader(
          title: l.topRanking,
          trailingWidget: AppleHeaderAction(label: l.all, onPressed: onSeeAll),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 7),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppleCard(
            radius: BorderRadius.circular(20),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: AppleSegmented(
                    labels: [l.blockedDomainsShort, l.queriedDomainsShort, l.activeDevices],
                    selectedIndex: rank,
                    onChanged: onRank,
                  ),
                ),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
                    child: Text(
                      l.noData,
                      style: TextStyle(
                        fontSize: 13,
                        color: ApplePalette.of(context).label3,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i != 0) const AppleSeparator(indent: 14, endIndent: 0),
                    _RankRow(
                      entry: rows[i],
                      place: i,
                      variant: rank,
                      largest: rows.first.value,
                    ),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The entries of one ranking, in the order the server sent them.
List<MapEntry<String, int>> _rankEntries(DnsStatistics stats, int rank) {
  final source = rank == 0
    ? stats.topBlockedDomains
    : rank == 1
      ? stats.topQueriedDomains
      : stats.topClients;

  return [
    for (final item in source)
      for (final entry in item.entries) entry,
  ];
}

/// One row of a ranking: the place, the name, a bar measured against the
/// busiest entry and the count.
class _RankRow extends StatelessWidget {
  final MapEntry<String, int> entry;
  final int place;

  /// Which ranking this row belongs to, which decides the colour of the bar.
  final int variant;
  final int largest;

  const _RankRow({
    required this.entry,
    required this.place,
    required this.variant,
    required this.largest,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final color = variant == 0 ? p.red : variant == 2 ? p.indigo : p.tint;
    final fraction = largest <= 0 ? 0.0 : (entry.value / largest).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(
              '${place + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.label3,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) => Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: p.fill2,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: constraints.maxWidth * fraction,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Text(
            intFormat(entry.value, Platform.localeName),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: p.label2,
            ),
          ),
        ],
      ),
    );
  }
}

/// The whole ranking, behind the 全部 action of the card.
class _RankingSheet extends StatefulWidget {
  final int rank;

  const _RankingSheet({required this.rank});

  @override
  State<_RankingSheet> createState() => _RankingSheetState();
}

class _RankingSheetState extends State<_RankingSheet> {
  late int _rank = widget.rank;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final stats = Provider.of<StatusProvider>(context).serverStatus?.stats;
    final rows = stats == null ? <MapEntry<String, int>>[] : _rankEntries(stats, _rank);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppleSegmented(
          labels: [l.blockedDomainsShort, l.queriedDomainsShort, l.activeDevices],
          selectedIndex: _rank,
          height: 38,
          onChanged: (index) => setState(() => _rank = index),
        ),
        const SizedBox(height: 12),
        AppleListSection(
          children: [
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                child: Text(
                  l.noData,
                  style: TextStyle(
                    fontSize: 13,
                    color: ApplePalette.of(context).label3,
                  ),
                ),
              )
            else
              for (var i = 0; i < rows.length; i++)
                _RankRow(
                  entry: rows[i],
                  place: i,
                  variant: _rank,
                  largest: rows.first.value,
                ),
          ],
        ),
      ],
    );
  }
}

/// 服务: the four server screens the overview links to.
class _ServicesGroup extends StatelessWidget {
  final Server? server;
  final ServerStatus status;
  final bool? tlsEnabled;
  final int? rewriteCount;
  final VoidCallback onServerInfo;
  final VoidCallback onDhcp;
  final VoidCallback onEncryption;
  final VoidCallback onRewrites;

  const _ServicesGroup({
    required this.server,
    required this.status,
    required this.tlsEnabled,
    required this.rewriteCount,
    required this.onServerInfo,
    required this.onDhcp,
    required this.onEncryption,
    required this.onRewrites,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final l = AppLocalizations.of(context)!;

    return AppleListSection(
      title: l.services,
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      children: [
        AppleListTile(
          icon: Icons.dns,
          iconColor: p.indigo,
          title: l.serverInformation,
          subtitle: status.serverVersion,
          value: server?.name,
          onTap: onServerInfo,
        ),
        AppleListTile(
          icon: CupertinoIcons.wifi,
          iconColor: p.tint,
          title: l.dhcp,
          value: status.dhcpAvailable ? l.enabled : l.disabled,
          onTap: onDhcp,
        ),
        AppleListTile(
          icon: CupertinoIcons.lock,
          iconColor: p.green,
          title: l.dnsOverTls,
          // The design layer calls a running DoT server "configured" rather
          // than "enabled": the row reports the setup, not a switch.
          value: tlsEnabled == null
            ? null
            : tlsEnabled == true
              ? l.configured
              : l.disabled,
          onTap: onEncryption,
        ),
        AppleListTile(
          icon: CupertinoIcons.globe,
          iconColor: p.orange,
          title: l.dnsRewrites,
          // A trailing control takes the place of the disclosure, so the count
          // and the chevron the design layer draws next to it travel together.
          trailing: rewriteCount == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(
                      color: p.fill2,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$rewriteCount',
                      style: TextStyle(fontSize: 15, color: p.label2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const AppleChevron(),
                ],
              ),
          onTap: onRewrites,
        ),
      ],
    );
  }
}
