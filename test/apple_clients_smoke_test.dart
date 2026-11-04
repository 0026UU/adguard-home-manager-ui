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
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/clients/added_list.dart';
import 'package:adguard_home_manager/screens/clients/client/remove_client_modal.dart';
import 'package:adguard_home_manager/screens/clients/clients_list.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

AutoClient _auto(int index) => AutoClient(
  whoisInfo: WhoisInfo(country: 'IT', orgname: 'Example'),
  name: index.isEven ? 'device-$index' : null,
  source: 'rdns',
  ip: '192.168.1.$index',
);

Client _added(int index) => Client(
  name: 'client-$index',
  blockedServices: const [],
  ids: ['10.0.0.$index', 'aa:bb:cc:dd:ee:ff'],
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

  final statusProvider = StatusProvider();
  statusProvider.setServerStatusLoad(LoadStatus.loaded);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppConfigProvider(sharedPreferencesInstance: prefs)),
        ChangeNotifierProvider.value(value: clientsProvider),
        ChangeNotifierProvider.value(value: statusProvider),
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
          title: 'Clients',
          header: AppleSegmented(
            labels: const ['Active', 'Added'],
            selectedIndex: 0,
            onChanged: (_) {},
          ),
          body: body,
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

  testWidgets('active clients render as grouped rows', (tester) async {
    AutoClient? tapped;

    await _pump(
      tester,
      ClientsList(
        data: [_auto(0), _auto(1), _auto(2)],
        onClientSelected: (client) => tapped = client,
        splitView: false,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('device-0'), findsOneWidget);
    // Rows without a name fall back to their address.
    expect(find.text('192.168.1.1'), findsWidgets);
    expect(find.text('rdns'), findsWidgets);

    await tester.tap(find.text('device-0'));
    await tester.pumpAndSettle();

    expect(tapped?.ip, '192.168.1.0');
    expect(tester.takeException(), isNull);
  });

  testWidgets('added clients render with their state icons', (tester) async {
    Client? tapped;

    await _pump(
      tester,
      AddedList(
        data: [_added(0), _added(1)],
        onClientSelected: (client) => tapped = client,
        splitView: false,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('client-0'), findsOneWidget);
    expect(find.text('10.0.0.0, aa:bb:cc:dd:ee:ff'), findsOneWidget);

    await tester.tap(find.text('client-1'));
    await tester.pumpAndSettle();

    expect(tapped?.name, 'client-1');
  });

  testWidgets('master/detail selection highlights the row', (tester) async {
    final selected = _added(0);

    await _pump(
      tester,
      AddedList(
        data: [selected, _added(1)],
        onClientSelected: (_) {},
        selectedClient: selected,
        splitView: true,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(l.seeDetails), findsNothing);
  });

  testWidgets('empty list shows the Apple empty state', (tester) async {
    await _pump(
      tester,
      ClientsList(
        data: const [],
        onClientSelected: (_) {},
        splitView: false,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(find.text(l.noClientsList), findsOneWidget);
    expect(find.text(l.refresh), findsOneWidget);
  });

  testWidgets('the list scrolls under the collapsing title', (tester) async {
    await _pump(
      tester,
      ClientsList(
        data: List.generate(20, _auto),
        onClientSelected: (_) {},
        splitView: false,
      ),
    );

    await tester.scrollUntilVisible(
      find.text('device-18'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('device-18'), findsOneWidget);
  });

  testWidgets('remove client alert confirms and dismisses', (tester) async {
    var confirmed = false;

    await _pump(
      tester,
      ClientsList(
        data: [_auto(0)],
        onClientSelected: (_) {},
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
