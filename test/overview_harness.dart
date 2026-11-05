import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/models/dns_statistics.dart';
import 'package:adguard_home_manager/models/encryption.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';
import 'package:adguard_home_manager/models/rewrite_rules.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/models/statistics_config.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/dhcp_provider.dart';
import 'package:adguard_home_manager/providers/dns_provider.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';
import 'package:adguard_home_manager/providers/rewrite_rules_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/home/home.dart';
import 'package:adguard_home_manager/services/api_client.dart';

// The overview asks the server for four things: the status, the statistics of
// one window, whether DoT is on and how many rewrites exist. No test can reach
// a server, so [OverviewApi] answers those from the fixtures below and records
// what was asked, which is how the tests tell a real per-window request from a
// rescaled answer.

final Server overviewServer = Server(
  id: 'server-1',
  name: 'Home Router',
  connectionMethod: 'http',
  domain: '192.168.1.10',
  port: 3000,
  defaultServer: true,
  runningOnHa: false,
);

/// 26 hourly buckets. Bucket 1 is the same hour of yesterday as the newest one,
/// which is what the "vs yesterday" caption compares: 1168 -> 1240.
const List<int> hourlyQueries = [
  800, 1168, 120, 95, 340, 980, 1240, 1610, 1880, 1420,
  300, 150, 110, 260, 720, 900, 1150, 1400, 1650, 1200,
  210, 120, 95, 340, 980, 1240,
];

const List<int> hourlyBlocked = [
  300, 402, 31, 28, 96, 310, 392, 505, 610, 447,
  180, 90, 40, 120, 300, 380, 470, 560, 640, 480,
  62, 31, 28, 96, 310, 392,
];

DnsStatistics statsOf({
  required String timeUnits,
  required List<int> queries,
  required List<int> blocked,
  bool withTops = false,
}) {
  int sum(List<int> values) => values.fold<int>(0, (a, b) => a + b);

  return DnsStatistics(
    timeUnits: timeUnits,
    topQueriedDomains: withTops
      ? const [
          {'api.telegram.org': 2418},
          {'dns.google': 1902},
          {'gateway.icloud.com': 1287},
        ]
      : const [],
    topClients: withTops
      ? const [
          {'iPhone 15 Pro': 5120},
          {'MacBook Pro': 3844},
        ]
      : const [],
    topBlockedDomains: withTops
      ? const [
          {'ads.doubleclick.net': 1842},
          {'graph.facebook.com': 1310},
          {'pagead2.googlesyndication.com': 1155},
          {'analytics.google.com': 988},
          {'device-metrics-us.amazon.com': 731},
          {'smetrics.adobe.com': 504},
        ]
      : const [],
    topUpstreamResponses: null,
    topUpstreamsAvgTime: null,
    dnsQueries: queries,
    blockedFiltering: blocked,
    replacedSafebrowsing: [for (final v in blocked) (v / 4).round()],
    replacedParental: [for (final v in blocked) (v / 8).round()],
    numDnsQueries: sum(queries),
    numBlockedFiltering: sum(blocked),
    numReplacedSafebrowsing: 214,
    numReplacedSafesearch: 51,
    numReplacedParental: 88,
    avgProcessingTime: 0.0246,
  );
}

/// The statistics of one lookback window, the way the server would answer
/// `GET /stats?recent=`: hourly buckets for a day, daily ones beyond that.
DnsStatistics trendFor(int recentMs) {
  if (recentMs == 604800000) {
    return statsOf(
      timeUnits: 'days',
      queries: const [14200, 15100, 16800, 21400, 19800, 15600, 12300],
      blocked: const [4100, 4520, 5010, 6900, 6300, 4600, 3200],
    );
  }

  if (recentMs == 2592000000) {
    return statsOf(
      timeUnits: 'days',
      queries: const [
        11800, 13200, 14500, 16800, 15100, 19400, 22100, 17600, 18400, 16100,
        12800, 13900, 15400, 17100, 18800, 14200, 15900, 17400, 19100, 20400,
        16700, 15200, 14800, 17900, 19600, 21400, 18100, 17300, 18432, 19600,
      ],
      blocked: const [
        3200, 3700, 4100, 5000, 4400, 6100, 7300, 5200, 5400, 4700,
        3600, 3900, 4300, 4800, 5200, 4000, 4400, 4800, 5300, 5600,
        4600, 4200, 4100, 4900, 5400, 5900, 5000, 4800, 5100, 5921,
      ],
    );
  }

  return statsOf(
    timeUnits: 'hours',
    queries: hourlyQueries,
    blocked: hourlyBlocked,
  );
}

