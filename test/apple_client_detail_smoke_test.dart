import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/screens/clients/client/client_detail.dart';
import 'package:adguard_home_manager/screens/clients/client/client_rules_modal.dart';
import 'package:adguard_home_manager/screens/clients/client/client_screen.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/process_dialog.dart';

import 'client_detail_harness.dart';

/// The device page, tapped the way a user taps it: the switches write the
/// entry back, the identifiers are read from it and the red button asks before
/// it removes anything.
void main() {
  late AppLocalizations l;

  // The design layer marks a value the server does not have with an em dash.
  const noValue = '—';

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the page is the device, named and identified', (tester) async {
    await pumpClientDetail(tester);

    expect(tester.takeException(), isNull);

    // The collapsing title carries the name of the entry and its identifiers.
    expect(
      find.descendant(
        of: find.byType(AppleLargeTitle),
        matching: find.text('MacBook Pro'),
      ),
      findsOneWidget,
    );
    expect(find.text('192.168.1.12 · a0:cc:83:12:34:56'), findsOneWidget);

    // A pushed route draws the back capsule of the screen behind it.
    expect(
      find.descendant(
        of: find.byType(AppleBackButton),
        matching: find.text(l.devices),
      ),
      findsOneWidget,
    );

    // The card of the design layer: the initial of the device and the queries
    // the server counted for it.
    expect(find.byType(AppleAvatar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppleAvatar),
        matching: find.text('M'),
      ),
      findsOneWidget,
    );
    expect(find.text(l.queries), findsOneWidget);
    expect(find.text('18,432'), findsOneWidget);

    // No Material chrome is left on the page.
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('the card keeps only the count the server answers', (tester) async {
    await pumpClientDetail(tester);

    // A per-client blocked total exists in no API, so neither the number of
    // the design layer nor its ring is drawn, and the access lists of the
    // design layer are not drawn either.
    expect(find.text(l.blocked), findsNothing);
    expect(find.byType(AppleDonut), findsNothing);
    expect(find.byType(AppleAreaChart), findsNothing);
    expect(find.text(l.deviceName), findsNothing);

    // The two groups of real data, nothing else.
    expect(find.text(l.clientSettings), findsOneWidget);
    expect(find.text(l.identity), findsOneWidget);
    expect(find.byType(AppleListSection), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a device outside the statistics window shows no count',
      (tester) async {
    await pumpClientDetail(
      tester,
      client: clientFixture(name: 'Living Room TV', ids: const ['192.168.1.30']),
    );

    expect(find.text(l.queries), findsOneWidget);
    expect(find.text(noValue), findsOneWidget);
    expect(find.text('18,432'), findsNothing);
  });

  testWidgets('the count is read from an address too', (tester) async {
    // `top_clients` names a device by its label or by the address the query
    // came from, and the entry below is only known by its address.
    await pumpClientDetail(
      tester,
      client: clientFixture(name: 'Nas', ids: const ['192.168.1.7']),
    );

    expect(find.text('120'), findsOneWidget);
    expect(find.text('18,432'), findsNothing);
  });

  testWidgets('the four switches carry the state written on the entry',
      (tester) async {
    await pumpClientDetail(tester);

    final switches = find.byType(CupertinoSwitch);
    expect(switches, findsNWidgets(4));

    expect(
      tester.widgetList<CupertinoSwitch>(switches).map((s) => s.value).toList(),
      [false, true, true, false],
    );

    expect(find.text(l.useGlobalSettings), findsOneWidget);
    expect(find.text(l.useGlobalSettingsHelper), findsOneWidget);
    expect(find.text(l.dnsFiltering), findsOneWidget);
    expect(find.text(l.dnsFilteringHelper), findsOneWidget);
    expect(find.text(l.safeBrowsing), findsOneWidget);
    expect(find.text(l.parentalControl), findsOneWidget);
  });

  testWidgets('a switch writes the entry back and keeps the state the server kept',
      (tester) async {
    final h = await pumpClientDetail(tester, blockWrites: true);

    // The second switch is the DNS filtering of the entry, which is on.
    await tester.tap(find.byType(CupertinoSwitch).at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The write blocks behind the blocking progress dialog.
    expect(find.text(l.savingChanges), findsOneWidget);
    expect(h.clients.edited, isEmpty);

    h.clients.writes.complete();
    await tester.pumpAndSettle();

    expect(find.text(l.savingChanges), findsNothing);
    expect(h.clients.edited, hasLength(1));

    // The whole entry is sent, so what the page does not show is kept as it was.
    final saved = h.clients.edited.single;
    expect(saved.filteringEnabled, false);
    expect(saved.safebrowsingEnabled, true);
    expect(saved.useGlobalSettings, false);
    expect(saved.parentalEnabled, false);
    expect(saved.name, 'MacBook Pro');
    expect(saved.ids, ['192.168.1.12', 'a0:cc:83:12:34:56']);

    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch).at(1)).value,
      false,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed write leaves the switch where it was', (tester) async {
    final h = await pumpClientDetail(tester, succeeds: false);

    await tester.tap(find.byType(CupertinoSwitch).at(3));
    await tester.pumpAndSettle();

    expect(h.clients.edited, isEmpty);
    expect(find.text(l.clientNotUpdated), findsOneWidget);
    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch).at(3)).value,
      false,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refused write says what the server said', (tester) async {
    const reason = 'another client "living-room" uses the same MAC';
    final h = await pumpClientDetail(
      tester,
      succeeds: false,
      editFailureMessage: reason,
    );

    await tester.tap(find.byType(CupertinoSwitch).at(3));
    await tester.pumpAndSettle();

    // AdGuard Home puts the reason for a 4xx in the response body, and the
    // page used to throw it away: a name already taken, a malformed address
    // and a server that never answered all read as the same sentence.
    expect(find.text(reason), findsOneWidget);
    expect(find.text(l.clientNotUpdated), findsNothing);
    expect(h.clients.edited, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the blocking sheet goes away even when the write throws',
      (tester) async {
    final h = await pumpClientDetail(tester, throwsOnEdit: true);

    await tester.tap(find.byType(CupertinoSwitch).at(3));
    await tester.pump();
    await tester.pumpAndSettle();

    // ProcessModal has a barrier that cannot be dismissed, so an exception
    // between its open and its close left the whole app under a sheet nobody
    // could close, and the switch stayed looking saved.
    expect(find.byType(ProcessDialog), findsNothing);
    expect(find.text(l.clientNotUpdated), findsOneWidget);
    expect(h.clients.edited, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the identity group reads the identifiers of the entry',
      (tester) async {
    await pumpClientDetail(tester);

    // An address is labelled as one, a MAC address as the other.
    expect(find.text(l.ipAddress), findsOneWidget);
    expect(find.widgetWithText(AppleListTile, l.ipAddress), findsOneWidget);
    expect(find.text('192.168.1.12'), findsOneWidget);
    expect(find.text(l.macAddress), findsOneWidget);
    expect(find.text('a0:cc:83:12:34:56'), findsOneWidget);

    // The services of the entry are a state, not a page to open.
    expect(find.text(l.services), findsOneWidget);
    expect(find.text(l.blockedServicesCount(2)), findsOneWidget);

    // Nothing in the group discloses.
    expect(find.byIcon(CupertinoIcons.chevron_right), findsNothing);

    // Tapping an identifier only asks for it to be copied; it opens nothing.
    await tester.tap(find.widgetWithText(AppleListTile, l.ipAddress));
    await tester.pumpAndSettle();

    expect(find.byType(ClientScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the services of a device following the server are said so',
      (tester) async {
    await pumpClientDetail(
      tester,
      client: clientFixture(
        useGlobalBlockedServices: true,
        blockedServices: const [],
      ),
    );

    expect(find.text(l.servicesSameAsServer), findsOneWidget);
    expect(find.text(l.blockedServicesCount(0)), findsNothing);
  });

  testWidgets('a device without identifiers still reads as a group',
      (tester) async {
    await pumpClientDetail(
      tester,
      client: clientFixture(ids: const []),
    );

    expect(find.text(l.noIdentifiers), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the red button removes the entry only after the alert',
      (tester) async {
    final h = await pumpClientDetail(tester);

    await tester.tap(find.text(l.deleteThisDevice));
    await tester.pumpAndSettle();

    expect(find.byType(AppleAlertDialog), findsOneWidget);
    expect(find.text(l.removeClient), findsOneWidget);
    expect(find.text(l.removeClientMessage), findsOneWidget);
    expect(h.clients.deleted, isEmpty);

    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();

    expect(find.byType(AppleAlertDialog), findsNothing);
    expect(h.clients.deleted, isEmpty);
    expect(find.text(l.deleteThisDevice), findsOneWidget);
  });

  testWidgets('a confirmed removal writes the device away and closes the page',
      (tester) async {
    final h = await pumpClientDetail(tester, blockWrites: true);

    await tester.tap(find.text(l.deleteThisDevice));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.confirm));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l.removingClient), findsOneWidget);

    h.clients.writes.complete();
    await tester.pumpAndSettle();

    expect(h.clients.deleted, hasLength(1));
    expect(h.clients.deleted.single.name, 'MacBook Pro');
    expect(find.text(l.removingClient), findsNothing);

    // The page of a device that is gone is not kept on the stack.
    expect(find.byType(ClientDetailScreen), findsNothing);
    expect(find.text(l.deleteThisDevice), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the header action opens the form of the entry', (tester) async {
    final h = await pumpClientDetail(tester);

    await tester.tap(find.widgetWithText(AppleHeaderAction, l.edit));
    await tester.pumpAndSettle();

    expect(find.byType(ClientScreen), findsOneWidget);
    // The form starts from the entry the page is showing.
    expect(find.text('MacBook Pro'), findsWidgets);
    expect(tester.takeException(), isNull);

    // This surface is a narrow one, so the form is the centred card and its
    // close button is the only way out of it that writes nothing.
    await tester.tap(find.byTooltip(l.close));
    await tester.pumpAndSettle();

    expect(find.byType(ClientScreen), findsNothing);
    expect(h.clients.edited, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the back capsule leaves the page it came from', (tester) async {
    await pumpClientDetail(tester);

    await tester.tap(find.byType(AppleBackButton));
    await tester.pumpAndSettle();

    expect(find.byType(AppleLargeTitle), findsNothing);
    expect(find.text(l.deleteThisDevice), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  group('the rules of the device itself', () {
    /// The count a row of the group carries on its right edge.
    String countOf(WidgetTester tester, String title) => tester
        .widget<AppleListTile>(find.widgetWithText(AppleListTile, title))
        .value!;

    Finder ruleRow(String rule) => find.widgetWithText(AppleListTile, rule);

    testWidgets('are left out on a server that would drop them',
        (tester) async {
      // A stock server takes the rules it is sent and forgets them, so the
      // group is left out rather than offering a write that filters nothing.
      await pumpClientDetail(
        tester,
        client: clientFixture(rules: const ['||tracker.example^']),
      );

      expect(find.text(l.clientRules), findsNothing);
      expect(find.text(l.allowList), findsNothing);
      expect(find.text(l.blockList), findsNothing);
      expect(find.byType(AppleListSection), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('are counted as exceptions and blocks', (tester) async {
      await pumpClientDetail(
        tester,
        supportsClientRules: true,
        client: clientFixture(
          rules: const [
            '||tracker.example^',
            '@@||allowed.example^',
            '||ads.example^',
          ],
        ),
      );

      expect(find.text(l.clientRules), findsOneWidget);
      expect(find.byType(AppleListSection), findsNWidgets(3));

      expect(countOf(tester, l.blockList), '2');
      expect(countOf(tester, l.allowList), '1');
      expect(tester.takeException(), isNull);
    });

    testWidgets('are edited in a sheet and written back with the entry',
        (tester) async {
      final h = await pumpClientDetail(
        tester,
        supportsClientRules: true,
        client: clientFixture(rules: const ['||tracker.example^']),
      );

      await tester.tap(find.widgetWithText(AppleHeaderAction, l.editRules));
      await tester.pumpAndSettle();

      expect(find.byType(ClientRulesModal), findsOneWidget);
      expect(ruleRow('||tracker.example^'), findsOneWidget);
      expect(h.clients.edited, isEmpty);

      await tester.tap(
        find.descendant(
          of: ruleRow('||tracker.example^'),
          matching: find.byTooltip(l.delete),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.confirm));
      await tester.pumpAndSettle();

      expect(find.byType(ClientRulesModal), findsNothing);
      expect(h.clients.edited, hasLength(1));

      // The whole entry is sent, so what the group does not show is kept.
      final saved = h.clients.edited.single;
      expect(saved.rules, isEmpty);
      expect(saved.name, 'MacBook Pro');
      expect(saved.ids, ['192.168.1.12', 'a0:cc:83:12:34:56']);
      expect(saved.filteringEnabled, true);

      // The counts on the page follow the write.
      expect(countOf(tester, l.blockList), '0');
      expect(countOf(tester, l.allowList), '0');
      expect(tester.takeException(), isNull);
    });

    testWidgets('are reachable from the header of the group too',
        (tester) async {
      final h = await pumpClientDetail(tester, supportsClientRules: true);

      expect(find.text(l.noClientRules), findsNothing);

      // The two count rows only report what the device holds; the header is
      // the single way into the one editor that serves both kinds.
      await tester.tap(ruleRow(l.blockList));
      await tester.pumpAndSettle();
      expect(find.byType(ClientRulesModal), findsNothing);

      await tester.tap(find.widgetWithText(AppleHeaderAction, l.editRules));
      await tester.pumpAndSettle();

      expect(find.byType(ClientRulesModal), findsOneWidget);
      expect(find.text(l.noClientRules), findsOneWidget);

      await tester.tap(find.text(l.cancel));
      await tester.pumpAndSettle();

      expect(find.byType(ClientRulesModal), findsNothing);
      expect(h.clients.edited, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
