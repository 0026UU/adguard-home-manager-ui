import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/floating_search_bar.dart';
import 'package:adguard_home_manager/widgets/load_status_widgets.dart';

late BuildContext _hostContext;

Future<void> _pump(WidgetTester tester, Widget home,
    {bool settle = true}) async {
  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(
    MaterialApp(
      // The floating field reads the view padding from the app navigator.
      navigatorKey: globalNavigatorKey,
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

  testWidgets('the floating field keeps the previous term and reports typing',
      (tester) async {
    final updates = <String>[];
    String? completed;

    await _pump(
      tester,
      Builder(
        builder: (context) {
          _hostContext = context;
          return const SizedBox.shrink();
        },
      ),
    );

    showDialog(
      context: _hostContext,
      builder: (context) => FloatingSearchBar(
        searchButtonRenderBox: null,
        existingSearchValue: 'example',
        onSearchFieldUpdated: updates.add,
        onSearchCompleted: (value) => completed = value,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppleSearchField), findsOneWidget);
    expect(find.text('example'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'example.com');
    await tester.pump();

    expect(updates, ['example.com']);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(completed, 'example.com');
    expect(find.byType(FloatingSearchBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the floating field clears through the search primitive',
      (tester) async {
    final updates = <String>[];

    await _pump(
      tester,
      Builder(
        builder: (context) {
          _hostContext = context;
          return const SizedBox.shrink();
        },
      ),
    );

    showDialog(
      context: _hostContext,
      builder: (context) => FloatingSearchBar(
        searchButtonRenderBox: null,
        existingSearchValue: 'old term',
        onSearchFieldUpdated: updates.add,
        onSearchCompleted: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
    await tester.pumpAndSettle();

    // The field reports the clear as an empty update, which is what the
    // log filters already treat as "no search".
    expect(updates, ['']);
    expect(find.text('old term'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap outside the floating field closes it', (tester) async {
    await _pump(
      tester,
      Builder(
        builder: (context) {
          _hostContext = context;
          return const SizedBox.shrink();
        },
      ),
    );

    showDialog(
      barrierDismissible: false,
      context: _hostContext,
      builder: (context) => FloatingSearchBar(
        searchButtonRenderBox: null,
        onSearchCompleted: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(20, 400));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingSearchBar), findsNothing);
    expect(tester.takeException(), isNull);
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
}
