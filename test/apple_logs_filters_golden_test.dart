import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/models/applied_filters.dart';
import 'package:adguard_home_manager/screens/logs/filters/logs_filters_modal.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'logs_sheets_harness.dart';

// The filter sheet is the prototype's 筛选日志 card: the three quick statuses as
// chips, the devices with a switch each, the window segment and 重置 / 应用 at
// the foot. What the last search ran with is also what the sheet opens on.
//
// Regenerate with:
//   flutter test --update-goldens test/apple_logs_filters_golden_test.dart

/// Opens the sheet the way a second visit does: with the applied filters.
Future<SheetsHarness> _applied(
  WidgetTester tester, {
  required Size surface,
  required bool dialog,
  Brightness brightness = Brightness.light,
}) async {
  final harness = SheetsHarness.withClients()
    ..logs.setAppliedFilters(AppliedFiters(
      statuses: const [LogStatus.blocked],
      searchText: null,
      clients: const ['192.168.1.2'],
      timeRange: LogTimeRange.twentyFourHours,
    ));

  await pumpSheet(
    tester,
    harness,
    surface,
    LogsFiltersModal(dialog: dialog),
    brightness: brightness,
  );

  expect(find.byType(AppleFormModal), findsOneWidget);
  expect(find.byType(AppleToggleChip), findsNWidgets(3));
  expect(find.byType(AppleSwitchListTile), findsNWidgets(2));
  expect(find.byType(AppleSegmented), findsOneWidget);
  expect(tester.takeException(), isNull);

  return harness;
}

void main() {
  testWidgets('the filter sheet on a phone', (tester) async {
    await _applied(
      tester,
      surface: const Size(390, 844),
      dialog: false,
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/logs_filters_phone_light.png'),
    );
  });

  testWidgets('the same sheet in the dark palette', (tester) async {
    await _applied(
      tester,
      surface: const Size(390, 844),
      dialog: false,
      brightness: Brightness.dark,
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/logs_filters_phone_dark.png'),
    );
  });

  testWidgets('the same sheet as a card on a wide layout', (tester) async {
    await _applied(
      tester,
      surface: const Size(900, 900),
      dialog: true,
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/logs_filters_card_light.png'),
    );
  });
}
