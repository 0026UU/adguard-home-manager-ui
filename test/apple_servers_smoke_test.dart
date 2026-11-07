import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/dns_statistics.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/add_server/add_server_modal.dart';
import 'package:adguard_home_manager/widgets/servers_list/servers_list.dart';
import 'package:adguard_home_manager/widgets/servers_list/servers_tile_item.dart';

import 'surface.dart';

Server _server({
  String id = '1',
  String name = 'Home box',
  bool defaultServer = false,
}) =>
    Server(
      id: id,
      name: name,
      connectionMethod: 'https',
      domain: 'adguard.example.com',
      path: '/api',
      port: 3000,
      defaultServer: defaultServer,
      runningOnHa: false,
    );

const String _address = 'https://adguard.example.com/api:3000';

/// A status as it arrives from a server the app has just reached. The tile
/// reads it to tell "selected and answering" from "selected and quiet".
ServerStatus _status() => ServerStatus(
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

Future<ServersProvider> _pump(
  WidgetTester tester, {
  List<Server> servers = const [],
  Server? selected,
  bool connected = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final serversProvider = ServersProvider();
  for (final server in servers) {
    serversProvider.addServer(server);
  }
  if (selected != null) serversProvider.setSelectedServer(selected);

  final statusProvider = StatusProvider();
  if (connected) {
    statusProvider.setServerStatusData(data: _status());
    statusProvider.setServerStatusLoad(LoadStatus.loaded);
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: serversProvider),
        ChangeNotifierProvider.value(value: statusProvider),
        // The empty state's button opens the connection form, which reads the
        // app config like every other screen does.
        ChangeNotifierProvider(
            create: (_) => AppConfigProvider(sharedPreferencesInstance: prefs)),
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
        // The list is only ever handed to [AppleScreen] as its own scrolling
        // body, so the harness builds it that way too: a bare Scaffold would
        // hide the fact that the body has to give the pinned bar's overlap
        // back before its first card.
        home: const AppleScreen(
          title: 'Servers',
          body: ServersList(breakingWidth: 1000),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  return serversProvider;
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('a saved server is a card with its address and a connect action',
      (tester) async {
    await _pump(tester, servers: [_server()]);

    expect(find.byType(ServersTileItem), findsOneWidget);
    expect(find.text(_address), findsOneWidget);
    expect(find.text('Home box'), findsOneWidget);
    expect(find.text(l.connect), findsOneWidget);
    // Only the default connection carries the star.
    expect(find.byIcon(CupertinoIcons.star_fill), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the card menu offers the same three actions as before',
      (tester) async {
    await _pump(tester, servers: [_server()]);

    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();

    expect(find.text(l.setDefault), findsOneWidget);
    expect(find.text(l.edit), findsOneWidget);
    // Delete sits on its own card, above cancel.
    expect(find.text(l.delete), findsOneWidget);

    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();

    expect(find.text(l.edit), findsNothing);
    expect(find.byType(ServersTileItem), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a selected server that answers shows its state, not a connect button',
      (tester) async {
    final server = _server(defaultServer: true);

    await _pump(tester, servers: [server], selected: server, connected: true);

    expect(find.byIcon(CupertinoIcons.star_fill), findsOneWidget);
    expect(find.text(l.connect), findsNothing);
    expect(find.text(l.connected), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a selected server that has gone quiet still offers the way back',
      (tester) async {
    final server = _server(defaultServer: true);

    await _pump(tester, servers: [server], selected: server);

    // Selected but with no status loaded yet. Reporting the quietness was the
    // whole message before, which left the one card that says "disconnected"
    // with no way to reach the server again.
    expect(find.text(l.selectedDisconnected), findsOneWidget);
    expect(find.text(l.connect), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();

    // The default row is already the default, so it only states that.
    expect(find.text(l.defaultConnection), findsOneWidget);
    expect(find.text(l.setDefault), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the cards clear the title bar, collapsed or not',
      (tester) async {
    setTestSurface(tester, const Size(390, 844));
    await _pump(tester, servers: [
      _server(id: '1'),
      _server(id: '2', name: 'Cabin'),
      _server(id: '3', name: 'Office'),
      _server(id: '4', name: 'Lab'),
    ]);

    void expectClearOfTheBar(String where) {
      final bar = tester.getRect(find.byType(AppleLargeTitle));
      final card = tester.getRect(find.byType(ServersTileItem).first);
      // Without the overlap injector the body starts at the top of the window
      // and the bar paints over it: the first card lost its address line to the
      // expanded bar and the whole card to the collapsed one.
      expect(card.top, greaterThanOrEqualTo(bar.bottom - 0.01), reason: where);
    }

    expectClearOfTheBar('at rest');
    await tester.drag(find.byType(ServersList), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(AppleLargeTitle)).height, lessThan(152),
        reason: 'the drag should have collapsed the title');
    expectClearOfTheBar('once the title has collapsed');
    expect(tester.takeException(), isNull);
  });

  testWidgets('no saved servers reads as an empty state', (tester) async {
    await _pump(tester);

    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(find.text(l.noSavedConnections), findsOneWidget);
    expect(find.byType(ServersTileItem), findsNothing);
    // A new user used to get the words "No saved connections" and an
    // unlabelled floating button, with nothing joining the two.
    expect(find.text(l.noSavedConnectionsHint), findsOneWidget);
    expect(find.widgetWithText(AppleButton, l.createConnection), findsOneWidget);

    await tester.tap(find.widgetWithText(AppleButton, l.createConnection));
    await tester.pumpAndSettle();
    expect(find.byType(AddServerModal), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
