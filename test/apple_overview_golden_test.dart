import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'overview_harness.dart';

// The overview has to be looked at, not only tapped: six blocks in one order,
// with the sizes the design layer gives them. These goldens hold the page as a
// picture, one at phone height for what fits on screen and one tall enough to
// show every block down to 服务.
//
// Regenerate with:
//   flutter test --update-goldens test/apple_overview_golden_test.dart

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the overview fits the phone the way the design layer draws it', (tester) async {
    await pumpOverview(tester, surface: const Size(390, 840));

    expect(find.text(l.protectionOn), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/overview_light.png'),
    );
  });

  testWidgets('the same page in the dark palette', (tester) async {
    await pumpOverview(
      tester,
      brightness: Brightness.dark,
      surface: const Size(390, 840),
    );

    expect(find.text(l.protectionOn), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/overview_dark.png'),
    );
  });

  testWidgets('every block of the page, in order', (tester) async {
    await pumpOverview(tester, surface: const Size(390, 1620));

    expect(find.byType(AppleHero), findsOneWidget);
    expect(find.byType(AppleStatGrid), findsOneWidget);
    expect(find.byType(AppleTrendChart), findsOneWidget);
    expect(find.text(l.topRanking), findsOneWidget);
    expect(find.text(l.services), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/overview_all_light.png'),
    );
  });

  testWidgets('every block in the dark palette too', (tester) async {
    await pumpOverview(
      tester,
      brightness: Brightness.dark,
      surface: const Size(390, 1620),
    );

    expect(find.byType(AppleTrendChart), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/overview_all_dark.png'),
    );
  });
}
