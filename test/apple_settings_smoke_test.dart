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
    await tester.binding.setSurfaceSize(const Size(420, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pump(tester, const Settings());

    expect(tester.takeException(), isNull);
    expect(find.byType(AppleListSection), findsNWidgets(2));
    // The server group is hidden until a server is connected.
    expect(find.text(l.appSettings.toUpperCase()), findsOneWidget);
    expect(find.text(l.customization), findsOneWidget);
    // App settings rows carry the tinted glyphs; the about group does not.
    expect(find.byType(AppleIconBadge), findsNWidgets(5));
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
