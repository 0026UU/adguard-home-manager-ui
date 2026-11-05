import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'client_detail_harness.dart';

// The device page is the client row of the devices list opened as its own
// route: the name and the count of the card, the switches written on the entry,
// the identifiers it is known by and the red button underneath.
//
// Regenerate with:
//   flutter test --update-goldens test/apple_client_detail_golden_test.dart

void main() {
  testWidgets('the device page is one pushed Apple page', (tester) async {
    await pumpClientDetail(tester, surface: const Size(390, 1060));

    expect(find.byType(AppleBackButton), findsOneWidget);
    expect(find.byType(AppleCard), findsOneWidget);
    expect(find.byType(AppleAvatar), findsOneWidget);
    expect(find.byType(AppleListSection), findsNWidgets(2));
    expect(find.byType(AppleSwitchListTile), findsNWidgets(4));
    // The red button under the two groups is the only one the page owns.
    expect(find.byType(AppleButton), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/client_detail_light.png'),
    );
  });

  testWidgets('the rules of the device are a group of their own',
      (tester) async {
    // Only the forked server keeps them, and it is the one the page is built
    // against, so the group is drawn here and left out in the two frames above.
    await pumpClientDetail(
      tester,
      surface: const Size(390, 1060),
      supportsClientRules: true,
      client: clientFixture(
        rules: const [
          '||tracker.example^',
          '@@||allowed.example^',
          '||ads.example^',
        ],
      ),
    );

    expect(find.byType(AppleListSection), findsNWidgets(3));
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/client_detail_rules_light.png'),
    );
  });

  testWidgets('the device page in dark mode', (tester) async {
    await pumpClientDetail(
      tester,
      surface: const Size(390, 1060),
      brightness: Brightness.dark,
    );

    expect(find.byType(AppleListSection), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/client_detail_dark.png'),
    );
  });
}
