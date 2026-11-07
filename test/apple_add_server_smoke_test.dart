import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/functions/auth_error_message.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/services/auth.dart';
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

  /// The servers the connection flow asked to be written.
  final List<Server> written = [];

  @override
  Future<bool> removeServer(Server server) async {
    removed.add(server);
    return true;
  }

  @override
  Future<dynamic> createServer(Server server) async {
    written.add(server);
    return null;
  }

  @override
  Future<dynamic> editServer(Server server) async {
    written.add(server);
    return null;
  }
}

/// A server that takes the login and answers nothing after it, so a
/// connection can only fail halfway through.
class _StatuslessHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

/// A host that answers nothing at all — the case that used to hand the wait
/// back to the operating system's own retry budget.
class _HangingHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _HangingHttpClient();
}

class _HangingHttpClient implements HttpClient {
  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> postUrl(Uri url) =>
      Completer<HttpClientRequest>().future;

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClient implements HttpClient {
  // The login path sets a connect timeout on the real client; an `implements`
  // fake sends that setter to noSuchMethod, which throws, and the whole
  // exchange would be reported as an unknown failure instead of reaching the
  // status call the test is about.
  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> postUrl(Uri url) async =>
      _FakeRequest(_FakeResponse(200));

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _FakeRequest(_FakeResponse(500));

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this._response);

  final _FakeResponse _response;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  void add(List<int> data) {}

  @override
  void write(Object? object) {}

  @override
  Future<HttpClientResponse> close() async => _response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// No header the app writes here is ever read back.
class _FakeHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(this.statusCode);

  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(utf8.encode('{}')).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
        debugShowCheckedModeBanner: false,
        // The Apple toast is anchored to the root navigator, which is also
        // how the connection results reach the user.
        navigatorKey: globalNavigatorKey,
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

  testWidgets('a login that outlives its status call says what failed',
      (tester) async {
    final servers = await _openForm(tester);
    await _tapOpen(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Lab box');
    await tester.enterText(find.byType(TextFormField).at(1), '192.168.1.10');
    await tester.pumpAndSettle();

    // The socket is only faked for the zone of the tap, so the app still
    // talks to the half-dead server and nothing else in the test can reach
    // the network.
    await HttpOverrides.runWithHttpOverrides(
      () async {
        await tester.tap(find.text(l.connect));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text(l.errorLoadServerStatus), findsOneWidget);
        // Nothing half-configured was written, and the sheet stays where the
        // user can read the answer and retry with usable fields.
        expect(servers.written, isEmpty);
        expect(find.byType(AddServerModal), findsOneWidget);
        expect(_confirmEnabled(tester, l.connect), isTrue);
        expect(
          tester
              .widgetList<AppleTextField>(find.byType(AppleTextField))
              .every((field) => field.enabled),
          isTrue,
        );

        await tester.pump(const Duration(milliseconds: 1700));
        await tester.pumpAndSettle();
      },
      _StatuslessHttpOverrides(),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('an edit whose status call fails keeps the stored connection',
      (tester) async {
    final servers = await _openForm(tester, server: _server());
    await _tapOpen(tester);

    await HttpOverrides.runWithHttpOverrides(
      () async {
        await tester.tap(find.text(l.save));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text(l.errorLoadServerStatus), findsOneWidget);
        expect(servers.written, isEmpty);
        expect(find.byType(AddServerModal), findsOneWidget);
        expect(_confirmEnabled(tester, l.save), isTrue);

        await tester.pump(const Duration(milliseconds: 1700));
        await tester.pumpAndSettle();
      },
      _StatuslessHttpOverrides(),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a host that answers nothing is given up on, not waited for',
      (tester) async {
    final servers = await _openForm(tester);
    await _tapOpen(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Lab box');
    await tester.enterText(find.byType(TextFormField).at(1), '192.168.1.10');
    await tester.pumpAndSettle();

    await HttpOverrides.runWithHttpOverrides(
      () async {
        await tester.tap(find.text(l.connect));
        await tester.pump();

        // The deadline is the app's, not the socket's: nothing is reported
        // while the user could still be waiting, and it is reported as soon as
        // the app stops waiting rather than after the OS gives up.
        await tester.pump(const Duration(seconds: 9));
        expect(find.text(l.cantReachServer), findsNothing);

        await tester.pump(const Duration(seconds: 2));
        expect(find.text(l.cantReachServer), findsOneWidget);
        expect(servers.written, isEmpty);
        expect(find.byType(AddServerModal), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 1700));
        await tester.pumpAndSettle();
      },
      _HangingHttpOverrides(),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('every way a login can fail has its own sentence',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox();
        },
      ),
    ));

    String message(AuthStatus status) => authErrorMessage(ctx, status);

    // Four different problems, four different answers. The two ways a host can
    // be unreachable share one because the user fixes them the same way; the
    // server tile used to give all of them the same sentence, which sent a
    // user with a typo in the password off to check the network.
    expect(
      {
        for (final status in AuthStatus.values)
          if (status != AuthStatus.success) message(status),
      }.length,
      6,
    );
    expect(message(AuthStatus.invalidCredentials),
        isNot(message(AuthStatus.socketException)));
    expect(message(AuthStatus.handshakeException),
        isNot(message(AuthStatus.timeoutException)));
    expect(message(AuthStatus.socketException),
        message(AuthStatus.timeoutException));
  });
}
