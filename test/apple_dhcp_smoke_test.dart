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
import 'package:adguard_home_manager/models/dhcp.dart';
import 'package:adguard_home_manager/models/dns_statistics.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/dhcp_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/settings/dhcp/dhcp.dart';
import 'package:adguard_home_manager/screens/settings/dhcp/dhcp_leases.dart';
import 'package:adguard_home_manager/screens/settings/dhcp/dhcp_not_available.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// DHCP data served to the screen without touching the API client.
class _StubDhcp extends DhcpProvider {
  _StubDhcp(this.data, {this.succeeds = true, this.blocks = false});

  final DhcpModel data;
  final bool succeeds;

  /// Keeps the screen in its loading state until the test releases it.
  final bool blocks;

  final List<Lease> deleted = [];
  final Completer<void> gate = Completer<void>();

  @override
  Future<bool> loadDhcpStatus({bool? showLoading}) async {
    await Future<void>.delayed(Duration.zero);
    if (blocks) await gate.future;
    if (!succeeds) {
      setDhcpLoadStatus(LoadStatus.error, true);
      return false;
    }
    setDhcpData(data);
    setDhcpLoadStatus(LoadStatus.loaded, true);
    return true;
  }

  @override
  Future<bool> deleteLease(Lease lease) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    deleted.add(lease);
    return true;
  }
}

NetworkInterface _iface({
  String name = 'eth0',
  List<String> ipv6 = const ['fe80::1'],
}) =>
    NetworkInterface(
      name: name,
      hardwareAddress: 'aa:bb:cc:dd:ee:ff',
      flags: const ['up', 'broadcast'],
      gatewayIp: '192.168.1.1',
      ipv4Addresses: const ['192.168.1.10'],
      ipv6Addresses: ipv6,
    );

DhcpModel _dhcp({
  String? interfaceName = 'eth0',
  List<NetworkInterface>? interfaces,
  bool withLeases = false,
}) =>
    DhcpModel(
      networkInterfaces:
          interfaces ?? [_iface(), _iface(name: 'docker0', ipv6: const [])],
      dhcpStatus: DhcpStatus(
        interfaceName: interfaceName,
        v4: IpVersion(
          gatewayIp: '192.168.1.1',
          subnetMask: '255.255.255.0',
          rangeStart: '192.168.1.50',
          rangeEnd: '192.168.1.60',
          leaseDuration: 3600,
        ),
        v6: IpVersion(
            rangeStart: 'fe80::50', rangeEnd: 'fe80::60', leaseDuration: 3600),
        leases: withLeases
            ? [
                Lease(
                    mac: 'aa:bb:cc:dd:ee:ff',
                    hostname: 'laptop',
                    ip: '192.168.1.50')
              ]
            : [],
        staticLeases: withLeases
            ? [
                Lease(
                    mac: '11:22:33:44:55:66',
                    hostname: 'printer',
                    ip: '192.168.1.90')
              ]
            : [],
        enabled: true,
      ),
    );

ServerStatus _status({bool dhcpAvailable = true}) => ServerStatus(
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
        interval: 0,
        enabled: true,
      ),
      timeGeneralDisabled: 0,
      generalEnabled: true,
      filteringEnabled: true,
      safeSearchEnabled: false,
      safeBrowsingEnabled: false,
      parentalControlEnabled: false,
      serverVersion: 'v0.107.0',
      safeSeachBing: false,
      safeSearchGoogle: false,
      safeSearchDuckduckgo: false,
      safeSearchEcosia: false,
      safeSearchPixabay: false,
      safeSearchYandex: false,
      safeSearchYoutube: false,
      dhcpAvailable: dhcpAvailable,
    );

Future<void> _pump(
  WidgetTester tester, {
  required DhcpProvider dhcp,
  bool dhcpAvailable = true,
  bool settle = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  // A tall surface keeps every field of the form inside the viewport.
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final prefs = await SharedPreferences.getInstance();
  final statusProvider = StatusProvider();
  statusProvider.setServerStatusData(
      data: _status(dhcpAvailable: dhcpAvailable));

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppConfigProvider(sharedPreferencesInstance: prefs),
        ),
        ChangeNotifierProvider(create: (_) => ServersProvider()),
        ChangeNotifierProvider(create: (_) => statusProvider),
        ChangeNotifierProvider<DhcpProvider>(create: (_) => dhcp),
      ],
      child: MaterialApp(
        navigatorKey: globalNavigatorKey,
        theme: appleLightTheme(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DhcpScreen(),
      ),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

IconButton _saveAction(WidgetTester tester) => tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(CupertinoIcons.checkmark),
        matching: find.byType(IconButton),
      ),
    );

