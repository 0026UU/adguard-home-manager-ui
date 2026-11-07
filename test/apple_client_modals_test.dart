import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/models/safe_search.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/screens/clients/client/blocking_schedule.dart';
import 'package:adguard_home_manager/screens/clients/client/blocking_schedule_modal.dart';
import 'package:adguard_home_manager/screens/clients/client/client_screen_functions.dart';
import 'package:adguard_home_manager/screens/clients/client/safe_search_modal.dart';
import 'package:adguard_home_manager/screens/clients/client/services_modal.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'client_modals_harness.dart';

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
    tz.initializeTimeZones();
  });

  group('services picker', () {
    Future<StubFiltering> openServices(
      WidgetTester tester, {
      required List<String> selected,
      required List<List<String>> results,
      int count = 3,
      bool succeeds = true,
      Completer<bool>? gate,
      Size surface = const Size(390, 844),
      Brightness brightness = Brightness.light,
      Widget? modal,
    }) async {
      final stub = StubFiltering(services: serviceCatalog(count), succeeds: succeeds)
        ..gate = gate;
      addTearDown(stub.dispose);

      await pumpAppleApp(
        tester,
        surface: surface,
        brightness: brightness,
        providers: [ChangeNotifierProvider<FilteringProvider>.value(value: stub)],
        body: (context) => AppleButton(
          label: 'Open services',
          onPressed: () => modal != null
              ? showModalBottomSheet<void>(
                  context: context,
                  useRootNavigator: true,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => modal,
                )
              : openServicesModal(
                  context: context,
                  blockedServices: selected,
                  onUpdateBlockedServices: results.add,
                ),
        ),
      );

      await tester.tap(find.text('Open services'));
      await settleRoute(tester);
      return stub;
    }

    testWidgets('lists the catalog with the device selection ticked',
        (tester) async {
      final selected = ['svc_1'];
      final results = <List<String>>[];
      final stub = await openServices(tester, selected: selected, results: results);

      expect(find.byType(ServicesModal), findsOneWidget);
      expect(find.byType(AppleFormModal), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.text(l.services), findsOneWidget);
      expect(find.byTooltip(l.close), findsOneWidget);

      expect(find.byType(AppleListTile), findsNWidgets(3));
      expect(isChecked(tester, 'Service 0'), isFalse);
      expect(isChecked(tester, 'Service 1'), isTrue);
      expect(isChecked(tester, 'Service 2'), isFalse);
      expect(stub.loaderFlags, [true]);
      expect(results, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('spins while the catalog loads and settles into rows',
        (tester) async {
      final gate = Completer<bool>();
      final selected = <String>[];
      final results = <List<String>>[];
      await openServices(
        tester,
        selected: selected,
        results: results,
        gate: gate,
      );

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.text(l.loadingBlockedServicesList), findsOneWidget);
      expect(find.byType(AppleListTile), findsNothing);
      expect(
        tester.widget<AppleFormFooter>(find.byType(AppleFormFooter)).confirmEnabled,
        isFalse,
      );

      gate.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(find.byType(AppleListTile), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelling and closing discard the edits', (tester) async {
      final selected = ['svc_1'];
      final results = <List<String>>[];
      await openServices(tester, selected: selected, results: results);

      await tester.tap(checkRow('Service 0'));
      await tester.pumpAndSettle();
      await tester.tap(checkRow('Service 1'));
      await tester.pumpAndSettle();
      expect(isChecked(tester, 'Service 0'), isTrue);
      expect(isChecked(tester, 'Service 1'), isFalse);
      expect(selected, ['svc_1']);
      expect(results, isEmpty);

      await tester.tap(find.byTooltip(l.close));
      await tester.pumpAndSettle();
      expect(find.byType(ServicesModal), findsNothing);
      expect(selected, ['svc_1']);
      expect(results, isEmpty);

      await tester.tap(find.text('Open services'));
      await tester.pumpAndSettle();
      expect(isChecked(tester, 'Service 0'), isFalse);
      expect(isChecked(tester, 'Service 1'), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('confirming nothing ticked clears every service',
        (tester) async {
      final selected = ['svc_0', 'svc_2'];
      final results = <List<String>>[];
      await openServices(tester, selected: selected, results: results);

      await tester.tap(checkRow('Service 0'));
      await tester.pumpAndSettle();
      await tester.tap(checkRow('Service 2'));
      await tester.pumpAndSettle();

      final footer = tester.widget<AppleFormFooter>(find.byType(AppleFormFooter));
      expect(footer.confirmEnabled, isTrue);
      await tester.tap(find.text(l.confirm));
      // A second activation during the exit must not confirm again.
      footer.onConfirm!();
      await tester.pumpAndSettle();

      expect(results, [<String>[]]);
      expect(identical(results.single, selected), isFalse);
      expect(selected, ['svc_0', 'svc_2']);
      expect(find.byType(ServicesModal), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed catalog load offers a retry', (tester) async {
      final selected = <String>[];
      final results = <List<String>>[];
      final stub = await openServices(
        tester,
        selected: selected,
        results: results,
        succeeds: false,
      );

      expect(find.byType(AppleEmptyState), findsOneWidget);
      expect(find.text(l.blockedServicesListNotLoaded), findsOneWidget);
      expect(find.byType(AppleListTile), findsNothing);
      expect(stub.loads, 1);

      stub.succeeds = true;
      await tester.tap(find.text(l.refresh));
      await tester.pumpAndSettle();

      expect(stub.loads, 2);
      expect(find.byType(AppleEmptyState), findsNothing);
      expect(find.byType(AppleListTile), findsNWidgets(3));
      await tester.tap(checkRow('Service 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.confirm));
      await tester.pumpAndSettle();
      expect(results, [
        ['svc_2']
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sheet shape scrolls a long catalog on a small phone',
        (tester) async {
      final selected = <String>[];
      final results = <List<String>>[];
      await openServices(
        tester,
        selected: selected,
        results: results,
        count: 40,
        surface: const Size(320, 568),
        modal: ServicesModal(
          dialog: false,
          blockedServices: selected,
          onConfirm: results.add,
        ),
      );

      expect(find.byType(ServicesModal), findsOneWidget);
      expect(find.text(l.confirm).hitTestable(), findsOneWidget);

      final scrollable = find.byType(SingleChildScrollView);
      for (var i = 0;
          i < 40 && checkRow('Service 39').hitTestable().evaluate().isEmpty;
          i++) {
        await tester.drag(scrollable, const Offset(0, -240));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(checkRow('Service 39').hitTestable(), findsOneWidget);

      await tester.tap(checkRow('Service 39'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.confirm));
      await tester.pumpAndSettle();
      expect(results, [
        ['svc_39']
      ]);
      expect(tester.takeException(), isNull);
    });
  });

  group('safe search picker', () {
    SafeSearch draftSafeSearch({bool enabled = false, bool google = false}) =>
        SafeSearch(
          enabled: enabled,
          bing: false,
          duckduckgo: false,
          ecosia: false,
          google: google,
          pixabay: false,
          yandex: false,
          youtube: false,
        );

    Future<void> openSafeSearch(
      WidgetTester tester, {
      required SafeSearch safeSearch,
      required List<SafeSearch> results,
      Size surface = const Size(390, 844),
    }) async {
      await pumpAppleApp(
        tester,
        surface: surface,
        body: (context) => AppleButton(
          label: 'Open safe search',
          onPressed: () => openSafeSearchModal(
            context: context,
            safeSearch: safeSearch,
            defaultSafeSearch: draftSafeSearch(),
            onUpdateSafeSearch: results.add,
          ),
        ),
      );
      await tester.tap(find.text('Open safe search'));
      await tester.pumpAndSettle();
    }

    testWidgets('engines stay locked until safe search is on', (tester) async {
      final results = <SafeSearch>[];
      await openSafeSearch(
        tester,
        safeSearch: draftSafeSearch(),
        results: results,
      );

      expect(find.byType(SafeSearchModal), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.text(l.safeSearch), findsOneWidget);
      expect(find.text(l.safeSearchSettings), findsOneWidget);
      expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
          isFalse);
      expect(rowEnabled(tester, 'Google'), isFalse);
      expect(isChecked(tester, 'Google'), isFalse);

      // A locked engine ignores taps instead of quietly ticking.
      await tester.tap(checkRow('Google'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(isChecked(tester, 'Google'), isFalse);

      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      expect(rowEnabled(tester, 'Google'), isTrue);
      expect(rowEnabled(tester, 'YouTube'), isTrue);
      expect(results, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('confirm returns the edited engines and spares the input',
        (tester) async {
      final input = draftSafeSearch(enabled: true);
      final results = <SafeSearch>[];
      await openSafeSearch(tester, safeSearch: input, results: results);

      expect(rowEnabled(tester, 'Google'), isTrue);
      await tester.tap(checkRow('Google'));
      await tester.pumpAndSettle();
      // The last engines sit under the fold of a phone sized dialog.
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -220));
      await tester.pumpAndSettle();
      await tester.tap(checkRow('YouTube'));
      await tester.pumpAndSettle();
      await tester.tap(checkRow('YouTube'));
      await tester.pumpAndSettle();
      expect(input.google, isFalse);

      await tester.tap(find.text(l.confirm));
      await tester.pumpAndSettle();

      final confirmed = results.single;
      expect(confirmed.enabled, isTrue);
      expect(confirmed.google, isTrue);
      expect(confirmed.youtube, isFalse);
      expect(confirmed.bing, isFalse);
      expect(identical(confirmed, input), isFalse);
      expect(input.google, isFalse);
      expect(find.byType(SafeSearchModal), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('turning safe search off confirms every engine as untouched',
        (tester) async {
      final input = draftSafeSearch(enabled: true, google: true);
      final results = <SafeSearch>[];
      await openSafeSearch(tester, safeSearch: input, results: results);

      expect(isChecked(tester, 'Google'), isTrue);
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      expect(rowEnabled(tester, 'Google'), isFalse);

      await tester.tap(find.text(l.cancel));
      await tester.pumpAndSettle();
      expect(results, isEmpty);
      expect(input.enabled, isTrue);

      await tester.tap(find.text('Open safe search'));
      await tester.pumpAndSettle();
      expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
          isTrue);
      expect(isChecked(tester, 'Google'), isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('blocking schedule picker', () {
    Future<List<EditBlockingSchedule>> openSchedule(
      WidgetTester tester, {
      EditBlockingSchedule? schedule,
      Size surface = const Size(390, 844),
    }) async {
      final results = <EditBlockingSchedule>[];
      await pumpAppleApp(
        tester,
        surface: surface,
        body: (context) => AppleButton(
          label: 'Open schedule',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => BlockingScheduleModal(
              schedule: schedule,
              onConfirm: results.add,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open schedule'));
      await tester.pumpAndSettle();
      return results;
    }

    Future<void> pickTime(
      WidgetTester tester,
      String row,
    ) async {
      final tile = find.widgetWithText(AppleListTile, row);
      // The form scrolls: on a phone the time rows sit below the fold, and a
      // tap at their off-screen position lands on the footer underneath.
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      await tester.tap(find.widgetWithText(AppleFormButton, l.confirm).last);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsNothing);
    }

    bool confirmEnabled(WidgetTester tester) => tester
        .widget<AppleFormFooter>(find.byType(AppleFormFooter).first)
        .confirmEnabled;

    Future<void> selectFirstTimezone(WidgetTester tester) async {
      final first = tz.timeZoneDatabase.locations.keys.first;
      final zone = find.byType(DropdownButtonFormField<String>);
      // Picking the times scrolled the form down, so the field is back off
      // the top of the viewport by now.
      await tester.ensureVisible(zone);
      await tester.pumpAndSettle();
      await tester.tap(zone);
      await tester.pumpAndSettle();
      await tester.tap(find.text(first).last);
      await tester.pumpAndSettle();
      expect(find.text(first), findsOneWidget);
    }

    testWidgets('a new window needs a timezone, a day and a valid range',
        (tester) async {
      final results = await openSchedule(tester);

      expect(find.text(l.newSchedule), findsOneWidget);
      expect(confirmEnabled(tester), isFalse);

      await tester.tap(find.text(l.monday));
      await tester.pumpAndSettle();
      expect(confirmEnabled(tester), isFalse);

      await pickTime(tester, l.from);
      await pickTime(tester, l.to);
      expect(confirmEnabled(tester), isFalse);

      await selectFirstTimezone(tester);
      expect(confirmEnabled(tester), isTrue);

      await tester.tap(find.text(l.confirm));
      await tester.pumpAndSettle();

      final window = results.single;
      expect(window.timezone, tz.timeZoneDatabase.locations.keys.first);
      expect(window.weekday, ['mon']);
      expect(window.start, 0);
      expect(window.end, Duration(hours: 23, minutes: 59).inMilliseconds);
      expect(find.byType(BlockingScheduleModal), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an end before the start is refused with the reason shown',
        (tester) async {
      final results = await openSchedule(
        tester,
        schedule: EditBlockingSchedule(
          timezone: 'UTC',
          weekday: const ['mon'],
          start: Duration(hours: 22).inMilliseconds,
          end: Duration(hours: 6).inMilliseconds,
        ),
      );

      expect(find.text(l.editSchedule), findsOneWidget);
      expect(find.text(l.startTimeBeforeEndTime), findsOneWidget);
      expect(confirmEnabled(tester), isFalse);
      // "UTC" is not in the timezone database, yet the saved window must still
      // read back instead of leaving the field without a matching item.
      expect(find.text('UTC'), findsOneWidget);
      expect(
        find.widgetWithText(AppleListTile, l.from),
        findsOneWidget,
      );
      expect(find.text('22:00'), findsOneWidget);
      expect(find.text('06:00'), findsOneWidget);

      await tester.tap(find.text(l.confirm), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(results, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('editing copies the saved days so a cancel leaves them alone',
        (tester) async {
      final savedDays = <String>['mon'];
      final results = await openSchedule(
        tester,
        schedule: EditBlockingSchedule(
          timezone: 'UTC',
          weekday: savedDays,
          start: Duration(hours: 8).inMilliseconds,
          end: Duration(hours: 17).inMilliseconds,
        ),
      );

      expect(find.widgetWithText(AppleToggleChip, l.monday), findsOneWidget);
      await tester.tap(find.text(l.friday));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.monday));
      await tester.pumpAndSettle();
      expect(savedDays, ['mon']);
      expect(results, isEmpty);

      await tester.tap(find.byTooltip(l.close));
      await tester.pumpAndSettle();
      expect(find.byType(BlockingScheduleModal), findsNothing);
      expect(savedDays, ['mon']);
      expect(results, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('several days share one window', (tester) async {
      final results = await openSchedule(
        tester,
        schedule: EditBlockingSchedule(
          timezone: 'UTC',
          weekday: const ['mon'],
          start: Duration(hours: 8).inMilliseconds,
          end: Duration(hours: 17).inMilliseconds,
        ),
      );

      await tester.tap(find.text(l.friday));
      await tester.pumpAndSettle();
      expect(confirmEnabled(tester), isTrue);
      await tester.tap(find.text(l.confirm));
      await tester.pumpAndSettle();

      expect(results.single.weekday, ['mon', 'fri']);
      expect(results.single.start, Duration(hours: 8).inMilliseconds);
      expect(results.single.end, Duration(hours: 17).inMilliseconds);
      expect(tester.takeException(), isNull);
    });
  });

  group('schedule list', () {
    Future<List<BlockedServicesSchedule>> pumpList(
      WidgetTester tester,
      BlockedServicesSchedule schedule,
    ) async {
      final results = <BlockedServicesSchedule>[];
      var current = schedule;
      await pumpAppleApp(
        tester,
        // Stateful, the way the client form is: a delete has to re-render the
        // list from the schedule the callback handed back.
        body: (context) => StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: BlockingSchedule(
              blockedServicesSchedule: current,
              setBlockedServicesSchedule: (next) {
                results.add(next);
                setState(() => current = next);
              },
            ),
          ),
        ),
      );
      return results;
    }

    BlockedServicesSchedule scheduleWith(Map<String, dynamic> days) =>
        BlockedServicesSchedule.fromJson({
          'time_zone': 'UTC',
          'mon': null,
          'tue': null,
          'wed': null,
          'thu': null,
          'fri': null,
          'sat': null,
          'sun': null,
          ...days,
        });

    testWidgets('reads each window and deletes just the one asked for',
        (tester) async {
      final results = await pumpList(
        tester,
        scheduleWith({
          'mon': {'start': Duration(hours: 8).inMilliseconds, 'end': Duration(hours: 17).inMilliseconds},
          'fri': {'start': 0, 'end': Duration(hours: 6).inMilliseconds},
        }),
      );

      expect(find.text(l.pauseServiceBlocking), findsOneWidget);
      expect(find.text(l.add), findsOneWidget);
      expect(find.byType(AppleListTile), findsNWidgets(2));
      expect(find.text(l.monday), findsOneWidget);
      expect(find.text('08:00 - 17:00'), findsOneWidget);
      expect(find.text(l.friday), findsOneWidget);
      expect(find.text('00:00 - 06:00'), findsOneWidget);

      await tester.tap(find.byTooltip(l.delete).first);
      await tester.pumpAndSettle();

      final updated = results.single;
      expect(updated.mon, isNull);
      expect(updated.fri, isNotNull);
      expect(updated.timeZone, 'UTC');
      expect(find.byType(AppleListTile), findsOneWidget);
      expect(find.text(l.friday), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty schedule says so and still offers a new window',
        (tester) async {
      await pumpList(tester, scheduleWith({}));

      expect(find.byType(AppleEmptyState), findsOneWidget);
      expect(find.text(l.noBlockingScheduleThisDevice), findsOneWidget);
      expect(find.byType(AppleListTile), findsNothing);

      await tester.tap(find.text(l.add));
      await tester.pumpAndSettle();
      expect(find.text(l.newSchedule), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a row opens its own window in the editor', (tester) async {
      await pumpList(
        tester,
        scheduleWith({
          'fri': {'start': Duration(hours: 21).inMilliseconds, 'end': Duration(hours: 23).inMilliseconds},
        }),
      );

      await tester.tap(find.text(l.friday));
      await tester.pumpAndSettle();
      expect(find.text(l.editSchedule), findsOneWidget);
      expect(find.text('21:00'), findsOneWidget);
      expect(find.text('23:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
