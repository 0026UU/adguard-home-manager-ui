import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/screens/clients/client/client_rules_modal.dart';
import 'package:adguard_home_manager/screens/clients/client/client_screen_functions.dart';
import 'package:adguard_home_manager/screens/filters/modals/custom_rules/add_custom_rule.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

// The rules of one device are edited in a sheet of their own: the builder the
// global list uses writes into it, a row is removed by its own button, and
// nothing reaches the caller until the confirm at the bottom is pressed.
//
// Run with: flutter test test/apple_client_rules_test.dart

const _rules = ['||tracker.example^', '@@||allowed.example^'];

void main() {
  late AppLocalizations l;

  /// Every list the sheet handed its caller, in the order it handed them.
  late List<List<String>> results;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() => results = []);

  tearDown(() => AppleToast.hide());

  Finder row(String rule) => find.widgetWithText(AppleListTile, rule);

  Future<void> openSheet(
    WidgetTester tester, {
    List<String> rules = _rules,
  }) async {
    // The rule builder opens as a compact dialog on a desktop width and as a
    // full screen page on a phone, so the sheet is driven at the width the
    // dialog is drawn at. A phone width would test a layout this flow never
    // shows.
    await tester.binding.setSurfaceSize(const Size(600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: appleLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: AppleButton(
                label: 'open',
                onPressed: () => openClientRulesModal(
                  context: context,
                  rules: rules,
                  onRules: results.add,
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

    expect(find.byType(ClientRulesModal), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  /// Builds a rule the way a finger does: open the builder, type the domain,
  /// pick the preset and press the check that hands the rule back. The sheet
  /// stays open and the toast of a refused rule stays on screen, so the frame
  /// is advanced by hand rather than settled.
  Future<void> buildRule(
    WidgetTester tester,
    String domain, {
    String? preset,
  }) async {
    await tester.tap(row(l.addClientRule));
    await tester.pumpAndSettle();
    expect(find.byType(AddCustomRule), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), domain);
    await tester.pump();

    if (preset != null) {
      await tester.tap(find.text(preset));
      await tester.pump();
    }

    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AddCustomRule), findsNothing);
    expect(tester.takeException(), isNull);
  }

  Future<void> remove(WidgetTester tester, String rule) async {
    await tester.tap(
      find.descendant(of: row(rule), matching: find.byTooltip(l.delete)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('the sheet holds the rules the device already carries',
      (tester) async {
    await openSheet(tester);

    expect(find.text(l.clientRules), findsOneWidget);
    expect(find.text(l.clientRulesHelper), findsOneWidget);

    expect(row('||tracker.example^'), findsOneWidget);
    expect(row('@@||allowed.example^'), findsOneWidget);

    // A blocking rule reads as blocked, an exception as allowed.
    expect(find.widgetWithText(ApplePill, l.blocked), findsOneWidget);
    expect(find.widgetWithText(ApplePill, l.allowed), findsOneWidget);

    // Opening the sheet writes nothing on its own.
    expect(results, isEmpty);
  });

  testWidgets('a device without rules says so instead of showing an empty card',
      (tester) async {
    await openSheet(tester, rules: const []);

    expect(find.text(l.noClientRules), findsOneWidget);
    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the builder of the global list writes into the sheet',
      (tester) async {
    await openSheet(tester, rules: const []);

    await buildRule(tester, 'example.org');

    expect(row('||example.org^'), findsOneWidget);
    expect(find.widgetWithText(ApplePill, l.blocked), findsOneWidget);
    expect(find.text(l.noClientRules), findsNothing);

    // The rule is on the sheet only; the device keeps what it had until the
    // confirm at the bottom is pressed.
    expect(results, isEmpty);
  });

  testWidgets('the unblock preset writes an exception', (tester) async {
    await openSheet(tester, rules: const []);

    await buildRule(tester, 'example.org', preset: l.unblock);

    expect(row('@@||example.org^'), findsOneWidget);
    expect(find.widgetWithText(ApplePill, l.allowed), findsOneWidget);
  });

  testWidgets('a rule already on the list is refused and said so',
      (tester) async {
    await openSheet(tester);

    await buildRule(tester, 'tracker.example');

    expect(find.text(l.ruleAlreadyOnList), findsOneWidget);
    // The row it would have duplicated is still the only one.
    expect(row('||tracker.example^'), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('a row is removed by its own button', (tester) async {
    await openSheet(tester);

    await remove(tester, '||tracker.example^');

    expect(row('||tracker.example^'), findsNothing);
    expect(row('@@||allowed.example^'), findsOneWidget);

    // Removing a row is an edit of the sheet, not a write to the server.
    expect(results, isEmpty);
  });

  testWidgets('the confirm hands the caller the list as it stands',
      (tester) async {
    await openSheet(tester);

    await buildRule(tester, 'example.org');
    await remove(tester, '@@||allowed.example^');

    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();

    expect(find.byType(ClientRulesModal), findsNothing);
    expect(results, [
      ['||tracker.example^', '||example.org^'],
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every rule can be taken off a device', (tester) async {
    await openSheet(tester, rules: const ['||tracker.example^']);

    await remove(tester, '||tracker.example^');
    expect(find.text(l.noClientRules), findsOneWidget);

    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();

    // An empty list is a write of its own, not a missing one.
    expect(results, [const <String>[]]);
  });

  testWidgets('the cancel and the close button write nothing', (tester) async {
    await openSheet(tester);

    await remove(tester, '||tracker.example^');
    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();

    expect(find.byType(ClientRulesModal), findsNothing);
    expect(results, isEmpty);

    // The caller keeps the list it opened the sheet with, so reopening it
    // shows the row the cancel threw away.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(row('||tracker.example^'), findsOneWidget);

    await tester.tap(find.byTooltip(l.close));
    await tester.pumpAndSettle();

    expect(find.byType(ClientRulesModal), findsNothing);
    expect(results, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
