import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/screens/filters/modals/custom_rules/edit_custom_rules.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'rules_editor_harness.dart';

// The rule editor is a page: a title, one monospaced field, three templates and
// a cancel/save pair. These tests drive it the way a finger would and read back
// what the caller was handed, because a field that cannot round-trip its own
// text is not an editor.
//
// Run with: flutter test test/apple_rules_editor_test.dart

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  tearDown(() => AppleToast.hide());

  group('custom rules editor', () {
    testWidgets('is a page holding the rules the server already has', (tester) async {
      await pumpRulesEditor(tester);

      expect(find.byType(AppleScreen), findsOneWidget);
      expect(find.text(l.customRules), findsWidgets);
      expect(find.text(l.customRulesEditorHint), findsOneWidget);

      // The capsule is named after the tab the page was pushed from.
      expect(find.text(l.filters), findsOneWidget);

      // The head of the field block: the label and the syntax note beside it.
      expect(find.text(l.rules), findsOneWidget);
      expect(find.text(l.adblockSyntax), findsOneWidget);

      expect(rulesFieldText(tester), rulesFixture.join('\n'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('draws the field the way the design layer draws code', (tester) async {
      await pumpRulesEditor(tester);

      final field = tester.widget<TextField>(find.byType(TextField));

      expect(field.style!.fontFamily, 'monospace');
      expect(field.style!.fontSize, 13);
      expect(field.style!.height, 1.7);

      // A dozen lines stay on screen before the field grows, and the box has no
      // outline: the card behind it is the chrome.
      expect(field.minLines, 12);
      expect(field.maxLines, isNull);
      expect(field.decoration!.border, InputBorder.none);

      final card = tester.widget<Container>(
        find.ancestor(of: find.byType(TextField), matching: find.byType(Container)).first,
      );
      expect((card.decoration! as BoxDecoration).borderRadius, BorderRadius.circular(12));
    });

    testWidgets('offers the three templates of the design layer', (tester) async {
      await pumpRulesEditor(tester);

      expect(find.text(l.insert), findsOneWidget);
      expect(find.text('||domain^'), findsOneWidget);
      expect(find.text(l.templateBlockDomain), findsOneWidget);
      expect(find.text('@@||domain^'), findsOneWidget);
      expect(find.text(l.templateAllowDomain), findsOneWidget);
      expect(find.text(r'$important'), findsOneWidget);
      expect(find.text(l.templateImportant), findsOneWidget);
    });

    testWidgets('a template lands on a line of its own and says so', (tester) async {
      await pumpRulesEditor(tester);

      // The caret starts inside the first rule, so the template has to open a
      // line of its own rather than glue itself to what is already there.
      final finder = find.byType(TextField);
      await tester.tap(finder);
      await tester.pump();
      tester.widget<TextField>(finder).controller!.selection =
          const TextSelection.collapsed(offset: 0);

      await tester.tap(find.text('||domain^'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(rulesFieldText(tester), '||domain^\n${rulesFixture.join('\n')}');
      expect(find.text(l.templateInserted), findsOneWidget);
    });

    testWidgets('inserting at the end appends without a blank line', (tester) async {
      await pumpRulesEditor(tester);

      final controller = tester.widget<TextField>(find.byType(TextField)).controller!;
      controller.selection = TextSelection.collapsed(offset: controller.text.length);

      await tester.tap(find.text('@@||domain^'));
      await tester.pump();

      expect(rulesFieldText(tester), '${rulesFixture.join('\n')}\n@@||domain^');
    });

    testWidgets('saving hands back the lines, blanks dropped', (tester) async {
      List<String>? saved;
      await pumpRulesEditor(tester, onConfirm: (rules) => saved = rules);

      final controller = tester.widget<TextField>(find.byType(TextField)).controller!;
      controller.text = '||a.example^\n\n@@b.example  \n! note\n';
      controller.selection = TextSelection.collapsed(offset: controller.text.length);

      await scrollToRulesFooter(tester);
      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(saved, ['||a.example^', '@@b.example', '! note']);
      // The page is gone, so the caller owns the request and its result.
      expect(find.byType(EditCustomRules), findsNothing);
    });

    testWidgets('cancel pops without saving', (tester) async {
      var saved = false;
      await pumpRulesEditor(tester, onConfirm: (_) => saved = true);

      await scrollToRulesFooter(tester);
      await tester.tap(find.text(l.cancel));
      await tester.pumpAndSettle();

      expect(saved, isFalse);
      expect(find.byType(EditCustomRules), findsNothing);
    });

    testWidgets('an empty set of rules saves as an empty list', (tester) async {
      List<String>? saved;
      await pumpRulesEditor(tester, onConfirm: (rules) => saved = rules);

      tester.widget<TextField>(find.byType(TextField)).controller!.clear();

      await scrollToRulesFooter(tester);
      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(saved, isEmpty);
    });

    testWidgets('a server with no rules opens an empty field', (tester) async {
      await pumpRulesEditor(tester, rules: const []);

      expect(rulesFieldText(tester), '');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the footer splits the row evenly between the pair', (tester) async {
      await pumpRulesEditor(tester);
      await scrollToRulesFooter(tester);

      final buttons = find.byType(AppleFormButton);
      expect(buttons, findsNWidgets(2));

      final cancel = tester.getSize(buttons.at(0));
      final save = tester.getSize(buttons.at(1));

      expect(cancel.height, 48);
      expect(save.height, 48);
      expect(cancel.width, save.width);
    });
  });
}
