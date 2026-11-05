import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/widgets/add_server/add_server_functions.dart';
import 'package:adguard_home_manager/widgets/add_server/add_server_modal.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/servers_list/server_tile_functions.dart';

Server _server({
  String id = '1',
  String name = 'Home box',
  String domain = 'adguard.example.com',
}) =>
    Server(
      id: id,
      name: name,
      connectionMethod: 'https',
      domain: domain,
      port: 3000,
      defaultServer: false,
      runningOnHa: false,
    );

/// Records the deletions instead of touching the database.
class _StubServers extends ServersProvider {
  final List<Server> removed = [];

  @override
  Future<bool> removeServer(Server server) async {
    removed.add(server);
    return true;
  }
}

Future<_StubServers> _pump(WidgetTester tester, Widget home) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final serversProvider = _StubServers();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ServersProvider>.value(value: serversProvider),
        ChangeNotifierProvider(create: (_) => StatusProvider()),
        ChangeNotifierProvider(
          create: (_) => AppConfigProvider(sharedPreferencesInstance: prefs),
        ),
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
        home: home,
      ),
    ),
  );

  await tester.pumpAndSettle();
  return serversProvider;
}

/// A home screen whose only button opens the connection form.
Future<_StubServers> _openForm(
  WidgetTester tester, {
  Server? server,
  double width = 1000,
}) {
  return _pump(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => openServerFormModal(
              context: context,
              width: width,
              server: server,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _tapOpen(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

TextFormField _field(WidgetTester tester, int index) => tester
    .widgetList<TextFormField>(find.byType(TextFormField))
    .elementAt(index);

/// The footer confirm is disabled by leaving it without an action.
bool _confirmEnabled(WidgetTester tester, String label) =>
    tester
        .widget<InkWell>(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(InkWell),
              )
              .first,
        )
        .onTap !=
    null;

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the create form shows its groups and an empty preview',
      (tester) async {
    await _openForm(tester);
    await _tapOpen(tester);

    expect(find.byType(AddServerModal), findsOneWidget);
    expect(find.text(l.createConnection), findsOneWidget);
    for (final group in [l.general, l.connection, l.authentication, l.other]) {
      expect(find.text(group), findsOneWidget);
    }
    // Name, address, path, port, username, password.
    expect(find.byType(TextFormField), findsNWidgets(6));
    expect(find.text('http://'), findsOneWidget);
    expect(find.text(l.redirectHttpsWarning), findsOneWidget);
    expect(find.text(l.sslWarning), findsNothing);
    expect(_confirmEnabled(tester, l.connect), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the preview follows the scheme, the address and the port',
      (tester) async {
    await _openForm(tester);
    await _tapOpen(tester);

    await tester.enterText(find.byType(TextFormField).at(1), '192.168.1.10');
    await tester.pumpAndSettle();

    expect(find.text('http://192.168.1.10'), findsOneWidget);

    // The form is taller than the card, so scroll to the control first.
    await tester.ensureVisible(find.text('HTTPS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HTTPS'));
    await tester.pumpAndSettle();

    expect(find.text('https://192.168.1.10'), findsOneWidget);
    // The self signed certificate note belongs to HTTPS only.
    expect(find.text(l.sslWarning), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(3), '8080');
    await tester.pumpAndSettle();

    expect(find.text('https://192.168.1.10:8080'), findsOneWidget);

    await tester.ensureVisible(find.text('HTTP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HTTP'));
    await tester.pumpAndSettle();

    expect(find.text('http://192.168.1.10:8080'), findsOneWidget);
    expect(find.text(l.sslWarning), findsNothing);
    expect(_field(tester, 3).controller!.text, '8080');
  });

  testWidgets('an invalid address or port keeps the connect button disabled',
      (tester) async {
    await _openForm(tester);
    await _tapOpen(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Lab box');
    await tester.enterText(find.byType(TextFormField).at(1), 'not a domain');
    await tester.pumpAndSettle();

    expect(find.text(l.invalidIpDomain), findsOneWidget);
    expect(_confirmEnabled(tester, l.connect), isFalse);

    await tester.enterText(find.byType(TextFormField).at(1), '192.168.1.10');
    await tester.enterText(find.byType(TextFormField).at(3), '99999');
    await tester.pumpAndSettle();

    expect(find.text(l.invalidPort), findsOneWidget);
    expect(_confirmEnabled(tester, l.connect), isFalse);

    await tester.enterText(find.byType(TextFormField).at(3), '8080');
    await tester.pumpAndSettle();

    expect(_confirmEnabled(tester, l.connect), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing a connection prefills it and locks the switches',
      (tester) async {
    await _openForm(tester, server: _server());
    await _tapOpen(tester);

    expect(find.text(l.editConnection), findsOneWidget);
    expect(_field(tester, 0).controller!.text, 'Home box');
    expect(_field(tester, 1).controller!.text, 'adguard.example.com');
    expect(_confirmEnabled(tester, l.save), isTrue);

    final switches = tester
        .widgetList<AppleSwitchListTile>(find.byType(AppleSwitchListTile))
        .toList();
    expect(switches, hasLength(2));
    // Both stay read only while editing.
    for (final row in switches) {
      expect(row.onChanged, isNull);
    }
  });

  testWidgets('a new connection leaves the switches usable', (tester) async {
    await _openForm(tester);
    await _tapOpen(tester);

    final before = tester
        .widgetList<AppleSwitchListTile>(find.byType(AppleSwitchListTile))
        .toList();
    expect(before.every((row) => row.onChanged != null), isTrue);

    await tester.ensureVisible(find.byType(CupertinoSwitch).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CupertinoSwitch).last);
    await tester.pumpAndSettle();

    final after = tester
        .widgetList<CupertinoSwitch>(find.byType(CupertinoSwitch))
        .toList();
    expect(after.last.value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow screen gets the same form as a sheet', (tester) async {
    await _openForm(tester, width: 500);
    await _tapOpen(tester);

    expect(find.byType(AddServerModal), findsOneWidget);
    expect(find.byType(AppleFormModal), findsOneWidget);
    expect(find.text(l.createConnection), findsOneWidget);
    expect(find.text(l.connect), findsOneWidget);
    // A fullscreen scaffold would leave the app bar behind.
    expect(find.byType(AppBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the delete alert only removes on the destructive action',
      (tester) async {
    final server = _server();
    final servers = await _pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  showDeleteModal(context: context, server: server),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await _tapOpen(tester);

    expect(find.text(l.remove), findsNWidgets(2));
    expect(find.text('${l.removeWarning}\n\nhttps://adguard.example.com:3000'),
        findsOneWidget);

    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();

    expect(servers.removed, isEmpty);

    await _tapOpen(tester);
    // The second "Remove" is the destructive row, the first is the title.
    await tester.tap(find.text(l.remove).last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(servers.removed, [server]);
    expect(find.byType(AppleAlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
