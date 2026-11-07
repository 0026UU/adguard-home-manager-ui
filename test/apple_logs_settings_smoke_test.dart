import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/querylog_config.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/screens/settings/logs_settings/logs_settings.dart';
import 'package:adguard_home_manager/services/api_client.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'surface.dart';

class _LogsApiStub extends ApiClientV2 {
  _LogsApiStub({required super.server});

  bool succeeds = true;
  bool clearSucceeds = true;
  int clears = 0;
  final updates = <Map<String, dynamic>>[];

  @override
  Future<ApiResponse> getQueryLogInfo() async {
    await Future<void>.delayed(Duration.zero);
    if (!succeeds) return const ApiResponse(successful: false);
    return ApiResponse(
      successful: true,
      content: QueryLogConfig(
        enabled: true,
        interval: Duration(days: 1).inMilliseconds,
        anonymizeClientIp: false,
        ignored: const [],
      ),
    );
  }

  @override
  Future<ApiResponse> updateQueryLogParameters({
    required Map<String, dynamic> data,
  }) async {
    await Future<void>.delayed(Duration.zero);
    updates.add(data);
    return const ApiResponse(successful: true);
  }

  @override
  Future<ApiResponse> clearLogs() async {
    await Future<void>.delayed(Duration.zero);
    clears++;
    return clearSucceeds
      ? const ApiResponse(successful: true)
      : const ApiResponse(successful: false);
  }
}

