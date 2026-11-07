// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/home/management_modal/management_modal.dart';
import 'package:adguard_home_manager/screens/clients/client/device_tile.dart';
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
import 'package:adguard_home_manager/functions/retention_label.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/functions/update_blocking.dart';
import 'package:adguard_home_manager/models/applied_filters.dart';
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

  /// Which trend window is showing.
  int _range = 0;

  /// Which ranking the card shows, or null until the user picks one.
  ///
  /// Held as the item rather than as a segment index: the sequence and the set
  /// of rankings come from a setting the user can change while this page is
  /// alive, and an index would then point at a segment that moved or went away.
  HomeTopItems? _rank;

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

    // Nothing below this line can be shown without the status, so a server
    // that did not answer for it is not asked four more times. Each of those
    // calls waits out its own timeout, and a refresh that keeps spinning for
    // half a minute after the page already said "could not be loaded" reads
    // as a hung app rather than an unreachable server.
    if (!mounted || !result) return result;

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
      color: ApplePalette.of(context).red,
    );
  }

  /// Jumps to the query log with [statuses] already applied; an empty list is
  /// the unfiltered log.
  void _openLogs(List<LogStatus> statuses) {
    final logsProvider = Provider.of<LogsProvider>(context, listen: false);
    final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);

    logsProvider.setSelectedStatuses(statuses);
    logsProvider.filterLogs();
    appConfigProvider.setSelectedScreen(2);
  }

  /// The trend of another window: a real request, not a rescaled answer.
  ///
  /// AdGuard Home keeps a rolling window, so a longer range is a change to the
  /// server's retention rather than a query. The selection stays where it was
  /// until that change is agreed to: a range that quietly shows another
  /// range's data is a difference the design layer cannot tell apart.
  Future<void> _setRange(int index) async {
    if (index == _range) return;

    final l = AppLocalizations.of(context)!;
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    final int wanted = _rangesMs[index];

    if (!statusProvider.needsLongerWindow(wanted)) {
      setState(() {
        _range = index;
        _tip = -1;
      });

      await statusProvider.getTrend(recentMs: wanted);
      return;
    }

    final int kept = statusProvider.statisticsIntervalMs ?? wanted;

    await showAppleActionSheet(
      context,
      title: l.statisticsWindowShort(_windowLabel(l, kept)),
      actions: [
        AppleSheetAction(
          label: l.extendStatisticsTo(_rangeLabel(l, index)),
          onTap: () => _extendWindow(index, wanted),
        ),
      ],
    );
  }

  /// Raises the retention, then asks the server for the window it can now
  /// answer.
  Future<void> _extendWindow(int index, int wanted) async {
    final l = AppLocalizations.of(context)!;
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);

    final extended = await statusProvider.extendStatisticsInterval(wanted);
    if (!mounted) return;

    if (!extended) {
      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: l.statisticsConfigNotUpdated,
        color: ApplePalette.of(context).red,
      );
      return;
    }

    setState(() {
      _range = index;
      _tip = -1;
    });

    await statusProvider.getTrend(recentMs: wanted);
    if (!mounted) return;

    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: l.statisticsConfigUpdated,
      color: ApplePalette.of(context).green,
    );
  }

  /// The name the design layer gives the trend window [index].
  static String _rangeLabel(AppLocalizations l, int index) =>
      [l.hours24, l.days7, l.days30][index];

  /// How a retention period of [ms] is written out.
  static String _windowLabel(AppLocalizations l, int ms) =>
      retentionLabel(l, ms);

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

  void _openAllRankings(List<HomeTopItems> rankings, HomeTopItems rank) {
    showAppleSheet(
      context,
      title: AppLocalizations.of(context)!.topRanking,
      initialFraction: 0.85,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: _RankingSheet(rankings: rankings, rank: rank),
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

    // The rankings the card offers: one stored list that carries both halves of
    // the setting, since turning a ranking off takes it out of the order. The
    // one showing is null while the user has every ranking turned off, which
    // leaves the card out rather than showing a control with no segments.
    final rankings = appConfigProvider.homeTopItemsOrder;
    final shown = rankings.isEmpty
      ? null
      : rankings.contains(_rank) ? _rank : rankings.first;
    final bool protectedOn = statusProvider.serverStatus?.generalEnabled == true;
    // A server that never answered has no protection state to report, and
    // neither does one that answered once and has not answered since: the
    // numbers left on screen are then the last truth, not the present one.
    // Either way, saying "paused" or "running" sends the user off to fix
    // something the app has no evidence is broken.
    final bool statusKnown =
        statusProvider.serverStatus != null &&
        statusProvider.loadStatus != LoadStatus.error;

    final address = server == null
      ? ''
      : "${server.connectionMethod}://${server.domain}${server.path ?? ""}${server.port != null ? ':${server.port}' : ""}";

    // The line the design layer hangs under every page title: which server
    // this is and whether it is still protecting. The address comes last
    // because it is the long part and the line cuts its tail when the phone
    // is narrow: the state is what has to survive.
    final subtitle = [
      server?.name,
      !statusKnown
        ? l.protectionUnknown
        : protectedOn ? l.protectionRunning : l.protectionPaused,
      if (!appConfigProvider.hideServerAddress) address,
    ].where((part) => part != null && part.isNotEmpty).join(' · ');

    return AppleScreen(
      title: l.overview,
      subtitle: subtitle,
      subtitleDot: !statusKnown ? p.label3 : protectedOn ? p.green : p.red,
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
              // Pull-to-refresh works here but is invisible on a page that
              // shows nothing else, so the failure offers the way out itself.
              action: AppleFormButton(
                label: AppLocalizations.of(context)!.refresh,
                background: p.tint,
                foreground: onTint(p.tint),
                onPressed: () => _refresh(),
              ),
              color: p.red,
            ),
          ),

        if (statusProvider.loadStatus == LoadStatus.loaded && stats != null) ...[
          SliverToBoxAdapter(
            child: _HeroCard(
              stats: stats,
              protectionOn: protectedOn,
              devices: mergeDevices(
                active: clientsProvider.clients?.autoClients ?? const [],
                added: clientsProvider.clients?.clients ?? const [],
              ).length,
              onToggleProtection: _toggleProtection,
            ),
          ),

          SliverToBoxAdapter(
            child: _StatGrid(
              stats: stats,
              filtering: statusProvider.serverStatus!.filteringStatus,
              onOpenLogs: () => _openLogs(const []),
              onOpenBlockedLogs: () => _openLogs(const [LogStatus.blocked]),
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

          if (shown != null)
            SliverToBoxAdapter(
              child: _RankCard(
                stats: stats,
                rankings: rankings,
                rank: shown,
                onRank: (item) => setState(() => _rank = item),
                onSeeAll: () => _openAllRankings(rankings, shown),
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
/// server is doing and how much it has stopped. The shield itself is the only
/// way in: the buttons the card used to carry duplicated the log tab and the
/// sheet the shield already offers.
class _HeroCard extends StatelessWidget {
  final DnsStatistics stats;
  final bool protectionOn;

  /// Devices the server knows about, shown on the first line of the card.
  final int devices;
  final VoidCallback onToggleProtection;

  const _HeroCard({
    required this.stats,
    required this.protectionOn,
    required this.devices,
    required this.onToggleProtection,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final l = AppLocalizations.of(context)!;

    final double rate = stats.numDnsQueries > 0
      ? (stats.numBlockedFiltering / stats.numDnsQueries) * 100
      : 0;

    // Two lines, like the design layer: what the server is doing right now,
    // then how much of the traffic the blocking accounts for. The count is the
    // same set the devices page lists, so the two screens never disagree about
    // how many devices the server is working for.
    final status = protectionOn
      ? l.protectingDevices(devices, intFormat(devices, Platform.localeName))
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
          child: Text(
            // A bare ring over "0%" reads as a spinner that never finished.
            // With no queries there is no rate to show, so say so.
            stats.numDnsQueries > 0 ? '${rate.toStringAsFixed(0)}%' : '—',
            style: TextStyle(
              fontSize: stats.numDnsQueries > 0 ? 15 : 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: stats.numDnsQueries > 0 ? p.label : p.label3,
            ),
          ),
        ),
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
          _StatTile(
            label: l.totalQueries,
            value: intFormat(stats.numDnsQueries, locale),
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
          _StatTile(
            label: l.blocked,
            value: intFormat(stats.numBlockedFiltering, locale),
            caption: l.blockRate("${percentFormat(rate, locale)}%"),
            // Danger colour on a rate measured over no traffic is an alarm
            // about nothing.
            captionColor: stats.numDnsQueries > 0 ? p.red : p.label2,
            sparkline: AppleSparkline(
              values: series(stats.blockedFiltering),
              color: p.red,
              width: 74,
              height: 28,
            ),
            onTap: onOpenBlockedLogs,
          ),
          _StatTile(
            label: l.avgProcessingTime,
            value: doubleFormat(millis, locale),
            unit: 'ms',
            caption: stats.numDnsQueries == 0
              ? null
              : fast
                ? l.belowReference('${_HomeState._referenceMs}')
                : l.aboveReference('${_HomeState._referenceMs}'),
            captionColor: p.label2,
          ),
          _StatTile(
            label: l.activeRules,
            value: intFormat(rules, locale),
            caption: l.filterListsCount(lists),
            captionColor: p.label2,
          ),
        ],
      ),
    );
  }
}

/// One tile of the statistics grid, drawn like `AppleStatTile` but with the
/// number told in full: the page promises exact figures, and an exact figure
/// of seven digits does not fit a half-width tile at the design layer's 26pt.
/// A [FittedBox] scales the number down until it fits instead of cutting it
/// to "54,7…", so every digit stays on one line, in tabular figures.
class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  /// Unit shown after the number, smaller and grey.
  final String? unit;

  /// Note under the number, e.g. a percentage.
  final String? caption;
  final Color? captionColor;

  /// Series drawn behind the number, e.g. an `AppleSparkline`.
  final Widget? sparkline;

  final VoidCallback? onTap;

  const _StatTile({
    required this.label,
    required this.value,
    this.unit,
    this.caption,
    this.captionColor,
    this.sparkline,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // The sparkline owns the right of the tile, so only the label
                // and the number step around it. The caption keeps the full
                // width, as it does in the design layer's tile.
                Padding(
                  padding: EdgeInsets.only(right: sparkline != null ? 80 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: p.label2,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.bottomLeft,
                              child: Text(
                                value,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -1.2,
                                  height: 1.05,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                  color: p.label,
                                ),
                              ),
                            ),
                          ),
                          if (unit != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Text(
                                unit!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: p.label2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (caption != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: captionColor ?? p.label3,
                        height: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
            // Anchored to the top so the caption keeps the width it needs.
            if (sparkline != null)
              Positioned(
                right: 8,
                top: 10,
                child: Opacity(opacity: 0.62, child: sparkline!),
              ),
          ],
        ),
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
    final queriesTotal = t == null ? 0 : t.dnsQueries.fold<int>(0, (a, b) => a + b);
    final blockedTotal = t == null ? 0 : t.blockedFiltering.fold<int>(0, (a, b) => a + b);

    // A run of empty buckets is not a chart: the painter gives up below two
    // values, so asking it for 24 zeros leaves a blank card instead of the
    // "no data" note.
    final bool drawn = queries.length > 1 && queries.any((v) => v > 0);

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
                      // Each series carries its own exact total: one combined
                      // compact figure told the user nothing about the split
                      // the chart draws, and rounded numbers are not the
                      // accuracy the page promises.
                      Expanded(
                        child: _legend(p.tint, l.queries, intFormat(queriesTotal, locale), p.label2),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _legend(p.red, l.blocked, intFormat(blockedTotal, locale), p.label2),
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
                        failed ? l.trendNotLoaded : l.noDataChart,
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

  Widget _legend(Color color, String label, String count, Color textColor) {
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
          // Scaled down rather than ellipsized: an exact total is the point of
          // the legend, so a long figure shrinks instead of losing digits.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$label '),
                  TextSpan(
                    text: count,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              style: TextStyle(fontSize: 12, color: textColor),
            ),
          ),
        ),
      ],
    );
  }
}

/// 热门排行: the five busiest entries of one list, with the whole list behind
/// the 全部 action.
class _RankCard extends StatelessWidget {
  final DnsStatistics stats;

  /// The rankings on offer, in the sequence the setting stores them in.
  final List<HomeTopItems> rankings;
  final HomeTopItems rank;
  final ValueChanged<HomeTopItems> onRank;
  final VoidCallback onSeeAll;

  const _RankCard({
    required this.stats,
    required this.rankings,
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
                    labels: <String>[
                      for (final item in rankings) _rankSegmentLabel(l, item),
                    ],
                    selectedIndex: rankings.indexOf(rank),
                    onChanged: (index) => onRank(rankings[index]),
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
List<MapEntry<String, int>> _rankEntries(DnsStatistics stats, HomeTopItems rank) {
  final List<Map<String, int>> source;
  switch (rank) {
    case HomeTopItems.blockedDomains:
      source = stats.topBlockedDomains;
      break;
    case HomeTopItems.queriedDomains:
      source = stats.topQueriedDomains;
      break;
    case HomeTopItems.recurrentClients:
      source = stats.topClients;
      break;
  }

  return [
    for (final item in source)
      for (final entry in item.entries) entry,
  ];
}

/// The short label one ranking carries on the segment control. The settings
/// page names the same three rankings with their long titles.
String _rankSegmentLabel(AppLocalizations l, HomeTopItems item) {
  switch (item) {
    case HomeTopItems.blockedDomains:
      return l.blockedDomainsShort;
    case HomeTopItems.queriedDomains:
      return l.queriedDomainsShort;
    case HomeTopItems.recurrentClients:
      return l.activeDevices;
  }
}

/// One row of a ranking: the place, the name, a bar measured against the
/// busiest entry and the count.
class _RankRow extends StatelessWidget {
  final MapEntry<String, int> entry;
  final int place;

  /// Which ranking this row belongs to, which decides the colour of the bar.
  final HomeTopItems variant;
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
    final color = variant == HomeTopItems.blockedDomains
      ? p.red
      : variant == HomeTopItems.recurrentClients ? p.indigo : p.tint;
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
                fontWeight: FontWeight.w600,
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
  final List<HomeTopItems> rankings;
  final HomeTopItems rank;

  const _RankingSheet({required this.rankings, required this.rank});

  @override
  State<_RankingSheet> createState() => _RankingSheetState();
}

class _RankingSheetState extends State<_RankingSheet> {
  late HomeTopItems _rank = widget.rank;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final stats = Provider.of<StatusProvider>(context).serverStatus?.stats;
    final rows = stats == null ? <MapEntry<String, int>>[] : _rankEntries(stats, _rank);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppleSegmented(
          labels: <String>[
            for (final item in widget.rankings) _rankSegmentLabel(l, item),
          ],
          selectedIndex: widget.rankings.indexOf(_rank),
          large: true,
          onChanged: (index) => setState(() => _rank = widget.rankings[index]),
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
          icon: CupertinoIcons.desktopcomputer,
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
