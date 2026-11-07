import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/dns_statistics.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';
import 'package:adguard_home_manager/models/server_status.dart';
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
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'overview_harness.dart';
import 'surface.dart';

// The user's complaint was ellipsized headline numbers ("查询总数 5....") and a
// legend that traded the two series totals for one compact figure. These tests
// pump the numbers from the real report — 54783 queries, 27429 blocked,
// 1143226 active rules — and hold the page to exact figures that are fully
// painted: every string is present and its render box fits the tile it sits
// in, on a phone width and on a narrow one.
//
// Run with: flutter test test/apple_overview_exact_numbers_test.dart

/// Answers the status call with numbers the fixtures do not carry.
class _ExactStatus extends StatusProvider {
  _ExactStatus(this._status);

  final ServerStatus _status;

  @override
  Future<bool> getServerStatus({
    bool? withLoadingIndicator = true,
    bool? overrideCheckServerVersion,
  }) async {
    // The page asks from initState, so the answer lands after the first frame.
    await Future.delayed(Duration.zero);
    setServerStatusData(data: _status);
    setServerStatusLoad(LoadStatus.loaded);
    return true;
  }
}

ServerStatus _exactStatus() => ServerStatus(
  stats: DnsStatistics(
    timeUnits: 'hours',
    topQueriedDomains: const [],
    topClients: const [],
    topBlockedDomains: const [],
    topUpstreamResponses: null,
    topUpstreamsAvgTime: null,
    dnsQueries: hourlyQueries,
    blockedFiltering: hourlyBlocked,
    replacedSafebrowsing: const [],
    replacedParental: const [],
    numDnsQueries: 54783,
    numBlockedFiltering: 27429,
    numReplacedSafebrowsing: 0,
    numReplacedSafesearch: 0,
    numReplacedParental: 0,
    avgProcessingTime: 0.0246,
  ),
  clients: const [],
  // 1143225 rules in one enabled list plus one user rule: the exact figure
  // the report named, seven digits wide.
  filteringStatus: FilteringStatus(
    filters: [filterFixture(1, 'Huge list', 1143225, true)],
    whitelistFilters: const [],
    userRules: const ['||ads.example.org^'],
    interval: 24,
    enabled: true,
  ),
  timeGeneralDisabled: 0,
  generalEnabled: true,
  filteringEnabled: true,
  safeSearchEnabled: false,
  safeBrowsingEnabled: false,
  parentalControlEnabled: false,
  serverVersion: 'v1.0.0-b.2',
  safeSeachBing: false,
  safeSearchGoogle: false,
  safeSearchDuckduckgo: false,
  safeSearchEcosia: false,
  safeSearchPixabay: false,
  safeSearchYandex: false,
  safeSearchYoutube: false,
  dhcpAvailable: false,
);

Future<void> _pumpExact(WidgetTester tester, Size surface) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  setTestSurface(tester, surface);

  final api = OverviewApi();
  final servers = ServersProvider()
    ..setSelectedServer(overviewServer)
    ..setApiClient2(api);
  final status = _ExactStatus(_exactStatus())..update(servers);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfigProvider>.value(
          value: AppConfigProvider(sharedPreferencesInstance: prefs),
        ),
        ChangeNotifierProvider<ServersProvider>.value(value: servers),
        ChangeNotifierProvider<StatusProvider>.value(value: status),
        ChangeNotifierProvider<ClientsProvider>.value(value: OverviewClients()),
        ChangeNotifierProvider<LogsProvider>.value(value: OverviewLogs()),
        ChangeNotifierProvider(create: (_) => FilteringProvider()),
        ChangeNotifierProvider(create: (_) => DhcpProvider()),
        ChangeNotifierProvider(create: (_) => RewriteRulesProvider()),
        ChangeNotifierProvider(create: (_) => DnsProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: scaffoldMessengerKey,
        navigatorKey: globalNavigatorKey,
        theme: appleLightTheme(),
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
}

