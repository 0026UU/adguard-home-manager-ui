import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/screens/settings/server_info/dns_addresses_modal.dart';
import 'package:adguard_home_manager/screens/settings/server_info/server_info.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/custom_list_tile.dart';

import 'server_info_harness.dart';

// Server information is a definition list, not a dashboard: the page answers
// what the box reports about itself and nothing else. The tests below check the
// header line, the values `/status` really carries, the three rows only the
// forked server can answer, the sheet the address row opens, and that the
// Material chrome the page used to be built from is gone.

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the values are one Apple group under the page title', (tester) async {
    final h = await pumpServerInfo(tester);

    expect(tester.takeException(), isNull);
    // The page asked `/status` exactly once while opening.
    expect(h.api.calls, 1);
    expect(find.byType(ServerInformation), findsOneWidget);

    // The collapsing title carries the page name and the address of the server.
    expect(
      find.descendant(
        of: find.byType(AppleLargeTitle),
        matching: find.text(l.serverInformation),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppleLargeTitle),
        matching: find.text('192.168.1.10'),
      ),
      findsOneWidget,
    );

    // A pushed route draws the back capsule of the design layer.
    expect(find.byType(AppleBackButton), findsOneWidget);

    // One card of value rows, then the group holding the address row.
    expect(find.byType(AppleListSection), findsNWidgets(2));
    expect(find.text(l.dnsAddresses), findsOneWidget);
    expect(find.widgetWithText(AppleListTile, l.serverVersion), findsOneWidget);
    expect(find.widgetWithText(AppleListTile, l.seeDnsAddresses), findsOneWidget);

    // No Material chrome is left on the page itself.
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(CustomListTile), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Card), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // The only bar on screen belongs to the design layer; no Scaffold of the
    // page carries a Material `appBar` of its own.
    for (final scaffold in tester.widgetList<Scaffold>(find.byType(Scaffold))) {
      expect(scaffold.appBar, isNull);
    }
  });

  testWidgets('every value comes from the server', (tester) async {
    await pumpServerInfo(tester);

    String valueOf(String title) =>
        tester.widget<AppleListTile>(find.widgetWithText(AppleListTile, title)).value!;

    expect(valueOf(l.serverVersion), 'v0.107.53');
    expect(valueOf(l.httpPort), '3000');
    expect(valueOf(l.dnsPort), '53');
    expect(valueOf(l.protectionEnabled), l.yes);
    expect(valueOf(l.dhcpAvailable), l.no);
    expect(valueOf(l.serverRunning), l.yes);
    expect(valueOf(l.serverLanguage), 'en');

    // The address row lists both addresses the server published.
    expect(
      tester.widget<AppleListTile>(find.widgetWithText(AppleListTile, l.seeDnsAddresses))
          .subtitle,
      '192.168.1.10 · 10.8.0.1',
    );

    // A value row never lies: it asks for nothing but a state colour.
    expect(
      tester.widget<AppleListTile>(find.widgetWithText(AppleListTile, l.protectionEnabled))
          .valueColor,
      isNotNull,
    );
  });

  testWidgets('the device count comes from the clients the server registered', (tester) async {
    await pumpServerInfo(tester, registeredClients: 5);

    expect(
      tester.widget<AppleListTile>(find.widgetWithText(AppleListTile, l.clients)).value,
      '5',
    );
  });

  testWidgets('a stock server leaves the platform and uptime rows out', (tester) async {
    await pumpServerInfo(tester);

    expect(find.widgetWithText(AppleListTile, l.cpuArchitecture), findsNothing);
    expect(find.widgetWithText(AppleListTile, l.uptime), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a forked server also answers its platform and its uptime', (tester) async {
    await pumpServerInfo(
      tester,
      data: serverInfoFixture(
        arch: 'amd64',
        goos: 'linux',
        startTime: DateTime.now().subtract(const Duration(days: 12, hours: 4)),
      ),
    );

    String valueOf(String title) =>
        tester.widget<AppleListTile>(find.widgetWithText(AppleListTile, title)).value!;

    expect(valueOf(l.cpuArchitecture), 'linux/amd64');
    expect(valueOf(l.uptime), l.uptimeDaysHours(12, 4));
  });

  testWidgets('a server up for less than a day reads in hours', (tester) async {
    await pumpServerInfo(
      tester,
      data: serverInfoFixture(
        startTime: DateTime.now().subtract(const Duration(hours: 3, minutes: 12)),
      ),
    );

    expect(
      tester.widget<AppleListTile>(find.widgetWithText(AppleListTile, l.uptime)).value,
      l.uptimeHoursMinutes(3, 12),
    );
    // The platform row is drawn from both answers together, so a server that
    // only says when it started gets the uptime row and nothing else.
    expect(find.widgetWithText(AppleListTile, l.cpuArchitecture), findsNothing);
  });

  test('an uptime the server has not reached yet is not drawn', () {
    expect(formatUptime(null, l), isNull);
    expect(formatUptime(DateTime.now().add(const Duration(hours: 1)), l), isNull);
    expect(formatUptime(DateTime.now().subtract(const Duration(minutes: 7)), l), l.uptimeMinutes(7));
  });

  testWidgets('a server that publishes no language drops that row', (tester) async {
    await pumpServerInfo(tester, data: serverInfoFixture(language: '', dnsAddresses: []));

    expect(find.byWidgetPredicate(
      (w) => w is AppleListTile && w.title == l.serverLanguage,
    ), findsNothing);
    // With no address of its own the page says so under the name of the server
    // it opened, and leaves the row without a list.
    expect(find.text('192.168.1.10'), findsOneWidget);
    expect(
      tester.widget<AppleListTile>(find.widgetWithText(AppleListTile, l.seeDnsAddresses))
          .subtitle,
      isNull,
    );
  });

  testWidgets('the address row opens the sheet that lists them', (tester) async {
    await pumpServerInfo(tester);

    await tester.tap(find.widgetWithText(AppleListTile, l.seeDnsAddresses));
    await tester.pumpAndSettle();

    expect(find.byType(DnsAddressesModal), findsOneWidget);
    expect(find.widgetWithText(ListTile, '10.8.0.1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed read reports the Apple way', (tester) async {
    await pumpServerInfo(tester, succeeds: false);

    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(find.text(l.serverInfoNotLoaded), findsOneWidget);
    expect(find.byType(AppleListTile), findsNothing);
    expect(find.byIcon(CupertinoIcons.exclamationmark_triangle), findsOneWidget);
  });

  testWidgets('the values load behind an Apple spinner', (tester) async {
    final h = await pumpServerInfo(tester, blocks: true, settle: false);

    expect(find.byType(AppleLoading), findsOneWidget);
    expect(find.text(l.loadingServerInfo), findsOneWidget);
    expect(find.byType(AppleListTile), findsNothing);

    h.api.gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(AppleLoading), findsNothing);
    expect(find.widgetWithText(AppleListTile, l.serverVersion), findsOneWidget);
  });
}
