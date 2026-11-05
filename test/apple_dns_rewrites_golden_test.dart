import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'rewrites_harness.dart';

// The rewrite page is the settings row that opens a table of domain
// rewrites: one caption with its add action, then one disclosure row per rule.
// The golden keeps the collapsing title, the back capsule and the whole group
// in one frame.
//
// Regenerate with:
//   flutter test --update-goldens test/apple_dns_rewrites_golden_test.dart

void main() {
  testWidgets('the rewrite table is drawn as one group', (tester) async {
    await pumpRewrites(tester, surface: const Size(390, 840));

    expect(find.byType(AppleListSection), findsOneWidget);
    expect(find.byType(AppleListTile), findsNWidgets(6));
    expect(find.byType(AppleBackButton), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dns_rewrites_light.png'),
    );
  });

  testWidgets('the rewrite table in dark mode', (tester) async {
    await pumpRewrites(
      tester,
      surface: const Size(390, 840),
      brightness: Brightness.dark,
    );

    expect(find.byType(AppleListSection), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dns_rewrites_dark.png'),
    );
  });
}