/// The painted text fits the tile it lives in: `getRect` walks through the
/// ancestor transforms, so a value the tile had to scale down is measured at
/// the size it is actually drawn, not at its natural width.
void _expectFitsItsTile(WidgetTester tester, String text) {
  final finder = find.text(text);
  expect(finder, findsOneWidget, reason: '$text is not on the page');

  final painted = tester.getRect(finder);
  final tile = tester.getRect(
    find.ancestor(of: finder, matching: find.byType(GestureDetector)).first,
  );

  expect(painted.width, greaterThan(0));
  expect(painted.left, greaterThanOrEqualTo(tile.left));
  expect(painted.right, lessThanOrEqualTo(tile.right));
  expect(painted.top, greaterThanOrEqualTo(tile.top));
  expect(painted.bottom, lessThanOrEqualTo(tile.bottom));
}

void main() {
  late AppLocalizations l;
  late String locale;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
    locale = Platform.localeName;
  });

  group('overview exact numbers', () {
    testWidgets('the tiles tell every digit on a phone width', (tester) async {
      await _pumpExact(tester, const Size(390, 2100));
      expect(tester.takeException(), isNull);

      final queries = intFormat(54783, locale);
      final blocked = intFormat(27429, locale);
      final rules = intFormat(1143226, locale);

      // The full grouped figures, not a compact "5.48万" and not an ellipsis.
      expect(find.text(queries), findsOneWidget);
      expect(find.text(blocked), findsOneWidget);
      expect(find.text(rules), findsOneWidget);

      _expectFitsItsTile(tester, queries);
      _expectFitsItsTile(tester, blocked);
      _expectFitsItsTile(tester, rules);
    });

    testWidgets('the tiles still tell every digit on a narrow phone',
        (tester) async {
      await _pumpExact(tester, const Size(320, 2100));
      expect(tester.takeException(), isNull);

      final queries = intFormat(54783, locale);
      final blocked = intFormat(27429, locale);
      final rules = intFormat(1143226, locale);

      _expectFitsItsTile(tester, queries);
      _expectFitsItsTile(tester, blocked);
      _expectFitsItsTile(tester, rules);
    });

    testWidgets('the legend keeps one exact total per series', (tester) async {
      await _pumpExact(tester, const Size(390, 2100));
      expect(tester.takeException(), isNull);

      // The day window the page opens on, counted out of the fixture buckets.
      final queriesTotal = hourlyQueries.fold<int>(0, (a, b) => a + b);
      final blockedTotal = hourlyBlocked.fold<int>(0, (a, b) => a + b);

      // Label and count are one rich text, so the finder reads rich texts too.
      final queriesLegend = find.textContaining(
        '${l.queries} ${intFormat(queriesTotal, locale)}',
        findRichText: true,
      );
      final blockedLegend = find.textContaining(
        '${l.blocked} ${intFormat(blockedTotal, locale)}',
        findRichText: true,
      );
      expect(queriesLegend, findsOneWidget);
      expect(blockedLegend, findsOneWidget);

      // Nothing is clipped: each painted legend fits the card it sits in.
      final card = tester.getRect(find.byType(AppleTrendChart));
      for (final finder in [queriesLegend, blockedLegend]) {
        final painted = tester.getRect(finder);
        expect(painted.left, greaterThanOrEqualTo(card.left - 40));
        expect(painted.right, lessThanOrEqualTo(card.right + 40));
      }
    });

    testWidgets('the protection card carries no buttons', (tester) async {
      await _pumpExact(tester, const Size(390, 2100));
      expect(tester.takeException(), isNull);

      final hero = find.byType(AppleHero);
      expect(hero, findsOneWidget);
      expect(
        find.descendant(of: hero, matching: find.byType(AppleButton)),
        findsNothing,
      );
      expect(find.text(l.manageProtection), findsNothing);
      expect(find.text(l.viewLogs), findsNothing);

      // The card still says what it is there to say.
      expect(find.textContaining(l.protectingDevices(23, intFormat(23, locale))),
          findsOneWidget);
      expect(
        find.textContaining(l.blockedOfQueries(
          intFormat(27429, locale),
          intFormat(54783, locale),
        )),
        findsOneWidget,
      );
    });
  });
}