Filter filterFixture(int id, String name, int rules, bool enabled) => Filter(
  url: 'https://example.org/$name.txt',
  name: name,
  id: id,
  rulesCount: rules,
  enabled: enabled,
  lastUpdated: DateTime.utc(2026, 11, 1),
);

/// The filtering status of the design layer's server: 312547 rules in force.
FilteringStatus filteringFixture() => FilteringStatus(
  filters: [
    filterFixture(1, 'AdGuard DNS filter', 150000, true),
    filterFixture(2, 'AdAway Default Blocklist', 162546, true),
    filterFixture(3, 'Disabled list', 999999, false),
  ],
  whitelistFilters: const [],
  userRules: const ['||ads.example.org^'],
  interval: 24,
  enabled: true,
);

ServerStatus statusFixture({bool protectionOn = true}) => ServerStatus(
  stats: statsOf(
    timeUnits: 'hours',
    queries: hourlyQueries,
    blocked: hourlyBlocked,
    withTops: true,
  ),
  clients: const [],
  filteringStatus: filteringFixture(),
  timeGeneralDisabled: 0,
  generalEnabled: protectionOn,
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
  dhcpAvailable: true,
);

EncryptionData encryptionFixture() => EncryptionData(
  validCert: true,
  validChain: true,
  dnsNames: const ['dns.example.org'],
  validKey: true,
  validPair: true,
  enabled: true,
  serverName: 'dns.example.org',
  forceHttps: false,
  portDnscrypt: 8443,
  dnscryptConfigFile: '',
  allowUnencryptedDoh: false,
  certificateChain: '',
  privateKey: '',
  certificatePath: '',
  privateKeyPath: '',
  privateKeySaved: false,
  servePlainDns: null,
);

List<RewriteRules> rewritesFixture() => [
  RewriteRules(domain: 'example.org', answer: '192.168.1.50', enabled: true),
  RewriteRules(domain: 'home.example.org', answer: '192.168.1.51', enabled: true),
];

class OverviewApi extends ApiClientV2 {
  OverviewApi() : super(server: overviewServer);

  /// The `recent` values of every statistics call, in the order they arrived.
  final List<int> trendRequests = [];

  /// The last protection change the page asked for.
  bool? lastProtectionEnable;
  int? lastProtectionTime;

  /// How long the server keeps statistics; a month, as the design layer's one.
  int statisticsIntervalMs = 30 * 24 * 60 * 60 * 1000;

  /// The retention the page asked the server for, in the order it arrived.
  final List<int> retentionUpdates = [];

  @override
  Future<ApiResponse> getStatistics({int? recentMs}) async {
    trendRequests.add(recentMs ?? 0);
    return ApiResponse(
      successful: true,
      content: trendFor(recentMs ?? 0),
    );
  }

  @override
  Future<ApiResponse> getStatisticsConfig() async => ApiResponse(
    successful: true,
    content: StatisticsConfig(
      ignored: const [],
      interval: statisticsIntervalMs,
      enabled: true,
    ),
  );

  @override
  Future<ApiResponse> updateStatisticsSettings({
    required Map<String, dynamic> body,
  }) async {
    final interval = body['interval'] as int;
    retentionUpdates.add(interval);
    statisticsIntervalMs = interval;
    return const ApiResponse(successful: true);
  }

  @override
  Future<ApiResponse> getEncryptionSettings() async => ApiResponse(
    successful: true,
    content: encryptionFixture(),
  );

  @override
  Future<ApiResponse> getDnsRewriteRules() async => ApiResponse(
    successful: true,
    content: rewritesFixture(),
  );

