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
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/models/server_info.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/screens/settings/server_info/server_info.dart';
import 'package:adguard_home_manager/services/api_client.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

// The page asks the server only one question: `/status`. No test here can reach
// a server, so the API client below answers that question from the fixture and
// counts the times the page asked it.

/// The server the app is connected to, as the settings list would have picked it.
Server serverFixture() => Server(
      id: '1',
      name: 'Home',
      connectionMethod: 'http',
      domain: '192.168.1.10',
      port: 3000,
      defaultServer: true,
      runningOnHa: false,
    );

/// What `/status` answers for the box the design layer draws.
///
/// [arch], [goos] and [startTime] are the three answers only the forked server
/// gives, so a test that leaves them out is a test of the stock one.
ServerInfoData serverInfoFixture({
  String version = 'v0.107.53',
  List<String> dnsAddresses = const ['192.168.1.10', '10.8.0.1'],
  int dnsPort = 53,
  int httpPort = 3000,
  bool protectionEnabled = true,
  bool dhcpAvailable = false,
  bool running = true,
  String language = 'en',
  String? arch,
  String? goos,
  DateTime? startTime,
}) =>
    ServerInfoData(
      version: version,
      dnsAddresses: dnsAddresses,
      dnsPort: dnsPort,
      httpPort: httpPort,
      protectionEnabled: protectionEnabled,
      dhcpAvailable: dhcpAvailable,
      running: running,
      language: language,
      arch: arch,
      goos: goos,
      startTime: startTime,
    );

/// An API client that never opens a socket.
class ServerInfoApiStub extends ApiClientV2 {
  ServerInfoApiStub({required super.server, required this.data});

  final ServerInfoData data;

  bool succeeds = true;

  /// Keeps the answer back until the test releases the gate, so the page can
  /// be caught in its loading state.
  bool blocks = false;

  int calls = 0;

  final Completer<void> gate = Completer<void>();

  /// A real call answers after the frame, so the page never hears about new
  /// data while it is still building.
  Future<void> _settled() => Future<void>.delayed(Duration.zero);

  @override
  Future<ApiResponse> getServerInfo() async {
    await _settled();
    if (blocks) await gate.future;
    calls++;
    if (!succeeds) return const ApiResponse(successful: false);
    return ApiResponse(successful: true, content: data);
  }
}

class ServerInfoHarness {
  ServerInfoHarness(this.api, this.servers);

  final ServerInfoApiStub api;
  final ServersProvider servers;
}

/// Pumps the server information page the way the settings list pushes it.
///
/// The route is pushed rather than used as the home widget because the page
/// draws its own back capsule, which only appears when there is a route to go
/// back to. The surface is tall by default so every row stays tappable.
Future<ServerInfoHarness> pumpServerInfo(
  WidgetTester tester, {
  ServerInfoData? data,
  bool succeeds = true,
  bool blocks = false,
  bool settle = true,
  Brightness brightness = Brightness.light,
  Size surface = const Size(390, 1400),
  int registeredClients = 3,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final server = serverFixture();
  final api = ServerInfoApiStub(server: server, data: data ?? serverInfoFixture())
    ..succeeds = succeeds
    ..blocks = blocks;

  final servers = ServersProvider()
    ..setSelectedServer(server)
    ..setApiClient2(api);
  final appConfig = AppConfigProvider(sharedPreferencesInstance: prefs);

  // The page reads the count of registered devices from the clients list,
  // which the app has already loaded by the time the settings are reachable.
  final clients = ClientsProvider()
    ..setClientsData(
      Clients(
        clients: [
          for (var index = 0; index < registeredClients; index++)
            Client(
              name: 'device-$index',
              ids: ['192.0.2.$index'],
              tags: const [],
              upstreams: const [],
              rules: const [],
              blockedServices: const [],
              useGlobalSettings: true,
              filteringEnabled: false,
              parentalEnabled: false,
              safebrowsingEnabled: false,
              useGlobalBlockedServices: true,
              safeSearch: null,
              ignoreQuerylog: false,
              ignoreStatistics: false,
              upstreamsCacheEnabled: false,
              upstreamsCacheSize: null,
              blockedServicesSchedule: null,
            ),
        ],
        autoClients: const [],
        supportedTags: const [],
      ),
      false,
    )
    ..setClientsLoadStatus(LoadStatus.loaded, false);
  addTearDown(clients.dispose);

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
                    builder: (_) => const ServerInformation(),
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
  // A gated load keeps its spinner turning, so settling would never finish.
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  return ServerInfoHarness(api, servers);
}
