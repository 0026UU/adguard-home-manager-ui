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
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pump(tester, const Settings());

    expect(tester.takeException(), isNull);
    // The look of the app is a group of its own, above the server one.
    expect(find.byType(AppleListSection), findsNWidgets(3));
    expect(find.text(l.appSettings.toUpperCase()), findsOneWidget);
    expect(find.text(l.appearance.toUpperCase()), findsOneWidget);
    expect(find.text(l.customization), findsOneWidget);
    // App settings rows carry the tinted glyphs; the appearance rows do not.
    expect(find.byType(AppleIconBadge), findsNWidgets(5));
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
        .setSelectedSettingsScreen(screen: 13, notify: true);
    await tester.pumpAndSettle();

    final tile = tester.widget<AppleListTile>(find.ancestor(
      of: find.text(l.generalSettings),
      matching: find.byType(AppleListTile),
    ));
    expect(tile.selected, isTrue);
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
