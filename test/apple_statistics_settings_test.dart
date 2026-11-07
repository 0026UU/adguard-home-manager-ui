import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/models/statistics_config.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/screens/settings/statistics_settings/statistics_settings.dart';
import 'package:adguard_home_manager/services/api_client.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'surface.dart';

// The page reads `/stats/config` and writes the same route back, so the only
// thing a test can hold it to is what lands in that write body.

class _StatisticsApiStub extends ApiClientV2 {
  _StatisticsApiStub({required super.server});

  bool readSucceeds = true;
  bool enabled = true;
  int intervalMs = Duration(days: 1).inMilliseconds;
  List<String> ignored = const [];
  final writes = <Map<String, dynamic>>[];

  @override
  Future<ApiResponse> getStatisticsConfig() async {
    await Future<void>.delayed(Duration.zero);
    if (!readSucceeds) return const ApiResponse(successful: false);
    return ApiResponse(
      successful: true,
      content: StatisticsConfig(
        enabled: enabled,
        interval: intervalMs,
        ignored: ignored,
      ),
    );
  }

  @override
  Future<ApiResponse> updateStatisticsSettings({
    required Map<String, dynamic> body,
  }) async {
    await Future<void>.delayed(Duration.zero);
    writes.add(body);
    return const ApiResponse(successful: true);
  }
}

Future<void> _pump(
  WidgetTester tester,
  _StatisticsApiStub api, {
  Size surface = const Size(390, 1200),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final servers = ServersProvider()
    ..setSelectedServer(Server(
      id: '1', name: 'Home', connectionMethod: 'http',
      domain: '192.168.1.10', port: 3000,
      defaultServer: true, runningOnHa: false,
    ))
    ..setApiClient2(api);

  setTestSurface(tester, surface);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfigProvider>.value(
          value: AppConfigProvider(sharedPreferencesInstance: prefs),
        ),
        ChangeNotifierProvider<ServersProvider>.value(value: servers),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: globalNavigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        theme: appleLightTheme(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StatisticsSettings(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens the retention field and picks the entry labelled [label].
Future<void> pickRetention(WidgetTester tester, String label) async {
  final field = find.byType(DropdownButtonFormField<String>);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();

  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l;
  late _StatisticsApiStub api;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  // Saving announces itself with the floating pill, which outlives the frame
  // the test ends on.
  tearDown(() => AppleToast.hide());

  setUp(() => api = _StatisticsApiStub(
    server: Server(
      id: '1', name: 'Home', connectionMethod: 'http',
      domain: '192.168.1.10', port: 3000,
      defaultServer: true, runningOnHa: false,
    ),
  ));

  testWidgets('the page shows what the server keeps', (tester) async {
    await _pump(tester, api);

    expect(find.byType(AppleScreen), findsOneWidget);
    // The collapsing header draws the name twice: once big, once in the bar.
    expect(find.text(l.statisticsSettings), findsWidgets);

    final enable = find.widgetWithText(AppleSwitchListTile, l.enableLog);
    expect(tester.widget<AppleSwitchListTile>(enable).value, isTrue);

    // 86400000 ms is the day entry, and the empty list is a caption rather
    // than the big empty state the page reserves for a failed read.
    expect(find.text(l.hours24), findsOneWidget);
    expect(find.text(l.noIgnoredDomainsAdded), findsOneWidget);
    expect(find.byType(AppleEmptyState), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a retention picked from the field reaches the write',
      (tester) async {
    await _pump(tester, api);

    await pickRetention(tester, l.days7);

    final enable = find.widgetWithText(AppleSwitchListTile, l.enableLog);
    await tester.ensureVisible(enable);
    await tester.tap(
      find.descendant(of: enable, matching: find.byType(CupertinoSwitch)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(l.save));
    await tester.pumpAndSettle();

    expect(api.writes, hasLength(1));
    expect(api.writes.single['interval'], Duration(days: 7).inMilliseconds);
    expect(api.writes.single['enabled'], isFalse);
    expect(api.writes.single['ignored'], isEmpty);
    expect(find.text(l.statisticsConfigUpdated), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a custom number of hours is written in milliseconds',
      (tester) async {
    await _pump(tester, api);

    await pickRetention(tester, l.custom);
    // The field the dropdown hides until "custom" is chosen.
    final hours = find.widgetWithText(TextFormField, l.customTimeInHours);
    await tester.enterText(hours, '12');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(l.save));
    await tester.pumpAndSettle();

    expect(api.writes.single['interval'], Duration(hours: 12).inMilliseconds);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a config that could not be read offers to be read again',
      (tester) async {
    api.readSucceeds = false;
    await _pump(tester, api);

    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(find.text(l.statisticsSettingsLoadError), findsOneWidget);

    api.readSucceeds = true;
    await tester.tap(find.text(l.refresh));
    await tester.pumpAndSettle();

    expect(find.byType(AppleEmptyState), findsNothing);
    expect(find.text(l.hours24), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
