import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'encryption_settings_harness.dart';

// Encryption is the settings row that opens the protocols of the server: the
// group of switches the design layer draws first, then the certificate the
// server reported. The golden keeps the collapsing title, the back capsule, the
// save of the bar and both groups in one frame.
//
// Regenerate with:
//   flutter test --update-goldens test/apple_encryption_settings_golden_test.dart

void main() {
  testWidgets('the protocols are drawn as Apple groups', (tester) async {
    await pumpEncryption(tester, surface: const Size(390, 840));

    // A scroll view only builds what its viewport reaches: the four protocol
    // switches and the certificate rows of `/tls/status` are the frame.
    expect(find.byType(AppleListSection), findsNWidgets(2));
    expect(find.byType(AppleSwitchListTile), findsNWidgets(4));
    expect(find.byType(AppleListTile), findsNWidgets(6));
    expect(find.byType(AppleBackButton), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/encryption_settings_light.png'),
    );
  });

  testWidgets('the protocols in dark mode', (tester) async {
    await pumpEncryption(
      tester,
      surface: const Size(390, 840),
      brightness: Brightness.dark,
    );

    expect(find.byType(AppleListSection), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/encryption_settings_dark.png'),
    );
  });
}
