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
    // The navigation bar keeps the filters and a button that reads the stream
    // again where it stands.
    expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsOneWidget);

    final liveReads = live.onceReads;
    await tester.tap(find.byIcon(CupertinoIcons.arrow_clockwise));
    await tester.pumpAndSettle();

    expect(live.onceReads, liveReads + 1);

    final before = logs.fetches;
    await tester.tap(find.text(l.historyLogs));
    await tester.pumpAndSettle();

    expect(live.watching, isFalse);
    expect(logs.fetches, before);
    expect(find.byType(LogTile), findsNWidgets(3));

    // On the stored log the same button goes back to the server for the rows.
    expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsOneWidget);
    await tester.tap(find.byIcon(CupertinoIcons.arrow_clockwise));
    await tester.pumpAndSettle();

    expect(logs.fetches, before + 1);
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

  testWidgets('the chips over the live rows narrow the rows themselves',
      (tester) async {
    await pumpLogsPage(tester, logs: logs, live: live);

    await tester.tap(find.text(l.liveLogs));
    await tester.pumpAndSettle();

    live.emit([
      logFixture('old.example.org', time: DateTime.utc(2024, 5, 1, 11)),
      logFixture('news.example.org', reason: 'NotFilteredNotFound'),
      logFixture('other.example.org', client: '192.0.2.9'),
      logFixture('ads.example.org'),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(LogTile), findsNWidgets(4));

    logs.setAppliedFilters(AppliedFiters(
      statuses: const [LogStatus.blocked],
      searchText: null,
      clients: const [],
      timeRange: LogTimeRange.twentyFourHours,
    ));
    await tester.pumpAndSettle();

    // The blocked chip stands for the filter reasons the server names, so the
    // upstream answer is no longer on screen.
    expect(find.byType(AppleFilterChip), findsOneWidget);
    expect(find.byType(LogTile), findsNWidgets(3));
    expect(find.text('news.example.org'), findsNothing);

    logs.setAppliedFilters(AppliedFiters(
      statuses: const [LogStatus.blocked],
      searchText: null,
      clients: const ['192.168.1.20'],
      timeRange: LogTimeRange.twentyFourHours,
    ));
    await tester.pumpAndSettle();

    // The device chip matches the address the query came from, not the name
    // the row shows.
    expect(find.byType(AppleFilterChip), findsNWidgets(2));
    expect(find.byType(LogTile), findsNWidgets(2));
    expect(find.text('other.example.org'), findsNothing);

    logs.setAppliedFilters(AppliedFiters(
      statuses: const [],
      searchText: null,
      clients: const ['192.168.1.20'],
      timeRange: LogTimeRange.oneHour,
    ));
    await tester.pumpAndSettle();

    // The window counts from the newest query the stream read, so the row an
    // hour behind it falls out of the last hour while its newer neighbours
    // stay, whatever reason they carry.
    expect(find.byType(LogTile), findsNWidgets(2));
    expect(find.text('old.example.org'), findsNothing);
    expect(find.text('ads.example.org'), findsOneWidget);
    expect(find.text('news.example.org'), findsOneWidget);
  });

  testWidgets('the live empty state says what it is waiting for',
      (tester) async {
    await pumpLogsPage(tester, logs: logs, live: live);

    await tester.tap(find.text(l.liveLogs));
    await tester.pumpAndSettle();

    // Nothing has asked the server since the view opened, and the copy says
    // the server is up and will answer.
    expect(find.byIcon(CupertinoIcons.bolt), findsOneWidget);
    expect(find.text(l.hereWillAppearRealtimeLogs), findsOneWidget);
    expect(find.text(l.protectionRunning), findsOneWidget);

    logs.setAppliedFilters(AppliedFiters(
      statuses: const [LogStatus.blocked],
      searchText: null,
      clients: const ['192.0.2.9'],
      timeRange: LogTimeRange.twentyFourHours,
    ));
    live.emit([logFixture('ads.example.org')]);
    await tester.pumpAndSettle();

    // The row arrived and the chip threw it away, which the page has to say
    // instead of showing a bare label.
    expect(find.text(l.noLogsDisplay), findsOneWidget);
    // The copy blames the filters, not the clock: live rows are by definition
    // recent, so "no logs that old" would send the user to the wrong control.
    expect(find.text(l.noLiveLogsMatchingFilters), findsOneWidget);
    expect(find.text(l.resetFilters), findsOneWidget);

    await tester.tap(find.text(l.resetFilters));
    await tester.pumpAndSettle();

    expect(find.byType(LogTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a load that failed keeps the filters within reach',
      (tester) async {
    final unreachable = OfflineLogs(failing: true);

    await pumpLogsPage(tester, logs: unreachable, live: live);

    expect(find.text(l.logsNotLoaded), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.slider_horizontal_3), findsOneWidget);
    // A failed load is the only thing on the page, so the pull gesture that
    // would retry it is invisible; the page has to offer the retry by name.
    expect(find.widgetWithText(AppleFormButton, l.refresh), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.slider_horizontal_3));
    await tester.pumpAndSettle();

    expect(find.byType(LogsFiltersModal), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty stored log says whether filters are the reason',
      (tester) async {
    final quiet = OfflineLogs(empty: true);

    await pumpLogsPage(tester, logs: quiet, live: live);

    expect(find.byType(LogTile), findsNothing);
    expect(find.text(l.noLogsDisplay), findsOneWidget);
    // With nothing on screen throwing rows away, the page says no more than
    // that the window is empty.
    expect(find.text(l.noLogsMatchingFilters), findsNothing);

    quiet.setAppliedFilters(AppliedFiters(
      statuses: const [LogStatus.blocked],
      searchText: null,
      clients: const [],
      timeRange: LogTimeRange.twentyFourHours,
    ));
    await tester.pumpAndSettle();

    // The same rule the stream follows: something on screen is narrowing the
    // rows, so the copy names that instead of leaving a bare label.
    expect(find.text(l.noLogsMatchingFilters), findsOneWidget);
    expect(find.text(l.noLogsThatOld), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a row names its reason on the one line the pill has',
      (tester) async {
    await pumpLogsPage(tester, logs: logs, live: live);

    await tester.tap(find.text(l.liveLogs));
    await tester.pumpAndSettle();

    live.emit([
      logFixture('a.example.org', reason: 'FilteredBlackList'),
      logFixture('b.example.org', reason: 'FilteredParental'),
      logFixture('c.example.org', reason: 'NotFilteredNotFound'),
    ]);
    await tester.pumpAndSettle();

    // The pill is a single line. The labels the old filter screen drew over
    // two lines carried a newline, so every blocked row read "Blocked…" and
    // hid which rule had stopped the query.
    expect(find.text(l.blockedBlacklistRow), findsOneWidget);
    expect(find.text(l.blockedParentalRow), findsOneWidget);
    expect(find.text(l.processedRow), findsOneWidget);

    for (final twoLine in [
      l.blockedBlacklist,
      l.blockedParental,
      l.processed,
    ]) {
      expect(twoLine, contains('\n'));
      expect(find.text(twoLine), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });
}
