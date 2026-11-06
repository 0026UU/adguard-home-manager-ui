import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/settings/settings.dart';
import 'package:adguard_home_manager/screens/settings/diagnostics/diagnostics_log_screen.dart';
import 'package:adguard_home_manager/models/app_log.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/custom_list_tile.dart';
import 'package:adguard_home_manager/widgets/custom_switch_list_tile.dart';

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
    await tester.binding.setSurfaceSize(const Size(420, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    expect(find.text(l.queryLogSettings), findsOneWidget);
    expect(find.text(l.autoRefreshLiveLogs), findsOneWidget);
    expect(find.text(l.statusColorUseThemeColor), findsOneWidget);
    expect(find.text(l.hideServerAddress), findsOneWidget);
    expect(find.text(l.openSourceLicenses), findsOneWidget);
    expect(find.text(l.diagnosticsLog), findsOneWidget);
    expect(find.text(l.customization), findsNothing);
    expect(find.text(l.generalSettings), findsNothing);
    expect(find.text(l.advancedSettings), findsNothing);
    // App settings and about rows carry the tinted glyphs; the appearance
    // rows do not.
    expect(find.byType(AppleIconBadge), findsNWidgets(8));
    // The page signs itself with the app and the version it runs; the note
    // sits under the last group, out of the phone's first screen.
    expect(
      find.text(l.unofficialClient, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('the appearance group switches the theme from inside its card',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pump(tester, const Settings());

    final context = tester.element(find.byType(Settings));
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);

    AppleListTile accentRow() => tester.widget<AppleListTile>(find.ancestor(
          of: find.text(l.accentColor),
          matching: find.byType(AppleListTile),
        ));

    // The Apple theme keeps the system tint, so there is nothing to pick.
    expect(accentRow().value, l.systemBlue);
    expect(accentRow().onTap, isNull);

    await tester.tap(find.text(l.accentColor));
    await tester.pumpAndSettle();

    // A row with nothing to pick does not open the sheet, so its title is
    // still the only one on screen.
    expect(find.text(l.accentColor), findsOneWidget);
    expect(tester.takeException(), isNull);

    // With the classic theme back on, the same row opens the swatches.
    await appConfigProvider.setUseAppleStyle(false);
    await tester.pumpAndSettle();

    expect(accentRow().onTap, isNotNull);

    await tester.tap(find.text(l.accentColor));
    await tester.pumpAndSettle();

    // The sheet puts the same title above its own list.
    expect(find.text(l.accentColor), findsNWidgets(2));

    await tester.tap(find.text(l.indigo));
    await tester.pumpAndSettle();

    expect(appConfigProvider.staticColor, 11);
    expect(accentRow().value, l.indigo);
  });

  testWidgets('the master pane marks the selected section', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    await tester.tap(switchFor(l.statusColorUseThemeColor));
    await tester.pumpAndSettle();
    expect(appConfigProvider.useThemeColorForStatus, isTrue);

    // The two rows read the one pref the appearance sheet writes as well.
    final statusRow = tester.widget<AppleListTile>(find.ancestor(
      of: find.text(l.statusColors),
      matching: find.byType(AppleListTile),
    ));
    expect(statusRow.value, l.themeColorForStatus);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('autoRefreshLiveLogs'), isFalse);
    expect(prefs.getBool('useThemeColorForStatus'), isTrue);
  });

  testWidgets('the rows that read the server wait for one', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    // The three that were here plus the one that hides the address.
    expect(find.byType(CupertinoSwitch), findsNWidgets(4));
    // There is nothing to read again until a server is connected.
    expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the diagnostics page shows what the app wrote down',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
      Material(
        child: CustomSwitchListTile(
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
        child: CustomListTile(
          title: 'Query logs',
          subtitle: 'Saved on the server',
          disabled: true,
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
