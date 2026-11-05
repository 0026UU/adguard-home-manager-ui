import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'rules_editor_harness.dart';

// The rule editor is a whole page: the collapsing title with its back capsule,
// the monospaced field on a card, the three templates and the footer pair. The
// golden keeps the top of the page in one frame, where the field lives.
//
// Regenerate with:
//   flutter test --update-goldens test/apple_rules_editor_golden_test.dart

void main() {
  testWidgets('the editor is drawn as one pushed page', (tester) async {
    await pumpRulesEditor(tester);

    expect(find.byType(AppleScreen), findsOneWidget);
    expect(find.byType(AppleBackButton), findsOneWidget);
    expect(find.byType(AppleGroupHeader), findsOneWidget);
    expect(find.byType(AppleListSection), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/rules_editor_light.png'),
    );
  });

  testWidgets('the editor page in dark mode', (tester) async {
    await pumpRulesEditor(tester, brightness: Brightness.dark);

    expect(find.byType(AppleListSection), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/rules_editor_dark.png'),
    );
  });
}
