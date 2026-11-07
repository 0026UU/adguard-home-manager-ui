import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/rewrite_rules.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/providers/rewrite_rules_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/screens/settings/dns_rewrites/dns_rewrite_modal.dart';
import 'package:adguard_home_manager/services/api_client.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'rewrites_harness.dart';

/// `/rewrite/delete` answered from memory, keeping what the app posts.
class _DeleteApi extends ApiClientV2 {
  _DeleteApi()
      : super(server: Server(
          id: '1',
          name: 'Home box',
          connectionMethod: 'http',
          domain: 'adguard.example.com',
          defaultServer: false,
          runningOnHa: false,
        ));

  final List<Map<String, dynamic>> deleted = [];

  @override
  Future<ApiResponse> deleteDnsRewriteRule({
    required Map<String, dynamic> data,
  }) async {
    deleted.add(data);
    return const ApiResponse(successful: true);
  }
}

/// The rewrite page, tapped the way a user taps it: the header action adds a
/// rule, a row edits one, and the form's delete button asks before removing it.
void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the rules are one Apple group under the page title', (tester) async {
    final h = await pumpRewrites(tester);

    expect(tester.takeException(), isNull);
    // The page fetched its rules exactly once while opening.
    expect(h.stub.fetches, 1);

    // The collapsing title carries the page name and its one-line summary.
    expect(
      find.descendant(
        of: find.byType(AppleLargeTitle),
        matching: find.text(l.dnsRewrites),
      ),
      findsOneWidget,
    );
    expect(find.text(l.dnsRewritesSubtitle), findsOneWidget);

    // A pushed route draws the back capsule of the design layer.
    expect(find.byType(AppleBackButton), findsOneWidget);

    // The group caption and its add action, then one row per rule.
    expect(find.text(l.rules), findsOneWidget);
    expect(find.widgetWithText(AppleHeaderAction, l.add), findsOneWidget);
    expect(find.byType(AppleListSection), findsOneWidget);
    expect(find.byType(AppleListTile), findsNWidgets(6));
    expect(find.text('nas.local'), findsOneWidget);
    expect(find.text('192.168.1.5'), findsNWidgets(2));
    // Every row is a disclosure, so the chevron count matches the row count.
    expect(find.byIcon(CupertinoIcons.chevron_right), findsNWidgets(6));

    // No Material chrome is left on the page.
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('a rule switched off says so in its own row', (tester) async {
    await pumpRewrites(tester, rules: rewriteFixture(disablePrinter: true));

    expect(
      find.text('192.168.1.66 · ${l.disabled}'),
      findsOneWidget,
    );
    expect(find.text('192.168.1.5'), findsNWidgets(2));
  });

  testWidgets('the header action adds a rule', (tester) async {
    final h = await pumpRewrites(tester, blockWrites: true);

    await tester.tap(find.widgetWithText(AppleHeaderAction, l.add));
    await tester.pumpAndSettle();

    expect(find.byType(DnsRewriteModal), findsOneWidget);
    expect(find.text(l.addDnsRewrite), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    // A new rule cannot be switched off, so the form offers no switch for it.
    expect(find.byType(CupertinoSwitch), findsNothing);

    // Nothing typed yet, so confirming does nothing.
    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();
    expect(h.stub.added, isEmpty);

    await tester.enterText(find.byType(TextFormField).at(0), 'camera.local');
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(1), '192.168.1.77');
    await tester.pump();

    await tester.tap(find.text(l.confirm));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The write blocks behind the progress dialog until the server answers.
    expect(find.text(l.addingRewrite), findsOneWidget);

    h.stub.writes.complete();
    await tester.pumpAndSettle();

    expect(h.stub.added, hasLength(1));
    expect(h.stub.added.single.domain, 'camera.local');
    expect(h.stub.added.single.answer, '192.168.1.77');
    expect(find.byType(DnsRewriteModal), findsNothing);
    expect(find.text(l.addingRewrite), findsNothing);
    expect(find.byType(AppleListTile), findsNWidgets(7));
    expect(find.text('camera.local'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a row edits its rule and keeps it switched off', (tester) async {
    final h = await pumpRewrites(
      tester,
      rules: rewriteFixture(disablePrinter: true),
    );

    await tester.tap(find.widgetWithText(AppleListTile, 'printer.local'));
    await tester.pumpAndSettle();

    expect(find.text(l.editRewriteRule), findsOneWidget);
    // The row's domain is already typed into the form.
    expect(
      find.descendant(
        of: find.byType(DnsRewriteModal),
        matching: find.text('printer.local'),
      ),
      findsOneWidget,
    );
    // The stored state is carried into the form instead of being reset.
    expect(find.byType(CupertinoSwitch), findsOneWidget);
    expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value, false);

    await tester.enterText(find.byType(TextFormField).at(1), '192.168.1.80');
    await tester.pump();
    await tester.tap(find.text(l.confirm));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(h.stub.edited, hasLength(1));
    final saved = h.stub.edited.single.first;
    final previous = h.stub.edited.single.last;
    expect(saved.answer, '192.168.1.80');
    expect(saved.enabled, false);
    expect(previous.domain, 'printer.local');
    expect(previous.enabled, false);
    expect(find.text('192.168.1.80 · ${l.disabled}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching the rule on from the form saves it enabled', (tester) async {
    final h = await pumpRewrites(
      tester,
      rules: rewriteFixture(disablePrinter: true),
    );

    await tester.tap(find.widgetWithText(AppleListTile, 'printer.local'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pump();
    await tester.tap(find.text(l.confirm));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(h.stub.edited.single.first.enabled, true);
    expect(find.text('192.168.1.66'), findsOneWidget);
    expect(find.text('192.168.1.66 · ${l.disabled}'), findsNothing);
  });

  testWidgets('the form deletes only after the alert is confirmed', (tester) async {
    final h = await pumpRewrites(tester, blockWrites: true);

    await tester.tap(find.widgetWithText(AppleListTile, 'vault'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.delete));
    await tester.pumpAndSettle();

    expect(find.byType(AppleAlertDialog), findsOneWidget);
    expect(find.text(l.deleteDnsRewrite), findsOneWidget);
    expect(find.text(l.deleteDnsRewriteMessage), findsOneWidget);
    expect(h.stub.deleted, isEmpty);

    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();

    expect(find.byType(AppleAlertDialog), findsNothing);
    expect(h.stub.deleted, isEmpty);

    await tester.tap(find.widgetWithText(AppleListTile, 'vault'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.confirm));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The write blocks behind the progress dialog.
    expect(find.text(l.deleting), findsOneWidget);

    h.stub.writes.complete();
    await tester.pumpAndSettle();

    expect(h.stub.deleted, hasLength(1));
    expect(h.stub.deleted.single.domain, 'vault');
    expect(find.text(l.deleting), findsNothing);
    expect(find.byType(AppleListTile), findsNWidgets(5));
    expect(find.text('vault'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty rule list still keeps the Apple shell', (tester) async {
    await pumpRewrites(tester, rules: []);

    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(find.text(l.noRewriteRules), findsOneWidget);
    expect(find.byType(AppleListTile), findsNothing);
    expect(find.byIcon(Icons.error), findsNothing);

    // The card fills the page, so the bar below it is out of sight: the
    // empty state has to start the form itself.
    await tester.tap(find.widgetWithText(AppleButton, l.addDnsRewrite));
    await tester.pumpAndSettle();

    expect(find.byType(DnsRewriteModal), findsOneWidget);
  });

  testWidgets('a failed load reports the Apple way', (tester) async {
    final h = await pumpRewrites(tester, succeeds: false);

    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(find.text(l.rewriteRulesNotLoaded), findsOneWidget);
    expect(find.byType(AppleListTile), findsNothing);

    expect(find.widgetWithText(AppleFormButton, l.refresh), findsOneWidget);

    await tester.tap(find.widgetWithText(AppleFormButton, l.refresh));
    await tester.pumpAndSettle();

    // A retry that only redraws the same card would leave the tab a dead
    // end, so what matters is that the server was asked again.
    expect(h.stub.fetches, 2);
  });

  testWidgets('the rules load behind an Apple spinner', (tester) async {
    final h = await pumpRewrites(tester, blocks: true, settle: false);

    expect(find.byType(AppleLoading), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    h.stub.gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(AppleLoading), findsNothing);
    expect(find.byType(AppleListTile), findsNWidgets(6));
  });

  test('deleting one answer keeps the other answers of the same domain', () async {
    final api = _DeleteApi();
    final provider = RewriteRulesProvider()
      ..update(ServersProvider()..setApiClient2(api));

    // One domain may carry several rules and the server deletes only the pair
    // it was posted, so the local list has to keep the others: dropping them
    // here would show them gone and write them off for real on the next save.
    final ipSwitch = RewriteRules(
        domain: 'nas.local', answer: '192.168.1.5', enabled: true);
    final mirror = RewriteRules(
        domain: 'nas.local', answer: '192.168.1.9', enabled: true);
    final vault =
        RewriteRules(domain: 'vault', answer: '10.8.0.2', enabled: true);
    provider.setRewriteRulesData([ipSwitch, mirror, vault]);

    expect(await provider.deleteDnsRewrite(ipSwitch), isTrue);

    expect(api.deleted, [
      {'domain': 'nas.local', 'answer': '192.168.1.5'}
    ]);
    expect(
      provider.rewriteRules!.map((rule) => rule.answer).toList(),
      ['192.168.1.9', '10.8.0.2'],
    );
  });
}
