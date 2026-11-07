import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/blocked_services.dart';
import 'package:adguard_home_manager/models/dns_statistics.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/models/filtering_status.dart' hide Filter;
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/filters/filters_page.dart';

import 'surface.dart';

// The filters page is the one screen that stacks five different shapes - the
// protection card, the two list cards, the rules preview and the service grid -
// so the golden keeps their relative sizes and paddings pinned.
//
// Regenerate with: flutter test --update-goldens test/apple_filters_golden_test.dart

Filter _list(int index, {bool enabled = true, DateTime? updated}) => Filter(
  url: 'https://example.org/list-$index.txt',
  name: 'List $index',
  lastUpdated: updated,
  id: index,
  rulesCount: 100000 + index * 37,
  enabled: enabled,
);

FilteringProvider _filtering() {
  final provider = FilteringProvider();
  provider.setFilteringData(Filtering(
    filters: [
      _list(0, enabled: true, updated: DateTime.utc(2026, 10, 28)),
      _list(1, enabled: true, updated: DateTime.utc(2026, 11, 1)),
      _list(2, enabled: false),
    ],
    whitelistFilters: [_list(3, updated: DateTime.utc(2026, 10, 12))],
    userRules: const [
      '! Home rules',
      '||ads.example.org^',
      '@@allowed.example.org',
      '||tracker.example.net^\$important',
      '127.0.0.1 local.server',
      '||third.example.com^',
      '@@cdn.example.com',
      '||banner.example.org^',
      '||stats.example.io^',
      '! end',
    ],
    blockedServices: ['netflix'],
    interval: 24,
    enabled: true,
  ));
  provider.setFilteringLoadStatus(LoadStatus.loaded, false);
  provider.setBlockedServiceListData([
    BlockedService(id: 'netflix', name: 'Netflix', iconSvg: '', rules: const []),
    BlockedService(id: 'twitch', name: 'Twitch', iconSvg: '', rules: const []),
    BlockedService(id: 'crunchyroll', name: 'Crunchyroll', iconSvg: '', rules: const []),
  ]);
  provider.setBlockedServicesListLoadStatus(LoadStatus.loaded, false);
  return provider;
}

StatusProvider _status() => StatusProvider()
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
      serverVersion: 'v0.107.58',
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

void main() {
  testWidgets('the filters page stacks its five groups', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    setTestSurface(tester, const Size(390, 2300));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppConfigProvider(sharedPreferencesInstance: prefs)),
          ChangeNotifierProvider(create: (_) => _filtering()),
          ChangeNotifierProvider(create: (_) => _status()),
          ChangeNotifierProvider(create: (_) => ServersProvider()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appleLightTheme(),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            AppLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FiltersPage(actions: [], onOpenDetailsModal: _noop),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/filters_page.png'),
    );
  });
}

void _noop(Filter list, String type) {}
