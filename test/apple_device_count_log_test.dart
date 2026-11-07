import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/models/dns_statistics.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/clients/client/client_detail.dart';
import 'package:adguard_home_manager/screens/clients/client/device_tile.dart';
import 'package:adguard_home_manager/screens/clients/clients_lists.dart';
import 'package:adguard_home_manager/screens/logs/filters/logs_filters_modal.dart';
import 'package:adguard_home_manager/screens/logs/logs.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'logs_harness.dart';
import 'surface.dart';

// The count on a device row is a second way in: it has to open the query log
// already narrowed to that device's client id, for a device with custom
// settings exactly as for one without, and the narrowing has to be what the
// Logs screen's own filter sheet shows and can clear.

/// Query-log double that narrows rows by the applied client filter the way
/// the real provider does — by the address the query came from or by the
/// name the client is known under.
class ClientFilteredLogs extends LogsProvider {
  ClientFilteredLogs(this.rows);

  final List<Log> rows;

  /// A real call answers after the frame, so the page never hears about new
  /// data while it is still building.
  Future<void> _settled() => Future<void>.delayed(Duration.zero);

  @override
  Future<bool> fetchLogs({
    int? inOffset,
    bool? loadingMore,
    String? searchText,
  }) async {
    await _settled();
    final clients = appliedFilters.clients;
    setLogsData(LogsData(
      data: clients.isEmpty
        ? rows
        : rows
            .where((log) => clients.contains(log.client)
                || clients.contains(log.clientInfo?.name))
            .toList(),
    ));
    setLoadStatus(LoadStatus.loaded);
    return true;
  }
}

/// The Logs screen asks for the filter lists when it opens; nothing here may
/// reach a server.
class OfflineFiltering extends FilteringProvider {
  @override
  Future<bool> fetchFilters({bool? showLoading}) async => true;
}

class StubClients extends ClientsProvider {
  StubClients(Clients data) {
    setClientsData(data, false);
    setClientsLoadStatus(LoadStatus.loaded, false);
  }

  @override
  Future<bool> fetchClients({bool? updateLoading}) async => true;
}

DnsStatistics _stats(List<Map<String, int>> topClients) =>
    DnsStatistics.fromJson({
      'time_units': 'hour',
      'top_queried_domains': <Map<String, int>>[],
      'top_clients': topClients,
      'top_blocked_domains': <Map<String, int>>[],
      'dns_queries': <int>[0],
      'blocked_filtering': <int>[0],
      'replaced_safebrowsing': <int>[0],
      'replaced_parental': <int>[0],
      'num_dns_queries': 0,
      'num_blocked_filtering': 0,
      'num_replaced_safebrowsing': 0,
      'num_replaced_safesearch': 0,
      'num_replaced_parental': 0,
      'avg_processing_time': 0,
    });

