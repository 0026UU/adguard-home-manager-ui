import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/models/safe_search.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/screens/clients/client/client_screen.dart';

import 'surface.dart';

// The add/edit form of one device in the Apple layer: an inset-grouped page on
// a phone, a centred card on the wide layouts.
//
// Regenerate with:
//   flutter test --update-goldens test/apple_client_form_golden_test.dart

Client _client() => Client(
      name: 'Living Room',
      ids: const ['192.168.1.2'],
      tags: const ['device_laptop'],
      upstreams: const [],
      rules: const [],
      filteringEnabled: true,
      parentalEnabled: false,
      safebrowsingEnabled: true,
      useGlobalBlockedServices: false,
      useGlobalSettings: false,
      blockedServices: const ['svc_1'],
      safeSearch: SafeSearch(
        enabled: true,
        bing: false,
        duckduckgo: true,
        ecosia: false,
        google: true,
        pixabay: false,
        yandex: false,
        youtube: false,
      ),
      ignoreQuerylog: false,
      ignoreStatistics: true,
      upstreamsCacheEnabled: true,
      upstreamsCacheSize: 4096,
      blockedServicesSchedule: BlockedServicesSchedule.fromJson({
        'time_zone': 'Europe/Madrid',
        'mon': {
          'start': Duration(hours: 8).inMilliseconds,
          'end': Duration(hours: 17).inMilliseconds,
        },
      }),
    );

Future<void> _pump(
  WidgetTester tester, {
  required Size surface,
  required bool fullScreen,
  Brightness brightness = Brightness.light,
}) async {
  setTestSurface(tester, surface);

  final clients = ClientsProvider();
  addTearDown(clients.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<ClientsProvider>.value(
      value: clients,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme:
            brightness == Brightness.dark ? appleDarkTheme() : appleLightTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClientScreen(
          fullScreen: fullScreen,
          client: _client(),
          onConfirm: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('the edit page on a phone', (tester) async {
    await _pump(
      tester,
      surface: const Size(390, 844),
      fullScreen: true,
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/client_form_phone_light.png'),
    );
  });

  testWidgets('the edit page in the dark palette', (tester) async {
    await _pump(
      tester,
      surface: const Size(390, 844),
      fullScreen: true,
      brightness: Brightness.dark,
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/client_form_phone_dark.png'),
    );
  });

  testWidgets('the edit form as a card on a wide layout', (tester) async {
    await _pump(
      tester,
      surface: const Size(900, 900),
      fullScreen: false,
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/client_form_card_light.png'),
    );
  });
}
