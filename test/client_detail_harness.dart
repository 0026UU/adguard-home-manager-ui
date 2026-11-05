import 'dart:async';

import 'package:flutter/cupertino.dart';
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
import 'package:adguard_home_manager/models/filtering_status.dart';
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/clients/client/client_detail.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

// The device page reads one client of `/clients` and the query counts of
// `/stats`. No test here can reach a server, so the client provider below
// answers from the fixture and records what the switches asked to be written.

/// The device the design layer opens as its pushed client page.
Client clientFixture({
  String name = 'MacBook Pro',
  List<String> ids = const ['192.168.1.12', 'a0:cc:83:12:34:56'],
  bool useGlobalSettings = false,
  bool filteringEnabled = true,
  bool safebrowsingEnabled = true,
  bool parentalEnabled = false,
  bool useGlobalBlockedServices = false,
  List<String> blockedServices = const ['netflix', 'youtube'],
  List<String> rules = const [],
}) =>
    Client(
      name: name,
      blockedServices: blockedServices,
      ids: ids,
      tags: const ['laptop'],
      upstreams: const [],
      rules: rules,
      filteringEnabled: filteringEnabled,
      parentalEnabled: parentalEnabled,
      safebrowsingEnabled: safebrowsingEnabled,
      useGlobalBlockedServices: useGlobalBlockedServices,
      useGlobalSettings: useGlobalSettings,
      safeSearch: null,
      ignoreQuerylog: false,
      ignoreStatistics: false,
      upstreamsCacheEnabled: false,
      upstreamsCacheSize: null,
      blockedServicesSchedule: null,
    );

/// The statistics window of `/status`: one device, one count.
DnsStatistics statsFixture({int queries = 18432}) => DnsStatistics(
      timeUnits: 'hour',
      topQueriedDomains: const [],
      topClients: [
        {'MacBook Pro': queries},
        {'192.168.1.7': 120},
      ],
      topBlockedDomains: const [],
      topUpstreamResponses: null,
      topUpstreamsAvgTime: null,
      dnsQueries: const [],
      blockedFiltering: const [],
      replacedSafebrowsing: const [],
      replacedParental: const [],
      numDnsQueries: queries,
      numBlockedFiltering: 0,
      numReplacedSafebrowsing: 0,
      numReplacedSafesearch: 0,
      numReplacedParental: 0,
      avgProcessingTime: 0.0,
    );

ServerStatus statusFixture({int queries = 18432}) => ServerStatus(
      stats: statsFixture(queries: queries),
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
    );

/// A clients provider that never touches the API client.
class ClientsStub extends ClientsProvider {
  ClientsStub(
    this.stored, {
    this.succeeds = true,
    this.supportsClientRules = false,
  });

  final Client stored;
  final bool succeeds;

  /// Whether the stubbed server is the forked one, which is what the page reads
  /// to decide if the rules group is drawn at all.
  final bool supportsClientRules;

  /// Every entry the page sent to be written, in the order it sent them.
  final List<Client> edited = [];
  final List<Client> deleted = [];

  /// Holds a write open so the test can see the blocking progress dialog.
  bool blockWrites = false;

  final Completer<void> writes = Completer<void>();

  /// A real call answers after the frame, so the page never hears about new
  /// data while it is still building.
  Future<void> _answered() async {
    await Future<void>.delayed(Duration.zero);
    if (blockWrites) await writes.future;
  }

  void seed() {
    setClientsData(
      Clients(
        clients: [stored],
        autoClients: const [],
        supportedTags: const [],
        supportsClientRules: supportsClientRules,
      ),
      false,
    );
    setClientsLoadStatus(LoadStatus.loaded, false);
  }

  Client get entry => clients!.clients.single;

  @override
  Future<bool> editClient(Client client) async {
    await _answered();
    if (!succeeds) return false;

    edited.add(client);
    setClientsData(
      Clients(
        clients: [client],
        autoClients: const [],
        supportedTags: const [],
        supportsClientRules: supportsClientRules,
      ),
      true,
    );

    return true;
  }

  @override
  Future<bool> deleteClient(Client client) async {
    await _answered();
    if (!succeeds) return false;

    deleted.add(client);
    setClientsData(
      Clients(
        clients: const [],
        autoClients: const [],
        supportedTags: const [],
      ),
      true,
    );

    return true;
  }
}

class ClientDetailHarness {
  ClientDetailHarness(this.clients, this.status, this.appConfig);

  final ClientsStub clients;
  final StatusProvider status;
  final AppConfigProvider appConfig;
}

/// Pumps the device page the way the clients list pushes it.
///
/// The route is pushed rather than used as the home widget because the page
/// draws its own back capsule, which only appears when there is a route to go
/// back to. The surface is tall by default so the delete button is on screen
/// too: a [CustomScrollView] only builds what fits its viewport.
Future<ClientDetailHarness> pumpClientDetail(
  WidgetTester tester, {
  Client? client,
  int? queries,
  bool succeeds = true,
  bool blockWrites = false,
  bool supportsClientRules = false,
  Brightness brightness = Brightness.light,
  Size surface = const Size(390, 1500),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final clients = ClientsStub(
    client ?? clientFixture(),
    succeeds: succeeds,
    supportsClientRules: supportsClientRules,
  )
    ..blockWrites = blockWrites
    ..seed();
  final status = StatusProvider()
    ..setServerStatusData(data: statusFixture(queries: queries ?? 18432))
    ..setServerStatusLoad(LoadStatus.loaded);
  final appConfig = AppConfigProvider(sharedPreferencesInstance: prefs);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfigProvider>.value(value: appConfig),
        ChangeNotifierProvider<ClientsProvider>.value(value: clients),
        ChangeNotifierProvider<StatusProvider>.value(value: status),
        ChangeNotifierProvider<FilteringProvider>(create: (_) => FilteringProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: globalNavigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        theme: brightness == Brightness.dark ? appleDarkTheme() : appleLightTheme(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: ApplePalette.of(context).window,
            body: Center(
              child: AppleButton(
                label: 'open',
                onPressed: () => Navigator.push(
                  context,
                  CupertinoPageRoute<void>(
                    builder: (_) => ClientDetailScreen(
                      client: clients.entry,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  return ClientDetailHarness(clients, status, appConfig);
}
