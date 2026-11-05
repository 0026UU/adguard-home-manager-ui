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
import 'package:adguard_home_manager/models/dns_info.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/dns_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/screens/settings/dns/dns.dart';
import 'package:adguard_home_manager/services/api_client.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

// The DNS page reads `/dns_info` and writes `/dns_config`. No test here can
// reach a server, so the API client below answers from the fixture and keeps
// every payload the taps produced, which is how the tests check that a switch
// on this page sends the same keys the screens editing the same value send.

/// The server the app is connected to.
Server serverFixture() => Server(
      id: '1',
      name: 'Home',
      connectionMethod: 'http',
      domain: '192.168.1.10',
      port: 3000,
      defaultServer: true,
      runningOnHa: false,
    );

/// What `/dns_info` answers for the box the design layer draws.
DnsInfo dnsInfoFixture({
  List<String> upstreamDns = const [
    '9.9.9.9',
    'tls://dns.example.com',
    '1.1.1.1',
  ],
  List<String> bootstrapDns = const ['9.9.9.9', '149.112.112.112'],
  List<String>? fallbackDns = const ['8.8.4.4'],
  String? upstreamMode = 'fastest_addr',
  bool ednsCsEnabled = true,
  int ratelimit = 20,
  int? cacheSize = 4194304,
  int? cacheTtlMin = 10,
  int? cacheTtlMax = 600,
}) =>
    DnsInfo(
      upstreamDns: upstreamDns,
      upstreamDnsFile: null,
      bootstrapDns: bootstrapDns,
      fallbackDns: fallbackDns,
      protectionEnabled: true,
      ratelimit: ratelimit,
      blockingMode: 'refused',
      ednsCsEnabled: ednsCsEnabled,
      ednsCsUseCustom: false,
      ednsCsCustomIp: '',
      dnssecEnabled: false,
      disableIpv6: false,
      upstreamMode: upstreamMode,
      cacheSize: cacheSize,
      cacheTtlMin: cacheTtlMin,
      cacheTtlMax: cacheTtlMax,
      cacheOptimistic: true,
      resolveClients: true,
      usePrivatePtrResolvers: true,
      localPtrUpstreams: const [],
      blockingIpv4: '',
      blockingIpv6: '',
      defaultLocalPtrUpstreams: const [],
      blockedResponseTtl: 10,
      ratelimitSubnetLenIpv4: 24,
      ratelimitSubnetLenIpv6: 56,
      ratelimitWhitelist: const [],
      upstreamTimeout: 5000,
    );

/// An API client that never opens a socket.
class DnsApiStub extends ApiClientV2 {
  DnsApiStub({required super.server, required this.info});

  /// The configuration the server holds, updated by the writes below so a read
  /// after a write answers what was written, the way a real server would.
  DnsInfo info;

  bool succeeds = true;

  /// Whether `/dns_config` accepts what the page writes.
  bool writeSucceeds = true;

  /// Keeps the first read back until the test releases the gate, so the page
  /// can be caught in its loading state.
  bool blocks = false;

  /// Holds a write open so the test can see the blocking progress dialog.
  bool blockWrites = false;

  int reads = 0;
  final List<Map<String, dynamic>> writes = [];
  final List<Map<String, dynamic>> cacheClears = [];
  final Completer<void> gate = Completer<void>();
  Completer<void> writesGate = Completer<void>();

  /// A real call answers after the frame, so the page never hears about new
  /// data while it is still building.
  Future<void> _settled() => Future<void>.delayed(Duration.zero);

  @override
  Future<ApiResponse> getDnsInfo() async {
    await _settled();
    if (blocks) await gate.future;
    reads++;
    if (!succeeds) return const ApiResponse(successful: false);
    return ApiResponse(successful: true, content: info);
  }

  @override
  Future<ApiResponse> setDnsConfig({required Map<String, dynamic> data}) async {
    await _settled();
    if (blockWrites) await writesGate.future;
    writes.add(data);
    if (!writeSucceeds) return const ApiResponse(successful: false, statusCode: 500);
    if (data['upstream_mode'] != null) info.upstreamMode = data['upstream_mode'];
    if (data['edns_cs_enabled'] != null) info.ednsCsEnabled = data['edns_cs_enabled'];
    return const ApiResponse(successful: true);
  }

  @override
  Future<ApiResponse> resetDnsCache() async {
    await _settled();
    if (blockWrites) await writesGate.future;
    cacheClears.add(const <String, dynamic>{});
    return const ApiResponse(successful: true);
  }

  @override
  Future<ApiResponse> testUpstreamDns({required Map<String, dynamic> body}) async {
    await _settled();
    return ApiResponse(
      successful: true,
      content: {for (final upstream in info.upstreamDns) upstream: 'OK'},
    );
  }
}

class DnsHarness {
  DnsHarness(this.api, this.dns, this.servers);

  final DnsApiStub api;
  final DnsProvider dns;
  final ServersProvider servers;
}

/// Pumps the DNS page the way the settings list pushes it.
///
/// The route is pushed rather than used as the home widget because the page
/// draws its own back capsule, which only appears when there is a route to go
/// back to. The surface is tall by default so every row stays tappable: a
/// [CustomScrollView] only builds what fits its viewport.
Future<DnsHarness> pumpDns(
  WidgetTester tester, {
  DnsInfo? info,
  bool succeeds = true,
  bool writeSucceeds = true,
  bool blocks = false,
  bool blockWrites = false,

  /// Hand the page the error state instead of the loaded one.
  bool fails = false,
  bool splitView = false,
  bool settle = true,
  Brightness brightness = Brightness.light,
  Size surface = const Size(390, 1400),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final server = serverFixture();
  final api = DnsApiStub(server: server, info: info ?? dnsInfoFixture())
    ..succeeds = succeeds
    ..writeSucceeds = writeSucceeds
    ..blocks = blocks
    ..blockWrites = blockWrites;

  final servers = ServersProvider()
    ..setSelectedServer(server)
    ..setApiClient2(api);
  final dns = DnsProvider()..update(servers);
  final appConfig = AppConfigProvider(sharedPreferencesInstance: prefs);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfigProvider>.value(value: appConfig),
        ChangeNotifierProvider<ServersProvider>.value(value: servers),
        ChangeNotifierProvider<DnsProvider>.value(value: dns),
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
                    builder: (_) => DnsSettings(splitView: splitView),
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
  if (fails) {
    // A read the server refused leaves the provider on its loading status, so
    // the page is still spinning. The error the page draws is handed to it
    // through the setter the provider exposes for that state.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    dns.setDnsInfoLoadStatus(LoadStatus.error, true);
    await tester.pumpAndSettle();
  } else if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  return DnsHarness(api, dns, servers);
}