Future<void> _pump(
  WidgetTester tester,
  _LogsApiStub api,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final servers = ServersProvider()
    ..setSelectedServer(Server(
      id: '1', name: 'Home', connectionMethod: 'http',
      domain: '192.168.1.10', port: 3000,
      defaultServer: true, runningOnHa: false,
    ))
    ..setApiClient2(api);

  setTestSurface(tester, const Size(390, 1200));

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
        home: const LogsSettings(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The bar button that empties the log.
///
/// It used to hide inside a Material overflow menu; the design layer puts the
/// destructive action on the bar itself and keeps the confirmation in front of
/// it, so the tooltip is the only handle the test has.
Finder clearButton(AppLocalizations l) => find.byTooltip(l.clearLogs);

/// The save button on the bar, as the control whose `onPressed` the page
/// holds shut while the draft is invalid.
///
/// [find.byTooltip] lands on the tooltip that wraps the button, so the button
/// itself has to be reached from it.
IconButton saveButton(WidgetTester tester, AppLocalizations l) =>
  tester.widget<IconButton>(
    find.ancestor(
      of: find.byTooltip(l.save),
      matching: find.byType(IconButton),
    ),
  );

/// The alert's destructive button.
///
/// [AppleSheetAction] is the data the alert is built from, not a widget, so
/// the tappable thing is the ink well wrapped around its label.
Finder alertButton(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(InkWell),
);

/// A screen of the design layer carries its title on the collapsing bar, so
/// the [Scaffold] underneath it must not have an app bar of its own.
void expectAppleScreen(WidgetTester tester, String title) {
  final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
  expect(scaffold.appBar, isNull);
  expect(find.byType(AppleScreen), findsOneWidget);
  expect(find.text(title), findsWidgets);
}

void main() {
  late AppLocalizations l;
  late _LogsApiStub api;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  // The save announces itself with the floating pill, which outlives the frame
  // the test ends on.
  tearDown(() => AppleToast.hide());

  setUp(() => api = _LogsApiStub(
    server: Server(
      id: '1', name: 'Home', connectionMethod: 'http',
      domain: '192.168.1.10', port: 3000,
      defaultServer: true, runningOnHa: false,
    ),
  ));

  testWidgets('the page is a screen of the design layer, not a Material bar',
      (tester) async {
    await _pump(tester, api);

    expectAppleScreen(tester, l.logsSettings);
    // The rows are the layer's grouped cards, and none of them is a Material
    // list row or card any more.
    expect(find.byType(AppleSwitchListTile), findsWidgets);
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(Card), findsNothing);
    expect(find.byType(PopupMenuButton), findsNothing);

    // The hub pushed this page, so it owes the user the way back.
    await tester.tap(find.byType(AppleBackButton));
    await tester.pumpAndSettle();
    expect(find.byType(LogsSettings), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing the log asks first and only writes on confirm',
      (tester) async {
    await _pump(tester, api);

    await tester.tap(clearButton(l));
    await tester.pumpAndSettle();

    // The tap that reaches for the trash must not be the tap that empties it.
    expect(api.clears, 0);
    expect(find.text(l.clearLogsConfirm), findsOneWidget);

    await tester.tap(alertButton(l.cancel));
    await tester.pumpAndSettle();
    expect(api.clears, 0);
    // The alert closes and the page stays: a button that pops the dialog for
    // its caller must not be popped again, or the page underneath leaves too.
    expect(find.byType(LogsSettings), findsOneWidget);

    await tester.tap(clearButton(l));
    await tester.pumpAndSettle();
    await tester.tap(alertButton(l.clearLogs));
    await tester.pumpAndSettle();

    expect(api.clears, 1);
    expect(find.byType(LogsSettings), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refused clear is reported instead of looking saved',
      (tester) async {
    api.clearSucceeds = false;
    await _pump(tester, api);

    await tester.tap(clearButton(l));
    await tester.pumpAndSettle();
    await tester.tap(alertButton(l.clearLogs));
    await tester.pumpAndSettle();

    expect(find.text(l.logsNotCleared), findsOneWidget);
    // The page still reports the refusal because it is still the page you are
    // on; a snackbar alone would show up even after the confirm popped it away.
    expect(find.byType(LogsSettings), findsOneWidget);
  });

  testWidgets('a page that could not be read offers to read it again',
      (tester) async {
    api.succeeds = false;
    await _pump(tester, api);

    expectAppleScreen(tester, l.logsSettings);
    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(find.text(l.logSettingsNotLoaded), findsOneWidget);
    expect(find.text(l.refresh), findsOneWidget);

    api.succeeds = true;
    await tester.tap(find.text(l.refresh));
    await tester.pumpAndSettle();

    expect(find.byType(AppleEmptyState), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('anonymizing the client address reaches the saved config',
      (tester) async {
    await _pump(tester, api);

    final row = find.widgetWithText(AppleSwitchListTile, l.anonymizeClientIp);
    expect(tester.widget<AppleSwitchListTile>(row).value, isFalse);

    await tester.ensureVisible(row);
    await tester.tap(
      find.descendant(of: row, matching: find.byType(CupertinoSwitch)),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<AppleSwitchListTile>(row).value, isTrue);

    await tester.tap(find.byTooltip(l.save));
    await tester.pumpAndSettle();

    // The row is a draft until the save button writes it, and what it writes
    // has to be the switch the page is showing.
    expect(api.updates, hasLength(1));
    expect(api.updates.single['anonymize_client_ip'], isTrue);
    expect(api.updates.single['enabled'], isTrue);
    expect(api.updates.single['interval'], Duration(days: 1).inMilliseconds);
    expect(api.updates.single['ignored'], isEmpty);
    expect(find.text(l.logsConfigUpdated), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a retention time that is not a number is not written',
      (tester) async {
    await _pump(tester, api);

    final field = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.custom).last);
    await tester.pumpAndSettle();

    final hours = find.widgetWithText(TextFormField, l.customTimeInHours);
    await tester.enterText(hours, '0');
    await tester.pumpAndSettle();

    expect(find.text(l.notLess1Hour), findsOneWidget);
    // The save is held shut while the draft is invalid, so nothing reaches the
    // server and the page keeps the values it read.
    expect(saveButton(tester, l).onPressed, isNull);

    await tester.enterText(hours, '12');
    await tester.pumpAndSettle();

    expect(saveButton(tester, l).onPressed, isNotNull);
    await tester.tap(find.byTooltip(l.save));
    await tester.pumpAndSettle();

    expect(api.updates.single['interval'], Duration(hours: 12).inMilliseconds);
    expect(tester.takeException(), isNull);
  });
}
