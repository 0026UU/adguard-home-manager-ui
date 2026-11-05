import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/screens/filters/modals/custom_rules/edit_custom_rules.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

// The editor writes through `/filtering/set_rules`, which no test can reach, so
// the caller hands in an `onConfirm` and reads back the lines the page
// produced. The provider here only supplies what the field opens with.

/// The rules the server already keeps.
const List<String> rulesFixture = [
  '||ads.example.org^',
  '@@allowed.example.org',
  '! comment line',
];

/// Pushes the editor over a page, the way the filters tab does, so the back
/// capsule has a route to be named after.
Future<void> pumpRulesEditor(
  WidgetTester tester, {
  void Function(List<String>)? onConfirm,
  List<String> rules = rulesFixture,
  Brightness brightness = Brightness.light,
  Size surface = const Size(390, 844),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final appConfigProvider = AppConfigProvider(sharedPreferencesInstance: prefs);
  final filteringProvider = FilteringProvider()
    ..setFilteringData(Filtering(
      filters: const [],
      whitelistFilters: const [],
      userRules: rules,
      blockedServices: const [],
      interval: 24,
      enabled: true,
    ));

  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appConfigProvider),
        ChangeNotifierProvider.value(value: filteringProvider),
      ],
      child: MaterialApp(
        navigatorKey: globalNavigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        theme: appleTheme(brightness),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EditCustomRules(
                      onConfirm: onConfirm ?? (_) {},
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The page is one long scroll: the field is above the fold, the footer is not.
Future<void> scrollToRulesFooter(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byType(AppleFormFooter),
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// What the field holds, read from the controller the page owns.
String rulesFieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;
