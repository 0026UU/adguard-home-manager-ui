import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/settings/settings.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'logs_harness.dart';
import 'overview_harness.dart';

import 'surface.dart';

// Pull-to-refresh is invisible: nothing about a list says it can be pulled, and
// a page that only shows what it fetched when it opened leaves a user with no
// way to ask that does not depend on knowing the gesture. These tests check the
// button that answers for it, that it makes the very call the gesture makes,
// and that the address it sits beside can be hidden by the setting that has
// always claimed to hide it.
//
// Run with: flutter test test/apple_refresh_action_test.dart

Future<void> _pumpShell(WidgetTester tester, Widget home) async {
  SharedPreferences.setMockInitialValues({});

  setTestSurface(tester, const Size(390, 1200));

  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfigProvider>(
            create: (_) => AppConfigProvider(sharedPreferencesInstance: prefs)),
        ChangeNotifierProvider(create: (_) => ServersProvider()),
        ChangeNotifierProvider(create: (_) => StatusProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appleLightTheme(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('the refresh button', () {
    testWidgets('a screen that can be pulled carries the button on its bar',
        (tester) async {
      var calls = 0;

      await _pumpShell(
        tester,
        AppleScreen(
          title: 'Pulled',
          onRefresh: () async => calls++,
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 400)),
          ],
        ),
      );

      expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(CupertinoIcons.arrow_clockwise));
      await tester.pumpAndSettle();

      expect(calls, 1);
    });

    testWidgets('a screen with nothing to ask for carries no button',
        (tester) async {
      await _pumpShell(
        tester,
        AppleScreen(
          title: 'Static',
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 400)),
          ],
        ),
      );

      expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsNothing);
    });

    testWidgets('a second tap while the call is in flight does not stack',
        (tester) async {
      final gate = Completer<void>();
      var calls = 0;

      await _pumpShell(
        tester,
        AppleScreen(
          title: 'Busy',
          onRefresh: () async {
            calls++;
            await gate.future;
          },
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 400)),
          ],
        ),
      );

      await tester.tap(find.byIcon(CupertinoIcons.arrow_clockwise));
      await tester.pump();

      // The button says it is working, and takes no further taps while it is.
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      final button = find.ancestor(
        of: find.byType(CupertinoActivityIndicator),
        matching: find.byType(IconButton),
      );
      expect(tester.widget<IconButton>(button).onPressed, isNull);

      await tester.tap(button);
      await tester.pump();
      expect(calls, 1);

      gate.complete();
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsOneWidget);
    });

    testWidgets('the overview button asks for everything the page shows',
        (tester) async {
      final h = await pumpOverview(tester);

      // The page opened by asking once for the window it shows.
      expect(h.api.trendRequests, hasLength(1));

      await tester.tap(find.byIcon(CupertinoIcons.arrow_clockwise));
      await tester.pumpAndSettle();

      expect(h.api.trendRequests, hasLength(2));
      // The same window, not a rescaled answer for another one.
      expect(h.api.trendRequests.first, h.api.trendRequests.last);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the query log button refetches the rows', (tester) async {
      final logs = OfflineLogs();
      final live = ScriptedLive();

      await pumpLogsPage(tester, logs: logs, live: live);

      expect(logs.fetches, 1);
      expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsOneWidget);

      await tester.tap(find.byIcon(CupertinoIcons.arrow_clockwise));
      await tester.pumpAndSettle();

      expect(logs.fetches, 2);
    });

    testWidgets('the live stream button reads the stream it is on',
        (tester) async {
      final logs = OfflineLogs();
      final live = ScriptedLive();

      await pumpLogsPage(tester, logs: logs, live: live);

      await tester.tap(find.text(l.liveLogs));
      await tester.pumpAndSettle();

      final before = live.onceReads;
      await tester.tap(find.byIcon(CupertinoIcons.arrow_clockwise));
      await tester.pumpAndSettle();

      expect(live.onceReads, greaterThan(before));
      expect(logs.fetches, 1);
    });
  });

  group('hiding the server address', () {
    testWidgets('the setting carries the switch and writes it down',
        (tester) async {
      await _pumpShell(tester, const Settings());

      final row = find.ancestor(
        of: find.text(l.hideServerAddress),
        matching: find.byType(AppleSwitchListTile),
      );
      expect(row, findsOneWidget);
      expect(tester.widget<AppleSwitchListTile>(row).value, isFalse);

      await tester.tap(
        find.descendant(of: row, matching: find.byType(CupertinoSwitch)),
      );
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('hideServerAddress'), isTrue);
      expect(
        tester.widget<AppleSwitchListTile>(row).value,
        isTrue,
      );
    });

    testWidgets('the address is on the overview and the setting takes it off',
        (tester) async {
      final h = await pumpOverview(tester);

      // The line the page signs itself with: which server, where it lives,
      // whether it is protecting.
      final title = find.byType(AppleLargeTitle).first;
      String line() => tester.widget<AppleLargeTitle>(title).subtitle ?? '';

      expect(line(), contains(overviewServer.domain));

      await h.appConfig.setHideServerAddress(true);
      await tester.pumpAndSettle();

      expect(line(), isNot(contains(overviewServer.domain)));
      expect(line(), isNot(contains(overviewServer.port)));
      // Only the address goes; the page still says which server this is and
      // whether it is protecting.
      expect(line(), contains(overviewServer.name));
      expect(line(), contains(l.protectionRunning));

      await h.appConfig.setHideServerAddress(false);
      await tester.pumpAndSettle();

      expect(line(), contains(overviewServer.domain));
    });
  });
}
