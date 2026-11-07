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
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/clients/clients_lists.dart';
import 'package:adguard_home_manager/screens/clients/client/device_tile.dart';
import 'package:adguard_home_manager/screens/clients/client/remove_client_modal.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'surface.dart';

/// A statistics window holding nothing but the `top_clients` the rows look
/// themselves up in.
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

AutoClient _auto(int index) => AutoClient(
  whoisInfo: WhoisInfo(country: 'IT', orgname: 'Example'),
  name: index.isEven ? 'device-$index' : null,
  source: 'rdns',
  ip: '192.168.1.$index',
);

Client _added(int index, {List<String>? ids}) => Client(
  name: 'client-$index',
  blockedServices: const [],
  ids: ids ?? ['10.0.0.$index', 'aa:bb:cc:dd:ee:ff'],
  tags: const [],
  upstreams: const [],
  rules: const [],
  filteringEnabled: true,
  parentalEnabled: false,
  safebrowsingEnabled: true,
  useGlobalBlockedServices: true,
  useGlobalSettings: true,
  safeSearch: null,
  ignoreQuerylog: null,
  ignoreStatistics: null,
  upstreamsCacheEnabled: null,
  upstreamsCacheSize: null,
  blockedServicesSchedule: null,
);

Future<void> _pump(WidgetTester tester, Widget body) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final clientsProvider = ClientsProvider();
  clientsProvider.setClientsLoadStatus(LoadStatus.loaded, false);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppConfigProvider(sharedPreferencesInstance: prefs)),
        ChangeNotifierProvider.value(value: clientsProvider),
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
        home: AppleScreen(
          title: 'Devices',
          slivers: [SliverToBoxAdapter(child: body)],
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

/// The devices page over fixtures: it answers its own load and never reaches
/// an API client, which is what lets a test read the header where the page
/// draws it.
class _StubClientsProvider extends ClientsProvider {
  _StubClientsProvider(Clients data, {
    LoadStatus loadStatus = LoadStatus.loaded,
  }) {
    setClientsData(data, false);
    setClientsLoadStatus(loadStatus, false);
  }

  @override
  Future<bool> fetchClients({bool? updateLoading}) async => true;
}

/// A `/status` whose statistics window holds nothing but [topClients].
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

Future<void> _pumpDevices(
  WidgetTester tester, {
  required List<AutoClient> active,
  required List<Client> added,
  required List<Map<String, int>> topClients,
  LoadStatus loadStatus = LoadStatus.loaded,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  setTestSurface(tester, const Size(390, 1200));

  final clientsProvider = _StubClientsProvider(
    Clients(
      clients: added,
      autoClients: active,
      supportedTags: const [],
    ),
    loadStatus: loadStatus,
  );
  final statusProvider = StatusProvider()
    ..setServerStatusData(data: _status(topClients))
    ..setServerStatusLoad(LoadStatus.loaded);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppConfigProvider(sharedPreferencesInstance: prefs)),
        ChangeNotifierProvider<ClientsProvider>.value(value: clientsProvider),
        ChangeNotifierProvider(create: (_) => ServersProvider()),
        ChangeNotifierProvider<StatusProvider>.value(value: statusProvider),
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
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('mergeDevices', () {
    test('an added client is read as the configuration of its address', () {
      final client = _added(0, ids: ['192.168.1.4', 'aa:bb:cc:dd:ee:ff']);
      final rows = mergeDevices(
        active: [_auto(4), _auto(5)],
        added: [client],
      );

      // The address and its entry collapse into one row, so the device does
      // not appear twice in the list.
      expect(rows.length, 2);
      final paired = rows.firstWhere((row) => row.name == 'client-0');
      expect(paired.configured, isTrue);
      expect(paired.named, isTrue);
      expect(paired.logKey, '192.168.1.4');
      expect(paired.source, 'rdns');
    });

    test('entries no query came from still hold a row', () {
      final rows = mergeDevices(active: [_auto(0)], added: [_added(7)]);

      expect(rows.map((row) => row.name), ['client-7', 'device-0']);
      expect(rows.first.configured, isTrue);
      expect(rows.first.address, '10.0.0.7, aa:bb:cc:dd:ee:ff');
      expect(rows.last.configured, isFalse);
    });

    test('devices without a name are listed under their address', () {
      final rows = mergeDevices(active: [_auto(1)], added: const []);

      expect(rows.single.name, '192.168.1.1');
      expect(rows.single.address, '192.168.1.1');
      expect(rows.single.named, isFalse);
    });
  });

  testWidgets('a device row shows its address and its configuration state',
      (tester) async {
    DeviceRow? tapped;

    await _pump(
      tester,
      DeviceTile(
        row: DeviceRow(
          name: 'MacBook Pro',
          address: '192.168.1.12',
          logKey: '192.168.1.12',
          source: 'dhcp',
        ),
        onTap: (row) => tapped = row,
        splitView: false,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('MacBook Pro'), findsOneWidget);
    expect(find.text('192.168.1.12 · ${l.hasDefaultSettings}'), findsOneWidget);

    // The row says nothing about queries the server did not report.
    expect(find.text('0 queries'), findsNothing);

    await tester.tap(find.text('MacBook Pro'));
    await tester.pumpAndSettle();

    expect(tapped?.logKey, '192.168.1.12');
  });

  testWidgets('a device row counts the queries of its statistics window',
      (tester) async {
    await _pump(
      tester,
      DeviceTile(
        row: DeviceRow(
          name: 'MacBook Pro',
          address: '192.168.1.12',
          logKey: '192.168.1.12',
          source: 'dhcp',
        ),
        queries: 5120,
        onTap: (_) {},
        splitView: false,
      ),
    );

    final counted = '192.168.1.12 · ${l.hasDefaultSettings}';

    expect(find.text(counted), findsOneWidget);
    // The count belongs to the right of the row alone. Saying it again in the
    // subtitle pushed the state word under an ellipsis on a phone.
    expect(find.text(intFormat(5120, Platform.localeName)), findsOneWidget);
    expect(
      find.textContaining(
        '${intFormat(5120, Platform.localeName)} queries',
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  test('top_clients answers by name, by address or not at all', () {
    final stats = _stats([
      {'MacBook Pro': 5120},
      {'192.168.1.9': 384},
    ]);

    expect(
      queriesForDevice(stats, DeviceRow(
        name: 'MacBook Pro',
        address: '192.168.1.12',
        logKey: '192.168.1.12',
      )),
      5120,
    );
    expect(
      queriesForDevice(stats, DeviceRow(
        name: '192.168.1.9',
        address: '192.168.1.9',
        logKey: '192.168.1.9',
      )),
      384,
    );
    expect(
      queriesForDevice(stats, DeviceRow(
        name: 'Nothing here',
        address: '10.0.0.1',
        logKey: '10.0.0.1',
      )),
      isNull,
    );
    expect(
      queriesForDevice(null, DeviceRow(
        name: 'MacBook Pro',
        address: '192.168.1.12',
        logKey: '192.168.1.12',
      )),
      isNull,
    );
  });

  testWidgets('a configured device row shows the state of its entry',
      (tester) async {
    final client = _added(0);

    await _pump(
      tester,
      Column(
        children: [
          DeviceTile(
            row: DeviceRow(
              name: client.name,
              address: client.ids.join(', '),
              logKey: client.ids.first,
              client: client,
            ),
            onTap: (_) {},
            splitView: false,
          ),
          DeviceTile(
            row: DeviceRow(
              name: 'Living Room Mac',
              address: '192.168.1.9',
              logKey: '192.168.1.9',
              source: 'rdns',
            ),
            onTap: (_) {},
            splitView: false,
            showSeparator: false,
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('client-0'), findsOneWidget);
    expect(find.text('10.0.0.0, aa:bb:cc:dd:ee:ff · ${l.hasCustomSettings}'), findsOneWidget);

    // The hairline belongs between the rows only.
    expect(find.byType(AppleSeparator), findsOneWidget);
  });

  testWidgets('the segment narrows the list to one configuration state',
      (tester) async {
    final configured = _added(3, ids: ['192.168.1.4']);
    final rows = mergeDevices(
      active: [_auto(4), _auto(5)],
      added: [configured],
    );

    expect(rows.where((row) => row.configured).length, 1);
    expect(rows.where((row) => !row.configured).length, 1);

    await _pump(
      tester,
      Column(
        children: [
          for (final row in rows)
            DeviceTile(
              row: row,
              onTap: (_) {},
              splitView: false,
              showSeparator: row != rows.last,
            ),
        ],
      ),
    );

    expect(find.text('client-3'), findsOneWidget);
    expect(find.text('192.168.1.4 · ${l.hasCustomSettings}'), findsOneWidget);

    // The address of the device that has no name is its title, so the second
    // line says only what the server knows about it.
    expect(find.text(l.hasDefaultSettings), findsOneWidget);
    expect(find.text('192.168.1.5 · ${l.hasDefaultSettings}'), findsNothing);
    expect(find.textContaining('192.168.1.5'), findsOneWidget);
  });

  testWidgets('a device badge wears an initial, not a digit of its address',
      (tester) async {
    await _pump(
      tester,
      Column(
        children: [
          DeviceTile(
            row: DeviceRow(
              name: 'livingroom-mac',
              address: '192.168.1.9',
              logKey: '192.168.1.9',
              source: 'dhcp',
            ),
            onTap: (_) {},
            splitView: false,
          ),
          DeviceTile(
            row: DeviceRow(
              name: '192.168.1.5',
              address: '192.168.1.5',
              logKey: '192.168.1.5',
              source: 'rdns',
            ),
            onTap: (_) {},
            splitView: false,
            showSeparator: false,
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);

    // The name gives its own initial; the bare address gives a glyph, and no
    // digit of the address is drawn on its own anywhere.
    expect(find.text('L'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.circle_fill), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('remove client alert confirms and dismisses', (tester) async {
    var confirmed = false;

    await _pump(
      tester,
      DeviceTile(
        row: DeviceRow(
          name: 'MacBook Pro',
          address: '192.168.1.12',
          logKey: '192.168.1.12',
        ),
        onTap: (_) {},
        splitView: false,
      ),
    );

    final context = tester.element(find.byType(AppleScreen));
    showDialog<void>(
      context: context,
      builder: (_) => RemoveClientModal(onConfirm: () => confirmed = true),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppleAlertDialog), findsOneWidget);
    expect(find.text(l.removeClient), findsOneWidget);

    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(find.byType(AppleAlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('the devices header', () {
    testWidgets('counts the rows it sits over and the order it promises',
        (tester) async {
      await _pumpDevices(
        tester,
        active: [_auto(0), _auto(1), _auto(5)],
        added: [_added(9, ids: ['10.0.0.9'])],
        topClients: [
          {'device-0': 5},
        ],
      );

      // Three addresses the server has seen and one entry no query came from:
      // the header says the four the page lists, in the order the busiest
      // device first.
      expect(find.byType(DeviceTile), findsNWidgets(4));
      expect(find.text('${l.shownDevices(4, '4')} · ${l.sortedByQueries}'),
          findsOneWidget);

      // The one number that counts something else says what it counts. It may
      // not promise a day: the server answers this from its statistics window,
      // which the user sets, and the page never reads it.
      expect(find.text(l.devicesSeenInStatistics(1)), findsOneWidget);
      expect(find.textContaining('24 hours'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('promises no sorting the empty server cannot back',
        (tester) async {
      await _pumpDevices(
        tester,
        active: [_auto(0)],
        added: const [],
        topClients: [
          {'device-0': 0},
        ],
      );

      expect(find.byType(DeviceTile), findsOneWidget);
      expect(find.text(l.shownDevices(1, '1')), findsOneWidget);
      expect(find.textContaining(l.sortedByQueries), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a segment that hides every device says where the rest went',
        (tester) async {
      await _pumpDevices(
        tester,
        active: [_auto(0), _auto(1)],
        added: const [],
        topClients: const [],
      );

      await tester.tap(find.text(l.onlyCustom));
      await tester.pumpAndSettle();

      expect(find.byType(DeviceTile), findsNothing);
      expect(find.text(l.noClientsList), findsNothing);
      expect(find.text(l.noDevicesInSegment), findsOneWidget);
      expect(find.text(l.switchDeviceSegment), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a device list that did not load offers the retry',
        (tester) async {
      await _pumpDevices(
        tester,
        active: const [],
        added: const [],
        topClients: const [],
        loadStatus: LoadStatus.error,
      );

      expect(find.text(l.clientsNotLoaded), findsOneWidget);
      expect(find.widgetWithText(AppleFormButton, l.refresh), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