  @override
  Future<ApiResponse> updateGeneralProtection({
    required bool enable,
    int? time,
  }) async {
    lastProtectionEnable = enable;
    lastProtectionTime = time;
    return const ApiResponse(successful: true);
  }

  @override
  Future<ApiResponse> getServerInfo() async => const ApiResponse(successful: false);
}

/// Answers the status call from the fixture instead of the network.
class OverviewStatus extends StatusProvider {
  OverviewStatus({this.protectionOn = true});

  final bool protectionOn;

  @override
  Future<bool> getServerStatus({
    bool? withLoadingIndicator = true,
    bool? overrideCheckServerVersion,
  }) async {
    // The page asks for the status from initState, so a fixture that notifies
    // right away would notify while the first frame is still being built.
    await Future.delayed(Duration.zero);
    setServerStatusData(data: statusFixture(protectionOn: protectionOn));
    setServerStatusLoad(LoadStatus.loaded);
    return true;
  }
}

class OverviewClients extends ClientsProvider {
  @override
  Future<bool> fetchClients({bool? updateLoading}) async {
    await Future.delayed(Duration.zero);
    setClientsData(
      Clients(
        clients: const [],
        autoClients: [
          for (var i = 0; i < 23; i++)
            AutoClient(
              whoisInfo: WhoisInfo(),
              ip: '192.168.1.${20 + i}',
              source: 'rdns',
            ),
        ],
        supportedTags: const [],
      ),
      false,
    );
    setClientsLoadStatus(LoadStatus.loaded, true);
    return true;
  }
}

/// The log page owns the filtering, so only the state change matters here.
class OverviewLogs extends LogsProvider {
  @override
  Future<bool> filterLogs() async => true;
}

class OverviewHarness {
  final AppConfigProvider appConfig;
  final ServersProvider servers;
  final OverviewStatus status;
  final OverviewClients clients;
  final OverviewLogs logs;
  final OverviewApi api;

  const OverviewHarness({
    required this.appConfig,
    required this.servers,
    required this.status,
    required this.clients,
    required this.logs,
    required this.api,
  });
}

/// Pumps the overview the way the tab does.
///
/// The surface is tall on purpose: a [CustomScrollView] only builds what fits,
/// so a phone-sized viewport would leave the trend and the ranking out of the
/// widget tree and untappable.
Future<OverviewHarness> pumpOverview(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Size surface = const Size(390, 2100),
  bool protectionOn = true,
  int statisticsIntervalMs = 30 * 24 * 60 * 60 * 1000,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final api = OverviewApi()..statisticsIntervalMs = statisticsIntervalMs;
  final servers = ServersProvider()
    ..setSelectedServer(overviewServer)
    ..setApiClient2(api);
  final status = OverviewStatus(protectionOn: protectionOn)..update(servers);
  final clients = OverviewClients();
  final logs = OverviewLogs();
  final appConfig = AppConfigProvider(sharedPreferencesInstance: prefs);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfigProvider>.value(value: appConfig),
        ChangeNotifierProvider<ServersProvider>.value(value: servers),
        ChangeNotifierProvider<StatusProvider>.value(value: status),
        ChangeNotifierProvider<ClientsProvider>.value(value: clients),
        ChangeNotifierProvider<LogsProvider>.value(value: logs),
        ChangeNotifierProvider(create: (_) => FilteringProvider()),
        ChangeNotifierProvider(create: (_) => DhcpProvider()),
        ChangeNotifierProvider(create: (_) => RewriteRulesProvider()),
        ChangeNotifierProvider(create: (_) => DnsProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        // The same keys the real shell passes, so the app-level helpers that
        // announce results reach an overlay here exactly as they do in the app.
        scaffoldMessengerKey: scaffoldMessengerKey,
        navigatorKey: globalNavigatorKey,
        theme: brightness == Brightness.dark ? appleDarkTheme() : appleLightTheme(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Home(),
      ),
    ),
  );

  await tester.pumpAndSettle();

  return OverviewHarness(
    appConfig: appConfig,
    servers: servers,
    status: status,
    clients: clients,
    logs: logs,
    api: api,
  );
}
