import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:adguard_home_manager/models/safe_search.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/screens/clients/client/blocking_schedule.dart';
import 'package:adguard_home_manager/screens/clients/client/blocking_schedule_modal.dart';
import 'package:adguard_home_manager/screens/clients/client/safe_search_modal.dart';
import 'package:adguard_home_manager/screens/clients/client/services_modal.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'client_modals_harness.dart';

// The three device pickers in the Apple layer: a checkbox list for the blocked
// services, a master switch with its engines for safe search, and the schedule
// editor with its weekday chips and hour rows.
//
// Regenerate with:
//   flutter test --update-goldens test/apple_client_modals_golden_test.dart

Future<void> _open(
  WidgetTester tester, {
  required Widget modal,
  required Size surface,
  required bool dialog,
  Brightness brightness = Brightness.light,
  List<SingleChildWidget> providers = const [],
}) async {
  await pumpAppleApp(
    tester,
    surface: surface,
    brightness: brightness,
    providers: providers,
    body: (context) => AppleButton(
      label: 'Open',
      onPressed: () => dialog
          ? showDialog<void>(context: context, builder: (_) => modal)
          : showModalBottomSheet<void>(
              context: context,
              useRootNavigator: true,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Colors.transparent,
              builder: (_) => modal,
            ),
    ),
  );

  await tester.tap(find.text('Open'));
  await settleRoute(tester);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

/// A loaded catalog for the services picker, owned by the calling test.
List<SingleChildWidget> _catalogProviders() {
  final catalog = StubFiltering(services: serviceCatalog(8));
  addTearDown(catalog.dispose);
  return [ChangeNotifierProvider<FilteringProvider>.value(value: catalog)];
}

void main() {
  final selected = ['svc_1', 'svc_3'];

  SafeSearch safeSearch() => SafeSearch(
        enabled: true,
        bing: false,
        duckduckgo: true,
        ecosia: false,
        google: true,
        pixabay: false,
        yandex: false,
        youtube: false,
      );

  testWidgets('the services sheet on a phone', (tester) async {
    await _open(
      tester,
      surface: const Size(390, 844),
      dialog: false,
      providers: _catalogProviders(),
      modal: ServicesModal(
        dialog: false,
        blockedServices: selected,
        onConfirm: (_) {},
      ),
    );

    expect(find.byType(AppleFormModal), findsOneWidget);
    expect(isChecked(tester, 'Service 1'), isTrue);
    expect(isChecked(tester, 'Service 2'), isFalse);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/client_services_phone_light.png'),
    );
  });

  testWidgets('the services sheet in the dark palette', (tester) async {
    await _open(
      tester,
      surface: const Size(390, 844),
      dialog: false,
      brightness: Brightness.dark,
      providers: _catalogProviders(),
      modal: ServicesModal(
        dialog: false,
        blockedServices: selected,
        onConfirm: (_) {},
      ),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/client_services_phone_dark.png'),
    );
  });

  testWidgets('the services picker as a card on a wide layout', (tester) async {
    await _open(
      tester,
      surface: const Size(900, 900),
      dialog: true,
      providers: _catalogProviders(),
      modal: ServicesModal(
        dialog: true,
        blockedServices: selected,
        onConfirm: (_) {},
      ),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/client_services_card_light.png'),
    );
  });

  testWidgets('the safe search sheet on a phone', (tester) async {
    await _open(
      tester,
      surface: const Size(390, 844),
      dialog: false,
      modal: SafeSearchModal(
        dialog: false,
        safeSearch: safeSearch(),
        onConfirm: (_) {},
      ),
    );

    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
      isTrue,
    );
    expect(isChecked(tester, 'Google'), isTrue);
    expect(isChecked(tester, 'YouTube'), isFalse);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/client_safe_search_phone_light.png'),
    );
  });

  testWidgets('the schedule editor as a card on a wide layout', (tester) async {
    await _open(
      tester,
      surface: const Size(900, 900),
      dialog: true,
      modal: BlockingScheduleModal(
        schedule: EditBlockingSchedule(
          timezone: 'Europe/Madrid',
          weekday: const ['mon', 'fri'],
          start: Duration(hours: 8).inMilliseconds,
          end: Duration(hours: 17).inMilliseconds,
        ),
        onConfirm: (_) {},
      ),
    );

    expect(find.byType(AppleToggleChip), findsNWidgets(7));
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('17:00'), findsOneWidget);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/client_schedule_card_light.png'),
    );
  });
}
