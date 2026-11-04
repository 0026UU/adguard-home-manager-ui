import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/screens/logs/log_tile.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'logs_harness.dart';

// The logs page is the only screen that swaps its whole body under a fixed
// segment, so the golden keeps both halves of the page in the same frame: the
// title with its status line, the segment, the field and the rows below.
//
// Regenerate with: flutter test --update-goldens test/apple_logs_golden_test.dart

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the query log keeps its segment above the rows', (tester) async {
    await pumpLogsPage(
      tester,
      logs: OfflineLogs(),
      live: ScriptedLive(),
      surface: const Size(390, 1200),
    );

    expect(find.byType(AppleSegmented), findsOneWidget);
    expect(find.byType(AppleSearchField), findsOneWidget);
    expect(find.byType(LogTile), findsNWidgets(3));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/logs_history.png'),
    );
  });

  testWidgets('the stream takes the same page with its own rows', (tester) async {
    final live = ScriptedLive();

    await pumpLogsPage(
      tester,
      logs: OfflineLogs(),
      live: live,
      surface: const Size(390, 1200),
    );

    await tester.tap(find.text(l.liveLogs));
    await tester.pumpAndSettle();

    live.emit([
      logFixture('ads.example.org', reason: 'Filtered'),
      logFixture('new.example.io'),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(LogTile), findsNWidgets(2));
    expect(find.byIcon(CupertinoIcons.bolt), findsNothing);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/logs_live.png'),
    );
  });
}
