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
import 'package:adguard_home_manager/models/dns_statistics.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/settings/safe_search_settings.dart';
import 'package:adguard_home_manager/services/api_client.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'surface.dart';

// Safe search is one write of eight flags: the page collects the switches into
// a draft and the checkmark sends them all at once, so the body is the only
// thing a test can hold the page to. The client below answers it, keeps the
// bodies it was sent, and holds the flags a real server would still report.

final Server _server = Server(
  id: '1',
  name: 'Home',
  connectionMethod: 'http',
  domain: '192.168.1.10',
  port: 3000,
  defaultServer: true,
  runningOnHa: false,
);

/// What the stubbed server holds, and the shape `/status` reports it in.
class _Flags {
  bool enabled = false;
  bool bing = false;
  bool duckduckgo = false;
  bool ecosia = false;
  bool google = false;
  bool pixabay = false;
  bool yandex = false;
  bool youtube = false;

  ServerStatus toStatus() => ServerStatus(
        stats: DnsStatistics(
          timeUnits: 'hour',
          topQueriedDomains: const [],
          topClients: const [],
          topBlockedDomains: const [],
          topUpstreamResponses: null,
          topUpstreamsAvgTime: null,
          dnsQueries: const [],
          blockedFiltering: const [],
          replacedSafebrowsing: const [],
          replacedParental: const [],
          numDnsQueries: 0,
          numBlockedFiltering: 0,
          numReplacedSafebrowsing: 0,
          numReplacedSafesearch: 0,
          numReplacedParental: 0,
          avgProcessingTime: 0.0,
        ),
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
        safeSearchEnabled: enabled,
        safeBrowsingEnabled: false,
        parentalControlEnabled: false,
        serverVersion: 'v0.107.58',
        safeSeachBing: bing,
        safeSearchGoogle: google,
        safeSearchDuckduckgo: duckduckgo,
        safeSearchEcosia: ecosia,
        safeSearchPixabay: pixabay,
        safeSearchYandex: yandex,
        safeSearchYoutube: youtube,
        dhcpAvailable: false,
      );
}

class _SafeSearchApi extends ApiClientV2 {
  _SafeSearchApi(this.flags) : super(server: _server);

  /// The flags the server holds, which a taken write replaces.
  final _Flags flags;

  /// Whether `/status` answers.
  bool answers = true;

  /// Whether the safe search write is taken.
  bool acceptsWrites = true;

  /// Keeps `/status` back until the test releases the gate, so the page can be
  /// caught in its spinner.
  bool blockReads = false;

  int reads = 0;
  final List<Map<String, bool>> writes = [];
  Completer<void> gate = Completer<void>();

  @override
  Future<ApiResponse> getServerStatus() async {
    await Future<void>.delayed(Duration.zero);
    if (blockReads) await gate.future;
    reads++;
    if (!answers) return const ApiResponse(successful: false);

    return ApiResponse(successful: true, content: flags.toStatus());
  }

  @override
  Future<ApiResponse> updateSafeSearchSettings({
    required Map<String, bool> body,
  }) async {
    await Future<void>.delayed(Duration.zero);
    writes.add(Map<String, bool>.from(body));
    if (!acceptsWrites) return const ApiResponse(successful: false);

    flags
      ..enabled = body['enabled'] ?? false
      ..bing = body['bing'] ?? false
      ..duckduckgo = body['duckduckgo'] ?? false
      ..ecosia = body['ecosia'] ?? false
      ..google = body['google'] ?? false
      ..pixabay = body['pixabay'] ?? false
      ..yandex = body['yandex'] ?? false
      ..youtube = body['youtube'] ?? false;

    return const ApiResponse(successful: true);
  }
}

class _SafeSearchHarness {
  _SafeSearchHarness(this.api, this.status);

  final _SafeSearchApi api;
  final StatusProvider status;
}

