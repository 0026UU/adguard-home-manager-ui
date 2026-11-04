import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/servers_list/servers_list.dart';
import 'package:adguard_home_manager/widgets/servers_list/servers_tile_item.dart';

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

Future<ServersProvider> _pump(
  WidgetTester tester, {
  List<Server> servers = const [],
  Server? selected,
}) async {
  SharedPreferences.setMockInitialValues({});

  final serversProvider = ServersProvider();
  for (final server in servers) {
    serversProvider.addServer(server);
  }
  if (selected != null) serversProvider.setSelectedServer(selected);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: serversProvider),
        ChangeNotifierProvider(create: (_) => StatusProvider()),
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
        home: Builder(
          builder: (context) => Scaffold(
            body: ServersList(
              context: context,
              controllers: const [],
              onChange: (_) {},
              scrollController: ScrollController(),
              breakingWidth: 1000,
            ),
          ),
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

  testWidgets('the selected default server shows its state instead of connect',
      (tester) async {
    final server = _server(defaultServer: true);

    await _pump(tester, servers: [server], selected: server);

    expect(find.byIcon(CupertinoIcons.star_fill), findsOneWidget);
    expect(find.text(l.connect), findsNothing);
    // Selected but with no status loaded yet.
    expect(find.text(l.selectedDisconnected), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();

    // The default row is already the default, so it only states that.
    expect(find.text(l.defaultConnection), findsOneWidget);
    expect(find.text(l.setDefault), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no saved servers reads as an empty state', (tester) async {
    await _pump(tester);

    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(find.text(l.noSavedConnections), findsOneWidget);
    expect(find.byType(ServersTileItem), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
