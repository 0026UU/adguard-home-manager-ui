import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/applied_filters.dart';
import 'package:adguard_home_manager/screens/logs/filters/logs_filters_modal.dart';
import 'package:adguard_home_manager/screens/logs/log_tile.dart';
import 'package:adguard_home_manager/screens/logs/logs_list.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'logs_harness.dart';

// The logs page owns the two views the design layer draws on one screen: the
// query log kept by the server and the live stream. Every test here taps the
// page the way a user does — segment, field, rows — and reads what comes back
// out of the providers.

late AppLocalizations l;

/// Types into the field under the title and lets the debounce run.
Future<void> _search(WidgetTester tester, String value) async {
  await tester.enterText(find.byType(TextField).first, value);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  late OfflineLogs logs;
  late ScriptedLive live;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    logs = OfflineLogs();
    live = ScriptedLive();
  });

  testWidgets('the page opens on the query log the server keeps', (tester) async {
    await pumpLogsPage(tester, logs: logs, live: live);

    expect(logs.fetches, 1);
    expect(find.byType(AppleSegmented), findsOneWidget);
    expect(find.text(l.historyLogs), findsOneWidget);
    expect(find.text(l.liveLogs), findsOneWidget);
    expect(tester.widget<AppleSegmented>(find.byType(AppleSegmented)).selectedIndex, 0);

    // The field sits under the title, where the design layer draws it, instead
    // of hiding behind a search button.
    expect(find.byType(AppleSearchField), findsOneWidget);
    expect(find.text(l.searchDomainOrClient), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.search), findsOneWidget);

    expect(find.text(l.queryLog), findsOneWidget);
    expect(find.text(l.loadedRecords('3')), findsOneWidget);
    expect(find.byType(LogTile), findsNWidgets(3));
    expect(live.watching, isFalse);
  });

  testWidgets('the field filters the stored log once the typing stops', (tester) async {
    await pumpLogsPage(tester, logs: logs, live: live);

    await _search(tester, 'tracker');

    expect(logs.filters, 1);
    expect(logs.searchText, 'tracker');
    expect(find.byType(LogTile), findsOneWidget);
    expect(find.text('news.example.org'), findsNothing);
    expect(find.text(l.loadedRecords('1')), findsOneWidget);

    await _search(tester, '');

    expect(logs.filters, 2);
    expect(logs.searchText, isNull);
    expect(find.byType(LogTile), findsNWidgets(3));
  });

  testWidgets('the live segment starts the stream and empties the list', (tester) async {
    await pumpLogsPage(tester, logs: logs, live: live);

    await tester.tap(find.text(l.liveLogs));
    await tester.pumpAndSettle();

    expect(live.watching, isTrue);
    // A stream that has not seen anything yet says so rather than showing the
    // stored rows.
    expect(find.byType(LogTile), findsNothing);
    expect(find.text(l.hereWillAppearRealtimeLogs), findsOneWidget);
    expect(find.text(l.trackingQueries), findsOneWidget);
    expect(find.text(l.queryLog), findsNothing);
    // The navigation bar keeps only the filters; a reload is a pull down.
    expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsNothing);

    final before = logs.fetches;
    await tester.tap(find.text(l.historyLogs));
    await tester.pumpAndSettle();

    expect(live.watching, isFalse);
    expect(logs.fetches, before);
    expect(find.byType(LogTile), findsNWidgets(3));
    expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsNothing);
  });

  testWidgets('the live stream keeps its own rows and its own filter', (tester) async {
    await pumpLogsPage(tester, logs: logs, live: live);

    await tester.tap(find.text(l.liveLogs));
    await tester.pumpAndSettle();

    live.emit([logFixture('ads.example.org'), logFixture('new.example.io')]);
    await tester.pumpAndSettle();

    expect(find.text(l.liveLogs), findsNWidgets(2));
    expect(find.text(l.loadedRecords('2')), findsOneWidget);
    expect(find.byType(LogTile), findsNWidgets(2));

    final filters = logs.filters;
    await _search(tester, 'new');

    // Typing in the stream must not ask the server for the stored log.
    expect(logs.filters, filters);
    expect(find.byType(LogTile), findsOneWidget);
    expect(find.text('new.example.io'), findsOneWidget);
    expect(find.text('ads.example.org'), findsNothing);

    await _search(tester, 'livingroom');

    expect(find.byType(LogTile), findsNWidgets(2));
  });

  testWidgets('the nav bar offers the log filters directly', (tester) async {
    await pumpLogsPage(tester, logs: logs, live: live);

    await tester.tap(find.byIcon(CupertinoIcons.slider_horizontal_3));
    await tester.pumpAndSettle();

    expect(find.byType(LogsFiltersModal), findsOneWidget);

    await tester.tap(find.text(l.apply));
    await tester.pumpAndSettle();

    expect(find.byType(LogsFiltersModal), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a status filter leaves a chip under the title', (tester) async {
    await pumpLogsPage(tester, logs: logs, live: live);

    expect(find.byType(LogsListWidget), findsOneWidget);
    expect(find.byType(AppleFilterChip), findsNothing);

    logs.setSelectedStatuses(const [LogStatus.blocked]);
    logs.setAppliedFilters(
      AppliedFiters(
        statuses: const [LogStatus.blocked],
        searchText: null,
        clients: const [],
        timeRange: LogTimeRange.twentyFourHours,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppleFilterChip), findsOneWidget);
    expect(find.text(l.onlyStatus(l.queryBlocked)), findsOneWidget);
  });
}
