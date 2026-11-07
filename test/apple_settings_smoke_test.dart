import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/classes/http_override.dart';
import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/settings/settings.dart';
import 'package:adguard_home_manager/screens/settings/diagnostics/diagnostics_log_screen.dart';
import 'package:adguard_home_manager/models/app_log.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'surface.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppConfigProvider(sharedPreferencesInstance: prefs)),
        ChangeNotifierProvider(create: (_) => ServersProvider()),
        ChangeNotifierProvider(create: (_) => StatusProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appleLightTheme(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('settings groups its rows into inset sections', (tester) async {
    // Tall enough that every group is laid out and on the page at once: the
    // list disposes what a short screen pushes past its cache.
    setTestSurface(tester, const Size(420, 1300));

    await _pump(tester, const Settings());

    expect(tester.takeException(), isNull);
    // The look of the app is a group of its own, above the app and the about
    // ones; the server group only appears with a server that answers.
    expect(find.byType(AppleListSection), findsNWidgets(3));
    expect(find.text(l.appSettings), findsOneWidget);
    expect(find.text(l.appearance), findsOneWidget);
    expect(find.text(l.aboutApp), findsOneWidget);
    expect(find.text(l.serverSettings), findsNothing);
    // The rows the design puts in the app group and the about one, and
    // nothing else.
    expect(find.text(l.language), findsOneWidget);
    expect(find.text(l.statisticsAndDashboard), findsOneWidget);
    expect(find.text(l.topItemsOrder), findsOneWidget);
    expect(find.text(l.queryLogSettings), findsOneWidget);
    expect(find.text(l.autoRefreshLiveLogs), findsOneWidget);
    expect(find.text(l.dontCheckCertificate), findsOneWidget);
    // One control per setting: the appearance sheet owns the status colours,
    // so a second switch for the same preference would read as a different one.
    expect(find.text(l.statusColorUseThemeColor), findsNothing);
    expect(find.text(l.hideServerAddress), findsOneWidget);
    expect(find.text(l.openSourceLicenses), findsOneWidget);
    expect(find.text(l.diagnosticsLog), findsOneWidget);
    expect(find.text(l.customization), findsNothing);
    expect(find.text(l.generalSettings), findsNothing);
    expect(find.text(l.advancedSettings), findsNothing);
    // App settings and about rows carry the tinted glyphs; the appearance
    // rows do not.
    expect(find.byType(AppleIconBadge), findsNWidgets(9));
    // The page signs itself with the app and the version it runs; the note
    // sits under the last group, out of the phone's first screen.
    expect(
      find.text(l.unofficialClient, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('the appearance group switches the theme from inside its card',
      (tester) async {
    setTestSurface(tester, const Size(420, 900));

    await _pump(tester, const Settings());

    final context = tester.element(find.byType(Settings));
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);

    final segment = tester.widget<AppleSegmented>(find.byType(AppleSegmented));
    expect(segment.labels, [l.autoTheme, l.light, l.dark]);
    expect(segment.selectedIndex, 0);
    expect(appConfigProvider.selectedThemeNumber, 0);

    await tester.tap(find.text(l.dark));
    await tester.pumpAndSettle();

    expect(appConfigProvider.selectedThemeNumber, 2);
    expect(appConfigProvider.selectedTheme, ThemeMode.dark);

    await tester.tap(find.text(l.light));
    await tester.pumpAndSettle();

    expect(appConfigProvider.selectedThemeNumber, 1);
    // The choice is kept, the way the other settings are.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('selectedTheme'), 1);
  });

  testWidgets('the status colours follow the server until the theme is asked for',
      (tester) async {
    setTestSurface(tester, const Size(420, 900));

    await _pump(tester, const Settings());

    final context = tester.element(find.byType(Settings));
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);

    AppleListTile statusRow() => tester.widget<AppleListTile>(find.ancestor(
          of: find.text(l.statusColors),
          matching: find.byType(AppleListTile),
        ));

    expect(statusRow().value, l.semanticColors);

    await tester.tap(find.text(l.statusColors));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.themeColorForStatus));
    await tester.pumpAndSettle();

    expect(appConfigProvider.useThemeColorForStatus, isTrue);
    expect(statusRow().value, l.themeColorForStatus);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('useThemeColorForStatus'), isTrue);
  });

  testWidgets('the accent row names the tint the theme actually uses',
      (tester) async {
    setTestSurface(tester, const Size(420, 900));

    await _pump(tester, const Settings());

    AppleListTile accentRow() => tester.widget<AppleListTile>(find.ancestor(
          of: find.text(l.accentColor),
          matching: find.byType(AppleListTile),
        ));

    // The theme keeps the system tint, so there is nothing to pick: the
    // swatch sheet belonged to the Material skin and is gone with it.
    expect(accentRow().value, l.systemBlue);
    expect(accentRow().onTap, isNull);

    await tester.tap(find.text(l.accentColor));
    await tester.pumpAndSettle();

    // A row with nothing to pick does not open the sheet, so its title is
    // still the only one on screen.
    expect(find.text(l.accentColor), findsOneWidget);
    expect(find.text(l.indigo), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the master pane marks the selected section', (tester) async {
    setTestSurface(tester, const Size(1200, 800));

    await _pump(tester, const Settings());

    final context = tester.element(find.byType(Settings));
    Provider.of<AppConfigProvider>(context, listen: false)
        .setSelectedSettingsScreen(screen: 1, notify: true);
    await tester.pumpAndSettle();

    final tile = tester.widget<AppleListTile>(find.ancestor(
      of: find.text(l.statisticsAndDashboard),
      matching: find.byType(AppleListTile),
    ));
    expect(tile.selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the app group keeps the switches the app owns', (tester) async {
    setTestSurface(tester, const Size(420, 900));

    await _pump(tester, const Settings());

    final context = tester.element(find.byType(Settings));
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);

    Finder switchFor(String title) => find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(AppleSwitchListTile),
          ),
          matching: find.byType(CupertinoSwitch),
        );

    expect(appConfigProvider.autoRefreshLiveLogs, isTrue);
    expect(appConfigProvider.useThemeColorForStatus, isFalse);

    await tester.tap(switchFor(l.autoRefreshLiveLogs));
    await tester.pumpAndSettle();
    expect(appConfigProvider.autoRefreshLiveLogs, isFalse);

    // The status colours are written by the appearance sheet alone; this row
    // only reads the preference back.
    final statusRow = tester.widget<AppleListTile>(find.ancestor(
      of: find.text(l.statusColors),
      matching: find.byType(AppleListTile),
    ));
    expect(statusRow.value, l.semanticColors);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('autoRefreshLiveLogs'), isFalse);
  });

  testWidgets('the certificate override applies to the next request',
      (tester) async {
    // Tall enough to keep the whole app group on the page: the switch this
    // test taps sits below the fold at phone height.
    setTestSurface(tester, const Size(420, 1300));
    addTearDown(() => HttpOverrides.global = null);

    await _pump(tester, const Settings());

    final context = tester.element(find.byType(Settings));
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);

    // [main] installs the override once at startup, so a session that began
    // without it has to be able to gain it without a restart. Under the test
    // binding dart:io answers with its own mock client instead of nothing, so
    // "began without it" is read as "not the app's override yet".
    expect(HttpOverrides.current, isNot(isA<MyHttpOverrides>()));

    await tester.tap(find.descendant(
      of: find.ancestor(
        of: find.text(l.dontCheckCertificate),
        matching: find.byType(AppleSwitchListTile),
      ),
      matching: find.byType(CupertinoSwitch),
    ));
    await tester.pumpAndSettle();

    expect(appConfigProvider.overrideSslCheck, isTrue);
    expect(HttpOverrides.current, isA<MyHttpOverrides>());

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('overrideSslCheck'), isTrue);

    await tester.tap(find.descendant(
      of: find.ancestor(
        of: find.text(l.dontCheckCertificate),
        matching: find.byType(AppleSwitchListTile),
      ),
      matching: find.byType(CupertinoSwitch),
    ));
    await tester.pumpAndSettle();

    expect(appConfigProvider.overrideSslCheck, isFalse);
    expect(HttpOverrides.current, isNull);
  });

  testWidgets('the rows that read the server wait for one', (tester) async {
    setTestSurface(tester, const Size(420, 900));

    await _pump(tester, const Settings());

    // Nothing is known about the query log until a server answers, so its
    // switch is drawn but cannot write; DHCP, which belongs to the server
    // group, is not on this page at all yet.
    final queryLogRow = tester.widget<AppleListTile>(find.ancestor(
      of: find.text(l.queryLogSettings),
      matching: find.byType(AppleListTile),
    ));
    final control = queryLogRow.trailing as AppleSwitch;
    expect(control.value, isFalse);
    expect(control.onChanged, isNull);

    expect(find.text(l.dhcpSettings), findsNothing);
    // Live logs, the query log page's own switch, hiding the address, and the
    // certificate override.
    expect(find.byType(CupertinoSwitch), findsNWidgets(4));
    // There is nothing to read again until a server is connected.
    expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the diagnostics page shows what the app wrote down',
      (tester) async {
    setTestSurface(tester, const Size(420, 900));

    await _pump(tester, const DiagnosticsLogScreen());

    final context = tester.element(find.byType(DiagnosticsLogScreen));
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);

    // Nothing has gone wrong, so nothing is listed.
    expect(find.text(l.noDiagnosticsLog), findsOneWidget);

    appConfigProvider.addLog(
      AppLog(
        type: 'get_status',
        dateTime: DateTime(2026, 1, 1, 12),
        message: 'SocketException',
        statusCode: '500',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l.noDiagnosticsLog), findsNothing);
    expect(find.text('SocketException'), findsOneWidget);
    expect(find.textContaining('get_status'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switch rows use the iOS control and toggle from the row', (tester) async {
    var value = false;

    await _pump(
      tester,
      // The live idiom (logs filters, client detail): an opaque gesture
      // detector wraps the row, so the whole row toggles and the switch
      // itself still wins the arena where it is hit.
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => value = !value,
        child: AppleSwitchListTile(
          value: value,
          title: 'Blocking status',
          subtitle: 'Write blocked queries in the log file',
          onChanged: (next) => value = next,
        ),
      ),
    );

    expect(find.byType(CupertinoSwitch), findsOneWidget);

    await tester.tap(find.text('Blocking status'));
    await tester.pumpAndSettle();

    expect(value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a disabled shared row does not fire its action', (tester) async {
    var tapped = false;

    await _pump(
      tester,
      Material(
        child: AppleListTile(
          title: 'Query logs',
          subtitle: 'Saved on the server',
          enabled: false,
          showChevron: false,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.byType(AppleListTile), findsOneWidget);

    await tester.tap(find.text('Query logs'));
    await tester.pumpAndSettle();

    expect(tapped, isFalse);
    expect(tester.takeException(), isNull);
  });
}
