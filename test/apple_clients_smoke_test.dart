import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/screens/clients/client/device_tile.dart';
import 'package:adguard_home_manager/screens/clients/client/remove_client_modal.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

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
    expect(find.text('dhcp'), findsOneWidget);

    await tester.tap(find.text('MacBook Pro'));
    await tester.pumpAndSettle();

    expect(tapped?.logKey, '192.168.1.12');
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
            onEdit: (_) {},
            onDelete: (_) {},
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
    expect(find.byType(ClientStatusIcons), findsOneWidget);

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
    expect(find.text('192.168.1.5 · ${l.hasDefaultSettings}'), findsOneWidget);
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
}
