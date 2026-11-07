import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/load_status_widgets.dart';

Future<void> _pump(WidgetTester tester, Widget home,
    {bool settle = true}) async {
  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(
    MaterialApp(
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
  );

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // The activity indicator never settles, so step a fixed frame instead.
    await tester.pump();
  }
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the load placeholders use the Apple widgets', (tester) async {
    await _pump(
      tester,
      Column(
        children: [
          const SizedBox(height: 200, child: LoadingData(text: 'Loading')),
          Expanded(child: ErrorLoadData(text: l.logSettingsNotLoaded)),
        ],
      ),
      settle: false,
    );

    expect(find.byType(AppleLoading), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(find.text(l.logSettingsNotLoaded), findsOneWidget);
    expect(find.byIcon(Icons.error), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // The design layer writes its group captions in the case of the words
  // themselves rather than the small caps iOS uses, and all three header
  // widgets draw the same caption, so they have to agree on it.
  testWidgets('the group headers keep the case they are given', (tester) async {
    await _pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              const AppleGroupHeader(title: 'Custom rules'),
              const AppleFormGroupLabel('Custom rules'),
              AppleListSection(
                title: 'Custom rules',
                children: const [AppleListTile(title: 'A rule')],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('CUSTOM RULES'), findsNothing);
    expect(find.text('Custom rules'), findsNWidgets(3));

    final styles = tester
      .widgetList<Text>(find.text('Custom rules'))
      .map((text) => text.style!)
      .toList();

    for (final style in styles) {
      expect(style.fontSize, 13);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.letterSpacing, 0.2);
    }
  });
}
