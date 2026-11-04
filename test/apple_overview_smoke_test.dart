import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/screens/home/management_modal/management_modal.dart';
import 'package:adguard_home_manager/screens/home/server_status.dart';
import 'package:adguard_home_manager/screens/settings/server_info/server_info.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'overview_harness.dart';

// The overview is one page in the design layer: a status card, four numbers, one
// chart of one window, one ranking and the services it links to. These tests tap
// the page the way a finger would, and check what the server was actually asked
// for, because a segment that repaints the same answer is indistinguishable from
// a chart that lies.
//
// Run with: flutter test test/apple_overview_smoke_test.dart

void main() {
  late AppLocalizations l;

  // The page formats every number with the platform locale, so the test has to
  // read them back the same way instead of assuming en_US.
  late String locale;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
    locale = Platform.localeName;
  });

  group('overview', () {
    testWidgets('draws the six blocks the design layer puts on the page', (tester) async {
      await pumpOverview(tester);

      expect(find.text(l.overview), findsWidgets);
      expect(find.text(l.protectionOn), findsOneWidget);
      expect(find.text(l.totalQueries), findsOneWidget);
      expect(find.text(l.blocked), findsWidgets);
      expect(find.text(l.avgProcessingTime), findsOneWidget);
      expect(find.text(l.activeRules), findsOneWidget);
      expect(find.text(l.trafficTrend), findsOneWidget);
      expect(find.text(l.topRanking), findsOneWidget);
      expect(find.text(l.services.toUpperCase()), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Nothing the design layer does not draw may stay on the page.
      expect(find.byType(PopupMenuButton), findsNothing);
      expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsNothing);
      expect(find.text(l.statistics), findsNothing);
      expect(find.byType(ServerStatusWidget), findsNothing);
      expect(find.byType(AppleTrendChart), findsOneWidget);
    });

    testWidgets('the tiles read what the server holds, not what the mock had', (tester) async {
      final h = await pumpOverview(tester);

      // The rules that are in force: the 312546 of the two enabled lists plus
      // the server's own user rule. The disabled list, with its 999999 rules,
      // counts for nothing.
      expect(find.text(compactFormat(312547, locale)), findsOneWidget);
      expect(find.text(l.filterListsCount('2')), findsOneWidget);

      // 7300 of 20478 queries stopped.
      expect(find.text(compactFormat(20478, locale)), findsOneWidget);
      expect(find.text(compactFormat(7300, locale)), findsOneWidget);
      expect(find.text(l.blockRate('35.6%')), findsOneWidget);

      // 0.0246 seconds, shown in the milliseconds the tile names.
      expect(find.text('24.6'), findsOneWidget);
      expect(find.text(l.belowReference('40')), findsOneWidget);

      // The newest hour against the same hour of yesterday: 1168 -> 1240.
      expect(find.text(l.vsYesterday('▲ 6.2%')), findsOneWidget);

      // The devices the server knows, the version it reports. The hero keeps
      // both of its lines in one Text, so they are matched by content.
      expect(find.textContaining(l.protectingDevices(23)), findsOneWidget);
      expect(find.text('v0.107.0'), findsOneWidget);
      expect(find.text('Home Router'), findsWidgets);
      expect(h.status.serverStatus!.generalEnabled, isTrue);
    });

    testWidgets('a paused server says so in every place it can', (tester) async {
      await pumpOverview(tester, protectionOn: false);

      expect(find.text(l.protectionPaused), findsWidgets);
      expect(find.textContaining(l.allQueriesAllowedDirectly), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.pause_circle), findsOneWidget);
    });

    testWidgets('the trend segment asks the server for its own window', (tester) async {
      final h = await pumpOverview(tester);

      // The page opened on the day it shows.
      expect(h.api.trendRequests, [86400000]);

      await tester.tap(find.text(l.days7));
      await tester.pumpAndSettle();

      expect(h.api.trendRequests, [86400000, 604800000]);
      expect(h.status.trend!.timeUnits, 'days');
      expect(
        tester.widget<AppleTrendChart>(find.byType(AppleTrendChart)).queries.length,
        7,
      );

      await tester.tap(find.text(l.days30));
      await tester.pumpAndSettle();

      expect(h.api.trendRequests.last, 2592000000);
      expect(
        tester.widget<AppleTrendChart>(find.byType(AppleTrendChart)).queries.length,
        30,
      );

      // 共 N 条 counts the buckets of the window that is showing.
      expect(find.text(l.queriesTotal(compactFormat(509032, locale))), findsOneWidget);
    });

    testWidgets('the window is clamped to what the server keeps', (tester) async {
      final h = await pumpOverview(
        tester,
        statisticsIntervalMs: 24 * 60 * 60 * 1000,
      );

      await tester.tap(find.text(l.days30));
      await tester.pumpAndSettle();

      // A month cannot be asked of a server that keeps a day.
      expect(h.api.trendRequests.last, 86400000);
    });

    testWidgets('touching the chart names the bucket it touched', (tester) async {
      await pumpOverview(tester);

      expect(find.text(l.chartTipHint), findsOneWidget);

      final before = tester.getTopLeft(find.byType(AppleTrendChart));
      await tester.tapAt(before + const Offset(200, 60));
      await tester.pumpAndSettle();

      final chart = tester.widget<AppleTrendChart>(find.byType(AppleTrendChart));
      final int index = chart.selectedIndex;
      expect(index, greaterThanOrEqualTo(0));

      final asked = chart.queries[index];
      final stopped = chart.blocked[index];
      // The same alphabetical order the generated method declares.
      expect(
        find.text(
          l.chartTipPoint(
            intFormat(stopped.round(), locale),
            chart.labels![index],
            '${wholePercentFormat(asked > 0 ? stopped / asked * 100 : 0, locale)}%',
            intFormat(asked.round(), locale),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(l.chartTipHint), findsNothing);
    });

    testWidgets('the ranking switches list and opens all of it', (tester) async {
      await pumpOverview(tester);

      // Five rows on the card, the busiest first; the sixth waits in the sheet.
      expect(find.text('ads.doubleclick.net'), findsOneWidget);
      expect(find.text('device-metrics-us.amazon.com'), findsOneWidget);
      expect(find.text('smetrics.adobe.com'), findsNothing);

      await tester.tap(find.text(l.queriedDomainsShort));
      await tester.pumpAndSettle();
      expect(find.text('api.telegram.org'), findsOneWidget);

      await tester.tap(find.text(l.activeDevices));
      await tester.pumpAndSettle();
      expect(find.text('iPhone 15 Pro'), findsOneWidget);

      await tester.tap(find.text(l.blockedDomainsShort));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.all));
      await tester.pumpAndSettle();

      // The sheet holds all six, not the five the card shows.
      expect(find.text('smetrics.adobe.com'), findsOneWidget);
      expect(find.text(l.topRanking), findsWidgets);

      await tester.tap(find.text(l.close));
      await tester.pumpAndSettle();
      expect(find.text(l.close), findsNothing);
      expect(find.text('smetrics.adobe.com'), findsNothing);
    });

    testWidgets('the shield turns a paused server back on', (tester) async {
      final h = await pumpOverview(tester, protectionOn: false);

      await tester.tap(find.byIcon(CupertinoIcons.pause_circle));
      await tester.pumpAndSettle();

      expect(h.api.lastProtectionEnable, isTrue);
      expect(h.status.serverStatus!.generalEnabled, isTrue);
      expect(find.text(l.protectionOn), findsOneWidget);
    });

    testWidgets('the shield asks before pausing a running server', (tester) async {
      final h = await pumpOverview(tester);

      await tester.tap(find.byIcon(CupertinoIcons.checkmark_shield));
      await tester.pumpAndSettle();

      expect(find.text(l.pauseProtection), findsOneWidget);
      expect(find.text(l.manageProtection), findsWidgets);

      await tester.tap(find.text(l.pauseProtection));
      await tester.pumpAndSettle();

      expect(find.text(l.pauseForever), findsOneWidget);
      expect(find.text(l.seconds(30)), findsOneWidget);
      expect(find.text(l.hour(1)), findsOneWidget);

      await tester.tap(find.text(l.pauseForever));
      await tester.pumpAndSettle();

      expect(h.api.lastProtectionEnable, isFalse);
      expect(h.api.lastProtectionTime, isNull);
      expect(h.status.serverStatus!.generalEnabled, isFalse);
    });

    testWidgets('the pause durations are the ones the server takes', (tester) async {
      final h = await pumpOverview(tester);

      await tester.tap(find.byIcon(CupertinoIcons.checkmark_shield));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.pauseProtection));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.minutes(10)));
      await tester.pumpAndSettle();

      // AdGuard Home counts a pause from the moment it stops, so ten minutes is
      // asked for as 599 seconds.
      expect(h.api.lastProtectionEnable, isFalse);
      expect(h.api.lastProtectionTime, 599000);
      expect(h.status.serverStatus!.disabledUntil, isNotNull);

      // The page now counts the pause down; the test ends it so the timer does
      // not outlive the test.
      h.status.stopCountdown();
    });

    testWidgets('管理防护 opens the protections of the server', (tester) async {
      final h = await pumpOverview(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(AppleHero),
          matching: find.text(l.manageProtection),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ManagementModal), findsOneWidget);
      expect(h.status.serverStatus!.generalEnabled, isTrue);
    });

    testWidgets('查看日志 hands the log tab the whole picture', (tester) async {
      final h = await pumpOverview(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(AppleHero),
          matching: find.text(l.viewLogs),
        ),
      );
      await tester.pumpAndSettle();

      expect(h.appConfig.selectedScreen, 2);
      expect(h.logs.selectedResultStatus, 'all');
    });

    testWidgets('the blocked tile opens the log tab on the blocked rows', (tester) async {
      final h = await pumpOverview(tester);

      await tester.tap(find.text(compactFormat(7300, locale)));
      await tester.pumpAndSettle();

      expect(h.appConfig.selectedScreen, 2);
      expect(h.logs.selectedResultStatus, 'blocked');
    });

    testWidgets('the service group carries the state the server answers', (tester) async {
      await pumpOverview(tester);

      expect(find.text(l.serverInformation), findsOneWidget);
      expect(find.text(l.dhcp), findsOneWidget);
      expect(find.text(l.dnsOverTls), findsOneWidget);
      expect(find.text(l.dnsRewrites), findsOneWidget);

      // The DHCP row reports what the status call answers, the TLS row what
      // the encryption call answers, and every row can be walked into.
      expect(find.text(l.enabled), findsOneWidget);
      expect(find.text(l.configured), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.chevron_right), findsNWidgets(4));
    });

    testWidgets('a service row goes to the screen it names', (tester) async {
      await pumpOverview(tester);

      await tester.tap(find.text(l.serverInformation));
      await tester.pumpAndSettle();

      expect(find.byType(ServerInformation), findsOneWidget);
    });
  });
}
