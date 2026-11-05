import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'dns_settings_harness.dart';

// DNS settings is the settings row that opens the upstreams of the server: one
// group of resolvers with its add action and two switches, then the group of
// caches and limits. The golden keeps the collapsing title, the back capsule,
// the two actions of the bar and both groups in one frame.
//
// Regenerate with:
//   flutter test --update-goldens test/apple_dns_settings_golden_test.dart

void main() {
  testWidgets('the resolver list is drawn as two Apple groups', (tester) async {
    await pumpDns(tester, surface: const Size(390, 840));

    expect(find.byType(AppleListSection), findsNWidgets(2));
    expect(find.byType(AppleListTile), findsNWidgets(12));
    expect(find.byType(AppleSwitchListTile), findsNWidgets(2));
    expect(find.byType(AppleBackButton), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dns_settings_light.png'),
    );
  });

  testWidgets('the resolver list in dark mode', (tester) async {
    await pumpDns(
      tester,
      surface: const Size(390, 840),
      brightness: Brightness.dark,
    );

    expect(find.byType(AppleListSection), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dns_settings_dark.png'),
    );
  });
}
