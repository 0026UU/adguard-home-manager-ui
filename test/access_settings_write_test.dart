import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/models/clients_allowed_blocked.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/screens/settings/access_settings/access_settings.dart';
import 'package:adguard_home_manager/services/api_client.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'surface.dart';

// Access control is the one place the app writes `/access/set`, a call that
// replaces all three lists at once. The page cannot be trusted to send what it
// showed, so the client below keeps the lists a real server would answer with
// and records every body the taps produced.

final Server _server = Server(
  id: '1',
  name: 'Home',
  connectionMethod: 'http',
  domain: '192.168.1.10',
  port: 3000,
  defaultServer: true,
  runningOnHa: false,
);

class _AccessApi extends ApiClientV2 {
  _AccessApi() : super(server: _server);

  ClientsAllowedBlocked lists = ClientsAllowedBlocked(
    allowedClients: ['192.168.1.50', 'a0:cc:83:12:34:56'],
    disallowedClients: ['203.0.113.7'],
    blockedHosts: ['ads.example.com'],
  );

  /// Whether `/clients` and `/access/list` answer at all.
  bool answers = true;

  /// Whether `/access/set` takes the body.
  bool acceptsWrites = true;

  /// The reason a refused write reports, the way a 400 on the other list does.
  String refusal = 'client_another_list';

  final List<Map<String, List<String>?>> writes = [];

  Future<void> _settled() => Future<void>.delayed(Duration.zero);

  @override
  Future<ApiResponse> getClients() async {
    await _settled();
    if (!answers) return const ApiResponse(successful: false);

    return ApiResponse(
      successful: true,
      content: Clients(
        clients: const [],
        autoClients: const [],
        supportedTags: const [],
        clientsAllowedBlocked: ClientsAllowedBlocked(
          allowedClients: [...lists.allowedClients],
          disallowedClients: [...lists.disallowedClients],
          blockedHosts: [...lists.blockedHosts],
        ),
      ),
    );
  }

  @override
  Future<ApiResponse> requestAllowedBlockedClientsHosts({
    required Map<String, List<String>?> body,
  }) async {
    await _settled();
    writes.add(Map<String, List<String>?>.from(body));

    if (!acceptsWrites) {
      return ApiResponse(successful: false, content: refusal, statusCode: 400);
    }

    lists = ClientsAllowedBlocked(
      allowedClients: [...body['allowed_clients'] ?? const <String>[]],
      disallowedClients: [...body['disallowed_clients'] ?? const <String>[]],
      blockedHosts: [...body['blocked_hosts'] ?? const <String>[]],
    );

    return const ApiResponse(successful: true);
  }
}

class _AccessHarness {
  _AccessHarness(this.api, this.clients);

  final _AccessApi api;
  final ClientsProvider clients;
}