/// The screen title, which the collapsing bar draws twice: large while
/// expanded, 17pt in the toolbar once scrolled under.
Finder _largeTitle(String text) => find.descendant(
      of: find.byType(AppleLargeTitle),
      matching: find.text(text),
    );

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the DHCP form reads as Apple sections', (tester) async {
    await _pump(tester, dhcp: _StubDhcp(_dhcp(withLeases: true)));

    expect(tester.takeException(), isNull);
    // No Material app bar, switch or outlined text field is left behind.
    expect(find.byType(SliverAppBar), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(_largeTitle(l.dhcpSettings), findsOneWidget);
    expect(find.text(l.ipv4settings.toUpperCase()), findsOneWidget);
    expect(find.text(l.ipv6settings.toUpperCase()), findsOneWidget);
    // Five IPv4 fields plus three IPv6 ones.
    expect(find.byType(TextFormField), findsNWidgets(8));
    expect(find.byType(CupertinoSwitch), findsOneWidget);
    expect(find.byType(AppleListSection), findsNWidgets(2));
    expect(find.text(l.dhcpStatic), findsOneWidget);
    // The seeded range is valid, so saving is offered right away.
    expect(_saveAction(tester).onPressed, isNotNull);
  });

  testWidgets('an invalid address blocks the save action', (tester) async {
    await _pump(tester, dhcp: _StubDhcp(_dhcp()));

    await tester.enterText(find.byType(TextFormField).first, '192.168.1.999');
    await tester.pump();

    expect(find.text(l.ipNotValid), findsOneWidget);
    expect(_saveAction(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextFormField).first, '192.168.1.70');
    await tester.pump();

    expect(find.text(l.ipNotValid), findsNothing);
    expect(_saveAction(tester).onPressed, isNotNull);
  });

  testWidgets('the ellipsis gathers the maintenance actions', (tester) async {
    await _pump(tester, dhcp: _StubDhcp(_dhcp()));

    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();

    expect(find.text(l.changeInterface), findsOneWidget);
    expect(find.text(l.restoreLeases), findsOneWidget);
    expect(find.text(l.restoreConfiguration), findsOneWidget);
    expect(find.text(l.cancel), findsOneWidget);

    await tester.tap(find.text(l.restoreLeases));
    await tester.pumpAndSettle();

    expect(find.text(l.restoreLeasesMessage), findsOneWidget);
    expect(find.text(l.confirm), findsOneWidget);

    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();

    expect(find.text(l.restoreLeasesMessage), findsNothing);
  });

  testWidgets('the destructive action is tinted red', (tester) async {
    await _pump(tester, dhcp: _StubDhcp(_dhcp()));

    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text(l.restoreConfiguration));
    expect(text.style?.color, const ApplePalette(Brightness.light).red);
  });

  testWidgets('the interface picker swaps the whole form', (tester) async {
    final dhcp = _StubDhcp(_dhcp());
    await _pump(tester, dhcp: dhcp);

    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.changeInterface));
    await tester.pumpAndSettle();

    // Both reported interfaces are offered, with their hardware address.
    expect(find.widgetWithText(AppleListTile, 'eth0'), findsOneWidget);
    expect(find.widgetWithText(AppleListTile, 'docker0'), findsOneWidget);
    expect(
      find.textContaining(l.hardwareAddress),
      findsNWidgets(2),
    );

    await tester.tap(find.widgetWithText(AppleListTile, 'docker0'));
    await tester.pumpAndSettle();

    // docker0 has no IPv6 addresses, so that group disappears.
    expect(find.text(l.ipv6settings.toUpperCase()), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(5));
    expect(find.text('docker0'), findsOneWidget);
    // The cleared range is not valid until it is filled again.
    expect(_saveAction(tester).onPressed, isNull);
  });

  testWidgets('a server without an interface asks for one', (tester) async {
    await _pump(tester, dhcp: _StubDhcp(_dhcp(interfaceName: null)));

    expect(find.text(l.neededSelectInterface), findsOneWidget);
    expect(find.byType(AppleButton), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.ellipsis), findsNothing);

    await tester.ensureVisible(find.text(l.selectInterface));
    await tester.tap(find.text(l.selectInterface));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppleListTile, 'eth0'), findsOneWidget);
  });

  testWidgets('the DHCP status loads behind an Apple spinner', (tester) async {
    final dhcp = _StubDhcp(_dhcp(), blocks: true);
    await _pump(tester, dhcp: dhcp, settle: false);

    expect(find.byType(AppleLoading), findsOneWidget);
    expect(find.text(l.loadingDhcp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    dhcp.gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(AppleLoading), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(8));
  });

  testWidgets('a failed load reports the Apple way', (tester) async {
    await _pump(tester, dhcp: _StubDhcp(_dhcp(), succeeds: false));

    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(find.text(l.dhcpSettingsNotLoaded), findsOneWidget);
    expect(find.byIcon(Icons.error), findsNothing);
  });

  testWidgets('an unsupported OS still keeps the Apple shell', (tester) async {
    await _pump(
      tester,
      dhcp: _StubDhcp(_dhcp()),
      dhcpAvailable: false,
    );

    expect(find.byType(DhcpNotAvailable), findsOneWidget);
    expect(find.byType(SliverAppBar), findsOneWidget);
    expect(find.text(l.dhcpNotAvailable), findsOneWidget);
    expect(find.text(l.osServerInstalledIncompatible), findsOneWidget);
  });

  testWidgets('static leases open their own Apple list', (tester) async {
    final dhcp = _StubDhcp(_dhcp(withLeases: true));
    await _pump(tester, dhcp: dhcp);

    await tester.ensureVisible(find.text(l.dhcpStatic));
    await tester.tap(find.text(l.dhcpStatic));
    await tester.pumpAndSettle();

    expect(find.byType(DhcpLeases), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(find.text('192.168.1.90'), findsOneWidget);
    // The lease list keeps the title it was pushed with.
    expect(_largeTitle(l.dhcpStatic), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.trash));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text(l.deleteStaticLeaseDescription), findsOneWidget);

    await tester.tap(find.text(l.confirm));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 60));
    // The blocking process alert is gone by now, so settling is safe.
    await tester.pumpAndSettle();

    expect(dhcp.deleted, hasLength(1));
    expect(dhcp.deleted.single.ip, '192.168.1.90');
    expect(find.text(l.deleteStaticLeaseDescription), findsNothing);
  });
}
