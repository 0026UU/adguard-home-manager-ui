import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/models/dns_statistics.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/models/filtering_status.dart' hide Filter;
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/providers/live_logs_provider.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/logs/logs_list.dart';

// The logs page reads two sources: the query log the server keeps and the live
// stream it polls. Neither test file can reach a server, so both use these
// doubles, which answer from the fixtures below.

Log logFixture(String domain, {String reason = 'FilteredBlackList', String? client}) => Log(
  cached: false,
  client: client ?? '192.168.1.20',
  clientInfo: ClientInfo(
    whois: Whois(),
    name: 'livingroom-mac',
    disallowedRule: '',
    disallowed: false,
  ),
  clientProto: '53',
  elapsedMs: '1.234',
  question: Question(questionClass: 'IN', name: domain, type: 'A'),
  reason: reason,
  rules: const [],
  status: 'NOERROR',
  time: DateTime.utc(2024, 5, 1, 12),
  upstream: '8.8.8.8:53',
  answer: const [],
);

List<Log> storedLogs() => [
  logFixture('ads.example.org'),
  logFixture('tracker.example.net'),
  logFixture('news.example.org', reason: 'Filtered'),
];

/// The page asks the server for logs on every filter change.
class OfflineLogs extends LogsProvider {
  int fetches = 0;
  int filters = 0;

  /// A real call answers after the frame, so the page never hears about new
  /// data while it is still building.
  Future<void> _settled() => Future<void>.delayed(Duration.zero);

  void _publish(List<Log> logs) {
    setLogsData(LogsData(data: logs));
    setLoadStatus(LoadStatus.loaded);
  }

  @override
  Future<bool> fetchLogs({
    int? inOffset,
    bool? loadingMore,
    String? searchText,
  }) async {
    await _settled();
    fetches++;
    _publish(storedLogs());
    return true;
  }

  @override
  Future<bool> filterLogs() async {
    await _settled();
    filters++;
    final needle = searchText?.toLowerCase();
    _publish(
      needle == null || needle.isEmpty
        ? storedLogs()
        : storedLogs().where((log) => (log.question.name ?? '').toLowerCase().contains(needle)).toList(),
    );
    return true;
  }

  @override
  Future<bool> requestResetFilters() async {
    await _settled();
    _publish(storedLogs());
    return true;
  }
}

/// The live stream is a poll; the tests feed it rows instead of a timer.
class ScriptedLive extends LiveLogsProvider {
  final List<Log> _rows = [];
  bool watching = false;

  @override
  List<Log> get logs => _rows;

  @override
  void startFetchLogs() {
    watching = true;
  }

  @override
  void stopFetchLogs() {
    watching = false;
  }

  @override
  void clearLogs() {
    _rows.clear();
    notifyListeners();
  }

  void emit(List<Log> logs) {
    _rows.insertAll(0, logs);
    notifyListeners();
  }
}

/// No client is attached, so nothing may reach the network through these.
class OfflineStatus extends StatusProvider {
  @override
  Future<bool> getFilteringRules() async => true;
}

class OfflineClients extends ClientsProvider {
  @override
  Future<bool> fetchClients({bool? updateLoading}) async => true;
}

/// Presents the logs page the way the tab does, with the fixtures loaded.
Future<void> pumpLogsPage(
  WidgetTester tester, {
  required OfflineLogs logs,
  required ScriptedLive live,
  Size surface = const Size(390, 900),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final statusProvider = OfflineStatus()
    ..setServerStatusData(
      data: ServerStatus(
        stats: DnsStatistics(
          timeUnits: 'hour',
          topQueriedDomains: const [],
          topClients: const [],
          topBlockedDomains: const [],
          topUpstreamResponses: null,
          topUpstreamsAvgTime: null,
          dnsQueries: const [],
          blockedFiltering: const [],
          replacedSafebrowsing: const [],
          replacedParental: const [],
          numDnsQueries: 0,
          numBlockedFiltering: 0,
          numReplacedSafebrowsing: 0,
          numReplacedSafesearch: 0,
          numReplacedParental: 0,
          avgProcessingTime: 0.0,
        ),
        clients: const [],
        filteringStatus: FilteringStatus(
          filters: const [],
          whitelistFilters: const [],
          userRules: const [],
          interval: 0,
          enabled: true,
        ),
        timeGeneralDisabled: 0,
        generalEnabled: true,
        filteringEnabled: true,
        safeSearchEnabled: false,
        safeBrowsingEnabled: true,
        parentalControlEnabled: false,
        serverVersion: 'v0.107.0',
        safeSeachBing: false,
        safeSearchGoogle: false,
        safeSearchDuckduckgo: false,
        safeSearchEcosia: false,
        safeSearchPixabay: false,
        safeSearchYandex: false,
        safeSearchYoutube: false,
        dhcpAvailable: false,
      ),
    )
    ..setServerStatusLoad(LoadStatus.loaded);

  final clientsProvider = OfflineClients()
    ..setClientsLoadStatus(LoadStatus.loaded, false)
    ..setClientsData(
      Clients(clients: const [], autoClients: const [], supportedTags: const []),
      false,
    );

  final filteringProvider = FilteringProvider()
    ..setFilteringData(
      Filtering(
        filters: const [],
        whitelistFilters: const [],
        userRules: const [],
        blockedServices: const [],
        interval: 24,
        enabled: true,
      ),
    )
    ..setFilteringLoadStatus(LoadStatus.loaded, false);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppConfigProvider(sharedPreferencesInstance: prefs)),
        ChangeNotifierProvider<LogsProvider>.value(value: logs),
        ChangeNotifierProvider<LiveLogsProvider>.value(value: live),
        ChangeNotifierProvider<StatusProvider>.value(value: statusProvider),
        ChangeNotifierProvider.value(value: filteringProvider),
        ChangeNotifierProvider<ClientsProvider>.value(value: clientsProvider),
        ChangeNotifierProvider(create: (_) => ServersProvider()),
      ],
      child: MaterialApp(
        theme: appleLightTheme(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: LogsListWidget(
          twoColumns: false,
          selectedLog: null,
          onLogSelected: (_) {},
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}
