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

// The appearance group is the only settings card that carries a control
// instead of a row, so the golden keeps the segment, its label and the two
// value rows below it in one frame.
//
// Regenerate with: flutter test --update-goldens test/apple_settings_golden_test.dart

Future<void> _pump(WidgetTester tester, Size surface) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfigProvider>(
            create: (_) =>
                AppConfigProvider(sharedPreferencesInstance: prefs)),
        ChangeNotifierProvider<ServersProvider>(create: (_) => ServersProvider()),
        ChangeNotifierProvider<StatusProvider>(create: (_) => StatusProvider()),
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
        home: const Settings(),
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

  testWidgets('the appearance card is drawn as one group', (tester) async {
    await _pump(tester, const Size(390, 760));

    expect(find.text(l.appearance), findsOneWidget);
    expect(find.byType(AppleSegmented), findsOneWidget);
    expect(find.text(l.autoTheme), findsOneWidget);
    expect(find.text(l.accentColor), findsOneWidget);
    expect(find.text(l.statusColors), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/settings_appearance.png'),
    );
  });

  testWidgets('the card marks the theme that is in use', (tester) async {
    await _pump(tester, const Size(390, 760));

    await tester.tap(find.text(l.dark));
    await tester.pumpAndSettle();

    expect(
      tester.widget<AppleSegmented>(find.byType(AppleSegmented)).selectedIndex,
      2,
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/settings_appearance_dark.png'),
    );
  });

  // The whole page at once: the look group, the app group with its switches
  // and the about group, which is everything a phone shows before a server
  // has answered.
  testWidgets('the groups are drawn in the order the design gives them',
      (tester) async {
    await _pump(tester, const Size(390, 1180));

    expect(find.text(l.appSettings), findsOneWidget);
    expect(find.text(l.aboutApp), findsOneWidget);
    expect(find.text(l.unofficialClient), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/settings_page.png'),
    );
  });
}