ServerStatus _status(List<Map<String, int>> topClients) => ServerStatus(
  stats: _stats(topClients),
  clients: const [],
  filteringStatus: FilteringStatus(
    filters: const [],
    whitelistFilters: const [],
    userRules: const [],
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

Client _customClient() => Client(
  name: 'MacBook Pro',
  blockedServices: const [],
  ids: const ['192.168.1.24'],
  tags: const [],
  upstreams: const [],
  rules: const [],
  filteringEnabled: true,
  parentalEnabled: false,
  safebrowsingEnabled: false,
  useGlobalBlockedServices: true,
  // The report this test pins: a client with its own settings used to send
  // every tap of the row to the edit form, the count included.
  useGlobalSettings: false,
  safeSearch: null,
  ignoreQuerylog: null,
  ignoreStatistics: null,
  upstreamsCacheEnabled: null,
  upstreamsCacheSize: null,
  blockedServicesSchedule: null,
);

Client _macClient() => Client(
  name: 'Studio Mac',
  blockedServices: const [],
  // Configured by hardware address alone: no id here is ever written into a
  // query-log row, so the log can only be reached through the client's name.
  ids: const ['de:ad:be:ef:00:31'],
  tags: const [],
  upstreams: const [],
  rules: const [],
  filteringEnabled: true,
  parentalEnabled: false,
  safebrowsingEnabled: false,
  useGlobalBlockedServices: true,
  useGlobalSettings: false,
  safeSearch: null,
  ignoreQuerylog: null,
  ignoreStatistics: null,
  upstreamsCacheEnabled: null,
  upstreamsCacheSize: null,
  blockedServicesSchedule: null,
);

Future<ClientFilteredLogs> _pumpDevices(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  setTestSurface(tester, const Size(390, 1200));

  final logs = ClientFilteredLogs([
    logFixture('ads.example.org',
        client: '192.168.1.24', clientName: 'MacBook Pro'),
    logFixture('tracker.example.net',
        client: '192.168.1.24', clientName: 'MacBook Pro'),
    logFixture('news.example.org', client: '192.168.1.20'),
    logFixture('studio.example.org',
        client: '192.168.1.31', clientName: 'Studio Mac'),
  ]);

  final clientsProvider = StubClients(
    Clients(
      clients: [_customClient(), _macClient()],
      autoClients: [
        AutoClient(
          whoisInfo: WhoisInfo(country: 'IT', orgname: 'Example'),
          name: 'macbook-pro',
          source: 'dhcp',
          ip: '192.168.1.24',
        ),
        AutoClient(
          whoisInfo: WhoisInfo(country: 'IT', orgname: 'Example'),
          name: null,
          source: 'rdns',
          ip: '192.168.1.20',
        ),
      ],
      supportedTags: const [],
    ),
  );

  final statusProvider = OfflineStatus()
    ..setServerStatusData(data: _status([
      {'MacBook Pro': 1234},
      {'Studio Mac': 77},
    ]))
    ..setServerStatusLoad(LoadStatus.loaded);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppConfigProvider(sharedPreferencesInstance: prefs)),
        ChangeNotifierProvider<ClientsProvider>.value(value: clientsProvider),
        ChangeNotifierProvider(create: (_) => ServersProvider()),
        ChangeNotifierProvider<StatusProvider>.value(value: statusProvider),
        ChangeNotifierProvider<LogsProvider>.value(value: logs),
        ChangeNotifierProvider<FilteringProvider>(create: (_) => OfflineFiltering()),
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
        home: const ClientsLists(splitView: false),
      ),
    ),
  );

  await tester.pumpAndSettle();
  return logs;
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the count of a custom-settings device opens its own log',
      (tester) async {
    final logs = await _pumpDevices(tester);

    // The row of the configured device shows the exact grouped count.
    expect(find.text('192.168.1.24 · ${l.hasCustomSettings}'), findsOneWidget);
    final count = intFormat(1234, Platform.localeName);
    expect(find.text(count), findsOneWidget);

    // The count is a labelled button of its own for assistive tech, at least
    // 44pt tall to hit on a phone.
    final semantics = find.byWidgetPredicate(
      (widget) => widget is Semantics
          && widget.properties.label == l.viewDeviceLog('MacBook Pro'),
    );
    expect(semantics, findsOneWidget);
    expect(tester.getSize(semantics).height, greaterThanOrEqualTo(44));

    await tester.tap(find.text(count));
    await tester.pumpAndSettle();

    expect(find.byType(Logs), findsOneWidget);
    // The narrowing keys on the label the log rows carry for this client, not
    // on an address: rows of a configured client name it in `client_info`.
    expect(logs.appliedFilters.clients, ['MacBook Pro']);

    // Only this device's entries; the row of the other address is gone.
    expect(find.text('ads.example.org'), findsOneWidget);
    expect(find.text('tracker.example.net'), findsOneWidget);
    expect(find.text('news.example.org'), findsNothing);

    // The pre-filter is an ordinary applied client filter: it gets the chip
    // under the title, and the sheet shows the same selection.
    expect(find.byType(AppleFilterChip), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.slider_horizontal_3));
    await tester.pumpAndSettle();

    expect(find.byType(LogsFiltersModal), findsOneWidget);
    final tile = find.widgetWithText(AppleSwitchListTile, 'macbook-pro');
    expect(tile, findsOneWidget);
    expect(
      tester.widget<CupertinoSwitch>(
        find.descendant(of: tile, matching: find.byType(CupertinoSwitch)),
      ).value,
      isTrue,
    );

    // And the sheet is where it can be cleared.
    await tester.tap(find.text('macbook-pro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.apply));
    await tester.pumpAndSettle();

    expect(logs.appliedFilters.clients, isEmpty);
    expect(find.text('news.example.org'), findsOneWidget);
    expect(find.byType(AppleFilterChip), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the row tap of a custom-settings device still opens the device',
      (tester) async {
    await _pumpDevices(tester);

    await tester.tap(find.text('MacBook Pro'));
    await tester.pumpAndSettle();

    expect(find.byType(Logs), findsNothing);
    expect(find.byType(ClientDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a device the server has no stats for shows no count to tap',
      (tester) async {
    final logs = await _pumpDevices(tester);

    Finder logButton(String device) => find.byWidgetPredicate(
      (widget) => widget is Semantics
          && widget.properties.label == l.viewDeviceLog(device),
    );

    // The second address has no entry in top_clients: no count, so no dead
    // tap target on its row either — the counts on screen belong to the two
    // configured devices alone.
    expect(find.byType(DeviceTile), findsNWidgets(3));
    expect(find.text(intFormat(1234, Platform.localeName)), findsOneWidget);
    expect(logButton('MacBook Pro'), findsOneWidget);
    expect(logButton('Studio Mac'), findsOneWidget);
    expect(logButton('192.168.1.20'), findsNothing);
    expect(logs.appliedFilters.clients, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a device configured by hardware address opens its own log',
      (tester) async {
    final logs = await _pumpDevices(tester);

    // The row of a client the server knows only by MAC: its title is the
    // configured label and its second line the address list, none of which a
    // query-log row ever repeats.
    expect(find.text('Studio Mac'), findsOneWidget);
    expect(find.text('de:ad:be:ef:00:31 · ${l.hasCustomSettings}'), findsOneWidget);

    await tester.tap(find.text(intFormat(77, Platform.localeName)));
    await tester.pumpAndSettle();

    expect(find.byType(Logs), findsOneWidget);
    expect(logs.appliedFilters.clients, ['Studio Mac']);

    // The rows name the client in `client_info`, which is what the narrowing
    // matches; the other devices' rows are gone.
    expect(find.text('studio.example.org'), findsOneWidget);
    expect(find.text('ads.example.org'), findsNothing);
    expect(find.text('news.example.org'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