Future<_AccessHarness> _pumpAccess(
  WidgetTester tester, {
  Size surface = const Size(390, 1400),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  setTestSurface(tester, surface);

  final api = _AccessApi();
  final servers = ServersProvider()
    ..setSelectedServer(_server)
    ..setApiClient2(api);
  final clients = ClientsProvider()..update(servers, null);
  final appConfig = AppConfigProvider(sharedPreferencesInstance: prefs);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfigProvider>.value(value: appConfig),
        ChangeNotifierProvider<ServersProvider>.value(value: servers),
        ChangeNotifierProvider<ClientsProvider>.value(value: clients),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: globalNavigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
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
            backgroundColor: ApplePalette.of(context).window,
            body: Center(
              child: AppleButton(
                label: 'open',
                onPressed: () => Navigator.push(
                  context,
                  CupertinoPageRoute<void>(builder: (_) => const AccessSettings()),
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

  return _AccessHarness(api, clients);
}

/// The label of the segment that is not the one already drawn as a title.
Finder segment(AppLocalizations l, String label) => find.descendant(
      of: find.byType(AppleSegmented),
      matching: find.text(label),
    );

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the segments draw the three lists /access answers with',
      (tester) async {
    await _pumpAccess(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(TabBarView), findsNothing);

    expect(find.widgetWithText(AppleListTile, '192.168.1.50'), findsOneWidget);
    expect(find.widgetWithText(AppleListTile, '203.0.113.7'), findsNothing);

    await tester.tap(segment(l, l.disallowedClients));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppleListTile, '203.0.113.7'), findsOneWidget);
    expect(find.widgetWithText(AppleListTile, '192.168.1.50'), findsNothing);

    await tester.tap(segment(l, l.disallowedDomains));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppleListTile, 'ads.example.com'), findsOneWidget);

    // The server keeps no entries for that list, so the page says so rather
    // than drawing an empty card.
    await tester.tap(segment(l, l.allowedClients));
    await tester.pumpAndSettle();
    expect(find.text(l.allowedClientsDescription), findsOneWidget);
  });

  testWidgets('adding an entry sends the whole access body', (tester) async {
    final h = await _pumpAccess(tester);

    await tester.tap(find.widgetWithText(AppleHeaderAction, l.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '10.0.0.8');
    await tester.pump();

    await tester.tap(find.text(l.confirm));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(h.api.writes, hasLength(1));

    // `/access/set` replaces all three lists, so an add that sent only the one
    // it touched would silently drop the other two.
    final body = h.api.writes.single;
    expect(body['allowed_clients'], ['192.168.1.50', 'a0:cc:83:12:34:56', '10.0.0.8']);
    expect(body['disallowed_clients'], ['203.0.113.7']);
    expect(body['blocked_hosts'], ['ads.example.com']);

    expect(find.widgetWithText(AppleListTile, '10.0.0.8'), findsOneWidget);
    expect(find.text(l.clientAddedSuccessfully), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a blocked host added on its own segment reaches blocked_hosts',
      (tester) async {
    final h = await _pumpAccess(tester);

    await tester.tap(segment(l, l.disallowedDomains));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppleHeaderAction, l.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'tracker.example.net');
    await tester.pump();
    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();

    expect(h.api.writes.single['blocked_hosts'],
        ['ads.example.com', 'tracker.example.net']);
    expect(h.api.writes.single['allowed_clients'],
        ['192.168.1.50', 'a0:cc:83:12:34:56']);
    expect(find.text(l.clientAddedSuccessfully), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('a removal confirms before it writes', (tester) async {
    final h = await _pumpAccess(tester);

    await tester.tap(find.byTooltip(l.removeClient).first);
    await tester.pumpAndSettle();

    expect(find.byType(AppleAlertDialog), findsOneWidget);
    expect(find.text(l.removeClientMessage), findsOneWidget);
    expect(h.api.writes, isEmpty);

    await tester.tap(find.text(l.confirm));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(h.api.writes.single['allowed_clients'], ['a0:cc:83:12:34:56']);
    expect(find.widgetWithText(AppleListTile, '192.168.1.50'), findsNothing);
    expect(find.text(l.clientRemovedSuccessfully), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('cancelling the confirmation writes nothing', (tester) async {
    final h = await _pumpAccess(tester);

    await tester.tap(find.byTooltip(l.removeClient).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();

    expect(h.api.writes, isEmpty);
    expect(find.widgetWithText(AppleListTile, '192.168.1.50'), findsOneWidget);
  });

  testWidgets('an entry the server keeps on another list stays on screen',
      (tester) async {
    final h = await _pumpAccess(tester);
    h.api.acceptsWrites = false;

    await tester.tap(find.byTooltip(l.removeClient).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();

    expect(h.api.writes, hasLength(1));
    // The refusal is about the other list, not about the connection, so the
    // page has to say which and leave the row where it is.
    expect(find.text(l.clientAnotherList), findsOneWidget);
    expect(find.widgetWithText(AppleListTile, '192.168.1.50'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('a write that fails outright is reported as a failed write',
      (tester) async {
    final h = await _pumpAccess(tester);
    h.api.acceptsWrites = false;
    h.api.refusal = 'server_error';

    await tester.tap(find.widgetWithText(AppleHeaderAction, l.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '10.0.0.8');
    await tester.pump();
    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();

    expect(find.text(l.clientNotAdded), findsOneWidget);
    // The page asked, the server said no, and the lists it holds are still the
    // ones it answered with. What the page shows afterwards is the provider's
    // own state, which `addClientList` appends to before it asks.
    expect(h.api.lists.allowedClients, isNot(contains('10.0.0.8')));

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('a page that could not read the lists offers the retry',
      (tester) async {
    final h = await _pumpAccess(tester);
    h.api.answers = false;

    await tester.tap(find.byIcon(CupertinoIcons.arrow_clockwise));
    await tester.pumpAndSettle();

    expect(find.byType(AppleEmptyState), findsOneWidget);
    // The retry pill reports the same words the card does, so the assertion is
    // about the card.
    expect(
      find.descendant(
        of: find.byType(AppleEmptyState),
        matching: find.text(l.clientsNotLoaded),
      ),
      findsOneWidget,
    );
    expect(find.byType(AppleListSection), findsNothing);

    h.api.answers = true;
    await tester.tap(find.widgetWithText(AppleButton, l.refresh));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppleListTile, '192.168.1.50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
