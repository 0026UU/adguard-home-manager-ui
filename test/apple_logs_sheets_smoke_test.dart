import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/applied_filters.dart';
import 'package:adguard_home_manager/screens/logs/filters/added_client_id_selection_modal.dart';
import 'package:adguard_home_manager/screens/logs/filters/clients_modal.dart';
import 'package:adguard_home_manager/screens/logs/filters/logs_filters_modal.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/custom_checkbox_list_tile.dart';
import 'package:adguard_home_manager/widgets/custom_list_tile.dart';

import 'logs_sheets_harness.dart';

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the filter sheet only applies on apply', (tester) async {
    final harness = SheetsHarness.withClients();

    await pumpSheet(
      tester,
      harness,
      const Size(900, 900),
      const LogsFiltersModal(dialog: true),
    );

    expect(find.byType(AppleFormModal), findsOneWidget);
    expect(find.text(l.filterLogs), findsOneWidget);
    expect(find.text(l.status), findsOneWidget);
    expect(find.text(l.clients), findsOneWidget);
    expect(find.text(l.timeRange), findsOneWidget);

    // One chip per quick status, in prototype order.
    expect(find.byType(AppleToggleChip), findsNWidgets(3));
    expect(find.text(l.queryBlocked), findsOneWidget);
    expect(find.text(l.queryAllowed), findsOneWidget);
    expect(find.text(l.queryUpstream), findsOneWidget);

    // Both known devices, and the window the provider starts with.
    expect(find.byType(AppleSwitchListTile), findsNWidgets(2));
    expect(find.text('device-2'), findsOneWidget);
    expect(
      tester.widget<AppleSegmented>(find.byType(AppleSegmented)).selectedIndex,
      LogTimeRange.twentyFourHours.index,
    );

    await tester.tap(find.text(l.queryBlocked));
    await tester.tap(find.text('device-2'));
    await tester.tap(find.text(l.lastSevenDays));
    await tester.pumpAndSettle();

    // Nothing reached the applied filters yet: the sheet edits a draft.
    expect(harness.logs.appliedFilters.statuses, isEmpty);
    expect(harness.logs.appliedFilters.clients, isEmpty);
    expect(
      harness.logs.appliedFilters.timeRange,
      LogTimeRange.twentyFourHours,
    );

    await tester.tap(find.text(l.apply));
    await tester.pumpAndSettle();

    expect(find.byType(LogsFiltersModal), findsNothing);

    final applied = harness.logs.appliedFilters;
    expect(applied.statuses, [LogStatus.blocked]);
    expect(applied.clients, ['192.168.1.2']);
    expect(applied.timeRange, LogTimeRange.sevenDays);
    expect(applied.reasons, ['FilteredBlackList', 'FilteredBlockedService']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the close button leaves the running search alone',
      (tester) async {
    final harness = SheetsHarness.withClients();
    harness.logs.setAppliedFilters(AppliedFiters(
      statuses: const [LogStatus.allowed],
      searchText: null,
      clients: const [],
      timeRange: LogTimeRange.oneHour,
    ));

    await pumpSheet(
      tester,
      harness,
      const Size(420, 800),
      const LogsFiltersModal(dialog: false),
    );

    await tester.tap(find.text(l.queryBlocked));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.xmark));
    await tester.pumpAndSettle();

    expect(find.byType(LogsFiltersModal), findsNothing);
    expect(harness.logs.appliedFilters.statuses, [LogStatus.allowed]);
    expect(harness.logs.appliedFilters.timeRange, LogTimeRange.oneHour);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset clears the filters but keeps the search', (tester) async {
    final harness = SheetsHarness.withClients();
    harness.logs.setSearchText('example.com');
    harness.logs.setAppliedFilters(AppliedFiters(
      statuses: const [LogStatus.blocked, LogStatus.allowed],
      searchText: 'example.com',
      clients: const ['192.168.1.2'],
      timeRange: LogTimeRange.sevenDays,
    ));

    await pumpSheet(
      tester,
      harness,
      const Size(420, 800),
      const LogsFiltersModal(dialog: false),
    );

    // The draft mirrors what the search was actually run with.
    expect(
      tester.widget<AppleSegmented>(find.byType(AppleSegmented)).selectedIndex,
      LogTimeRange.sevenDays.index,
    );
    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch).at(1)).value,
      isTrue,
    );

    await tester.tap(find.text(l.resetFilters));
    await tester.pumpAndSettle();

    expect(find.byType(LogsFiltersModal), findsNothing);

    final applied = harness.logs.appliedFilters;
    expect(applied.statuses, isEmpty);
    expect(applied.clients, isEmpty);
    expect(applied.timeRange, LogTimeRange.twentyFourHours);
    expect(applied.searchText, 'example.com');
    expect(harness.logs.selectedStatuses, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('devices past the inline limit open the full picker',
      (tester) async {
    final harness = SheetsHarness.withManyClients();

    await pumpSheet(
      tester,
      harness,
      const Size(900, 900),
      const LogsFiltersModal(dialog: true),
    );

    expect(find.byType(AppleSwitchListTile), findsNWidgets(5));
    expect(find.text(l.allClients), findsOneWidget);
    expect(
      tester.widget<AppleListTile>(find.byType(AppleListTile)).value,
      '2',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the clients sheet ticks active clients into the log filter',
      (tester) async {
    final harness = SheetsHarness.withClients();

    await pumpSheet(
      tester,
      harness,
      const Size(900, 900),
      ClientsModal(dialog: true),
    );

    expect(find.byType(AppleFormModal), findsOneWidget);
    expect(find.byType(AppleSearchField), findsOneWidget);
    expect(find.byType(AppleSegmented), findsOneWidget);
    expect(find.text(l.selectClientsFiltersInfo), findsOneWidget);
    // Two auto clients, each with its address as the title.
    expect(find.byType(CustomCheckboxListTile), findsNWidgets(2));
    expect(find.text('192.168.1.1'), findsOneWidget);

    await tester.tap(find.text('192.168.1.2'));
    await tester.pumpAndSettle();

    expect(harness.logs.selectedClients, ['192.168.1.2']);
    expect(
        tester
            .widget<CupertinoCheckbox>(find.byType(CupertinoCheckbox).at(1))
            .value,
        true);

    await tester.tap(find.text('192.168.1.2'));
    await tester.pumpAndSettle();

    expect(harness.logs.selectedClients, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('added clients go through the identifier picker', (tester) async {
    final harness = SheetsHarness.withClients();

    await pumpSheet(
      tester,
      harness,
      const Size(420, 800),
      ClientsModal(dialog: false),
    );

    await tester.tap(find.text(l.added));
    await tester.pumpAndSettle();

    // The added tab has no checkboxes; it asks which id to filter by.
    expect(find.byType(CustomCheckboxListTile), findsNothing);
    expect(find.byType(CustomListTile), findsNWidgets(1));
    expect(find.text('10.0.0.0, aa:bb:cc:dd:ee:ff'), findsOneWidget);

    await tester.tap(find.text(l.select));
    await tester.pumpAndSettle();

    expect(find.byType(AddedClientIdSelectionModal), findsOneWidget);
    expect(find.text(l.selectIdToFilter), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();

    expect(find.byType(AddedClientIdSelectionModal), findsNothing);
    expect(find.byType(ClientsModal), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
