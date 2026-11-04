import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'server_info_harness.dart';

// Server information is the settings row that answers what the box reports
// about itself: one card of value rows and the group holding its addresses.
// The golden keeps the collapsing title, the back capsule and both groups in
// one frame.
//
// Regenerate with:
//   flutter test --update-goldens test/apple_server_info_golden_test.dart

void main() {
  testWidgets('the server answers are drawn as Apple groups', (tester) async {
    await pumpServerInfo(tester, surface: const Size(390, 840));

    expect(find.byType(AppleListSection), findsNWidgets(2));
    expect(find.byType(AppleListTile), findsNWidgets(8));
    expect(find.byType(AppleBackButton), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/server_info_light.png'),
    );
  });

  testWidgets('the server answers in dark mode', (tester) async {
    await pumpServerInfo(
      tester,
      surface: const Size(390, 840),
      brightness: Brightness.dark,
    );

    expect(find.byType(AppleListSection), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/server_info_dark.png'),
    );
  });
}