Future<_SafeSearchHarness> _pumpSafeSearch(
  WidgetTester tester, {
  _Flags? flags,
  bool answers = true,

  /// Seed the provider with the answer, which is what happens when the page is
  /// opened after the overview already read `/status`.
  bool loaded = true,

  /// Keep the first read back so the page can be caught in its spinner.
  bool blocks = false,

  /// Leave the page in the state it reached instead of waiting it out.
  bool settle = true,
  Size surface = const Size(390, 1600),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  setTestSurface(tester, surface);

  final api = _SafeSearchApi(flags ?? _Flags())
    ..answers = answers
    ..blockReads = blocks;
  final servers = ServersProvider()
    ..setSelectedServer(_server)
    ..setApiClient2(api);
  final status = StatusProvider()..update(servers);

  if (loaded) {
    status.setServerStatusData(data: api.flags.toStatus());
    status.setServerStatusLoad(LoadStatus.loaded);
  }

  final appConfig = AppConfigProvider(sharedPreferencesInstance: prefs);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfigProvider>.value(value: appConfig),
        ChangeNotifierProvider<ServersProvider>.value(value: servers),
        ChangeNotifierProvider<StatusProvider>.value(value: status),
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
                  CupertinoPageRoute<void>(
                    builder: (_) => const SafeSearchSettingsScreen(),
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

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  return _SafeSearchHarness(api, status);
}

Finder _rowFinder(String title) =>
    find.widgetWithText(AppleSwitchListTile, title);

AppleSwitchListTile _row(WidgetTester tester, String title) =>
    tester.widget<AppleSwitchListTile>(_rowFinder(title));

/// The switch of one row: the design layer lets only the capsule answer, the
/// way an iOS row does.
Finder _switch(String title) => find.descendant(
      of: _rowFinder(title),
      matching: find.byType(CupertinoSwitch),
    );

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the switches are the flags /status answered', (tester) async {
    await _pumpSafeSearch(
      tester,
      flags: _Flags()
        ..enabled = true
        ..bing = true
        ..ecosia = true
        ..youtube = true,
    );

    expect(tester.takeException(), isNull);

    expect(_row(tester, l.enableSafeSearch).value, true);
    expect(_row(tester, 'Bing').value, true);
    expect(_row(tester, 'Ecosia').value, true);
    expect(_row(tester, 'YouTube').value, true);
    expect(_row(tester, 'DuckDuckGo').value, false);
    expect(_row(tester, 'Pixabay').value, false);
    expect(_row(tester, 'Yandex').value, false);

    // No Material row chrome is left on the page.
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('the engine rows wait for the general switch', (tester) async {
    final h = await _pumpSafeSearch(
      tester,
      flags: _Flags()..youtube = true,
    );

    // The server ignores the per-engine flags while the general one is down,
    // so those rows are drawn dead rather than offering a write that would
    // change nothing.
    expect(_row(tester, 'YouTube').onChanged, isNull);
    expect(_row(tester, l.enableSafeSearch).value, false);

    await tester.tap(_switch(l.enableSafeSearch));
    await tester.pump();

    expect(_row(tester, 'Bing').onChanged, isNotNull);
    expect(_row(tester, 'YouTube').value, true);
    expect(h.api.writes, isEmpty);
  });

  testWidgets('the checkmark writes the eight flags in one body',
      (tester) async {
    final h = await _pumpSafeSearch(tester);

    await tester.tap(_switch(l.enableSafeSearch));
    await tester.pump();

    await tester.tap(_switch('Bing'));
    await tester.pump();

    final ecosia = _switch('Ecosia');
    await tester.ensureVisible(ecosia);
    await tester.pumpAndSettle();
    await tester.tap(ecosia);
    await tester.pump();

    // A draft of its own is not yet something the server knows about.
    expect(h.api.writes, isEmpty);

    await tester.tap(find.byTooltip(l.save));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(h.api.writes, hasLength(1));
    expect(h.api.writes.single, {
      'enabled': true,
      'bing': true,
      'duckduckgo': false,
      'ecosia': true,
      'google': false,
      'pixabay': false,
      'yandex': false,
      'youtube': false,
    });
    expect(find.text(l.settingsUpdatedSuccessfully), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an engine the provider state drops keeps the value it wrote',
      (tester) async {
    // `updateSafeSearchConfig` echoes back every flag it was given but ecosia,
    // so a page drawing its switches from that answer would put the row back
    // where it started after a write the server took.
    final h = await _pumpSafeSearch(tester);

    await tester.tap(_switch(l.enableSafeSearch));
    await tester.pump();

    final ecosia = _switch('Ecosia');
    await tester.ensureVisible(ecosia);
    await tester.pumpAndSettle();
    await tester.tap(ecosia);
    await tester.pump();

    await tester.tap(find.byTooltip(l.save));
    await tester.pumpAndSettle();

    expect(h.api.writes.single['ecosia'], true);
    expect(h.api.flags.ecosia, true);
    expect(h.status.serverStatus?.safeSearchEcosia, false);
    expect(_row(tester, 'Ecosia').value, true);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('a refused write puts the switches back where the server left them',
      (tester) async {
    final h = await _pumpSafeSearch(
      tester,
      flags: _Flags()..enabled = true,
    );
    h.api.acceptsWrites = false;

    expect(_row(tester, l.enableSafeSearch).value, true);

    await tester.tap(_switch(l.enableSafeSearch));
    await tester.pump();
    expect(_row(tester, l.enableSafeSearch).value, false);

    await tester.tap(find.byTooltip(l.save));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(h.api.writes, hasLength(1));
    expect(find.text(l.settingsNotSaved), findsOneWidget);
    expect(_row(tester, l.enableSafeSearch).value, true);
    expect(h.api.flags.enabled, true);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the flags load behind an Apple spinner', (tester) async {
    final h = await _pumpSafeSearch(
      tester,
      flags: _Flags()
        ..enabled = true
        ..google = true,
      loaded: false,
      blocks: true,
      settle: false,
    );

    expect(find.byType(AppleLoading), findsOneWidget);
    expect(find.text(l.loadingSafeSearchSettings), findsOneWidget);
    expect(find.byType(AppleSwitchListTile), findsNothing);
    // Nothing to write yet, so the checkmark waits with the rows.
    expect(
      tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(l.save),
          matching: find.byType(IconButton),
        ),
      ).onPressed,
      isNull,
    );

    h.api
      ..blockReads = false
      ..gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(AppleLoading), findsNothing);
    expect(_row(tester, 'Google').value, true);
    expect(h.api.reads, 1);
  });

  testWidgets('a status that does not answer is said so, and retried',
      (tester) async {
    final h = await _pumpSafeSearch(tester, loaded: false, answers: false);

    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppleEmptyState),
        matching: find.text(l.safeSearchSettingsNotLoaded),
      ),
      findsOneWidget,
    );
    expect(find.byType(AppleSwitchListTile), findsNothing);

    h.api.answers = true;
    await tester.tap(find.widgetWithText(AppleButton, l.refresh));
    await tester.pumpAndSettle();

    expect(find.byType(AppleEmptyState), findsNothing);
    expect(find.byType(AppleSwitchListTile), findsNWidgets(8));
    expect(tester.takeException(), isNull);
  });
}
