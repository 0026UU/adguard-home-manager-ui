import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/screens/settings/general_settings/top_items_list/reorderable_top_items_home.dart';
import 'package:adguard_home_manager/screens/settings/general_settings/top_items_list/show_hide_top_items_list.dart';
import 'package:adguard_home_manager/screens/settings/general_settings/top_items_list/top_items_list_settings.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'surface.dart';

// What the dashboard shows, and in what sequence, is one stored list, so the
// only write this page has is AppConfigProvider.setHomeTopItemsOrder. The tests
// read that list back out of storage: a page that only moved its own rows
// around would look right and change nothing.

const List<String> _fullOrder = [
  'queriedDomains',
  'blockedDomains',
  'recurrentClients',
];

/// An app configuration whose storage refuses the write, the one way this page
/// can fail.
class _RefusingAppConfig extends AppConfigProvider {
  _RefusingAppConfig({required super.sharedPreferencesInstance});

  int attempts = 0;

  @override
  Future<bool> setHomeTopItemsOrder(List<HomeTopItems> order) async {
    attempts++;
    return false;
  }
}

class _TopItemsHarness {
  _TopItemsHarness(this.prefs, this.appConfig);

  final SharedPreferences prefs;
  final AppConfigProvider appConfig;

  List<String> get stored =>
      appConfig.homeTopItemsOrder.map((e) => e.name).toList();

  List<String> get onDisk =>
      prefs.getStringList('homeTopItemsOrder') ?? const [];
}

Future<_TopItemsHarness> _pumpTopItems(
  WidgetTester tester, {
  List<String>? storedOrder,
  AppConfigProvider Function(SharedPreferences prefs)? configure,
  Size surface = const Size(390, 1400),
}) async {
  SharedPreferences.setMockInitialValues({
    'homeTopItemsOrder': storedOrder ?? _fullOrder,
  });
  final prefs = await SharedPreferences.getInstance();

  setTestSurface(tester, surface);

  final appConfig =
      configure?.call(prefs) ?? AppConfigProvider(sharedPreferencesInstance: prefs);
  appConfig.saveFromSharedPreferences();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfigProvider>.value(value: appConfig),
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
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: ApplePalette.of(context).window,
            body: Center(
              child: AppleButton(
                label: 'open',
                onPressed: () => Navigator.push(
                  context,
                  CupertinoPageRoute<void>(
                    builder: (_) => const TopItemsListSettings(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  return _TopItemsHarness(prefs, appConfig);
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Finder segment(String label) => find.descendant(
        of: find.byType(AppleSegmented),
        matching: find.text(label),
      );

  bool saveReady(WidgetTester tester) =>
      tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(l.save),
          matching: find.byType(IconButton),
        ),
      ).onPressed !=
      null;

  List<String?> reorderedTitles(WidgetTester tester) => tester
      .widgetList<AppleListTile>(
        find.descendant(
          of: find.byType(ReorderableTopItemsHome),
          matching: find.byType(AppleListTile),
        ),
      )
      .map((tile) => tile.title)
      .toList();

  Finder handle(int index) =>
      find.byIcon(CupertinoIcons.line_horizontal_3).at(index);

  /// Takes the row by its three lines and moves it down [steps] rows.
  ///
  /// The move happens in the small jumps a finger makes: one jump of exactly a
  /// row lands the drag on the boundary the list resolves against, and the row
  /// goes back to where it started.
  Future<void> dragDown(WidgetTester tester, int from, int steps) async {
    final start = tester.getCenter(handle(from));
    final stride = tester.getCenter(handle(from + steps)).dy - start.dy;

    final drag = await tester.startGesture(start);
    await tester.pump(kPressTimeout);

    const jumps = 6;
    for (var i = 0; i < jumps; i++) {
      await drag.moveBy(Offset(0, stride / jumps));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pump(const Duration(milliseconds: 400));

    await drag.up();
    await tester.pumpAndSettle();
  }

  testWidgets('the stored order is the sequence the rows are in',
      (tester) async {
    await _pumpTopItems(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(reorderedTitles(tester), [
      l.topQueriedDomains,
      l.topBlockedDomains,
      l.topClients,
    ]);

    // Nothing has been changed, so there is nothing to write.
    expect(saveReady(tester), false);
  });

  testWidgets('a row dragged to a new place stores the new sequence',
      (tester) async {
    final h = await _pumpTopItems(tester);

    await dragDown(tester, 0, 1);

    // The drag moves the draft only: the setting is written when it is saved.
    expect(h.stored, _fullOrder);
    expect(saveReady(tester), true);

    await tester.tap(find.byTooltip(l.save));
    await tester.pumpAndSettle();

    expect(h.stored, [
      'blockedDomains',
      'queriedDomains',
      'recurrentClients',
    ]);
    expect(h.onDisk, h.stored);
    expect(find.text(l.settingsSaved), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(saveReady(tester), false);
  });

  testWidgets('the show/hide tab writes the same list without the hidden item',
      (tester) async {
    final h = await _pumpTopItems(tester);

    await tester.tap(segment(l.showHide));
    await tester.pumpAndSettle();

    expect(find.byType(ShowHideTopItemsList), findsOneWidget);
    expect(find.byType(AppleSwitchListTile), findsNWidgets(3));

    final clients = find.descendant(
      of: find.widgetWithText(AppleSwitchListTile, l.topClients),
      matching: find.byType(CupertinoSwitch),
    );
    await tester.ensureVisible(clients);
    await tester.pumpAndSettle();
    await tester.tap(clients);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(l.save));
    await tester.pumpAndSettle();

    expect(h.stored, [
      'queriedDomains',
      'blockedDomains',
    ]);
    expect(h.onDisk, h.stored);

    // A list the dashboard does not show has no position to keep, so it is not
    // in the reorder tab either.
    await tester.tap(segment(l.reorder));
    await tester.pumpAndSettle();
    expect(reorderedTitles(tester), hasLength(2));

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('an item switched back on joins the end of the sequence',
      (tester) async {
    final h = await _pumpTopItems(
      tester,
      storedOrder: const ['queriedDomains', 'blockedDomains'],
    );

    await tester.tap(segment(l.showHide));
    await tester.pumpAndSettle();

    final clients = find.descendant(
      of: find.widgetWithText(AppleSwitchListTile, l.topClients),
      matching: find.byType(CupertinoSwitch),
    );
    await tester.ensureVisible(clients);
    await tester.pumpAndSettle();
    await tester.tap(clients);
    await tester.pumpAndSettle();

    await tester.tap(segment(l.reorder));
    await tester.pumpAndSettle();
    expect(reorderedTitles(tester).last, l.topClients);

    await tester.tap(find.byTooltip(l.save));
    await tester.pumpAndSettle();

    expect(h.stored, ['queriedDomains', 'blockedDomains', 'recurrentClients']);
    expect(h.onDisk, h.stored);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('a write storage refused puts the page back to what is stored',
      (tester) async {
    final h = await _pumpTopItems(
      tester,
      configure: (prefs) => _RefusingAppConfig(sharedPreferencesInstance: prefs),
    );

    await tester.tap(segment(l.showHide));
    await tester.pumpAndSettle();

    final clients = find.descendant(
      of: find.widgetWithText(AppleSwitchListTile, l.topClients),
      matching: find.byType(CupertinoSwitch),
    );
    await tester.ensureVisible(clients);
    await tester.pumpAndSettle();
    await tester.tap(clients);
    await tester.pump();

    await tester.tap(find.byTooltip(l.save));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect((h.appConfig as _RefusingAppConfig).attempts, 1);
    expect(find.text(l.settingsNotSaved), findsOneWidget);

    // The draft is the stored list again, so the rows the page shows are the
    // ones the dashboard will actually draw.
    expect(h.stored, _fullOrder);
    expect(saveReady(tester), false);

    await tester.tap(segment(l.reorder));
    await tester.pumpAndSettle();
    expect(reorderedTitles(tester), hasLength(3));

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an order with nothing in it says so instead of an empty card',
      (tester) async {
    await _pumpTopItems(tester, storedOrder: const []);

    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(find.text(l.noElementsReorderMessage), findsOneWidget);
    expect(find.byType(ReorderableListView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an order an older build stored loses the rankings that went',
      (tester) async {
    // Builds from before the overview was redrawn offered five rankings, and
    // two of them have no segment on the card now. A stored order that still
    // carries their names has to come back without them, rather than reaching
    // the page as rows the dashboard cannot draw.
    final h = await _pumpTopItems(
      tester,
      storedOrder: const [
        'queriedDomains',
        'topUpstreams',
        'blockedDomains',
        'avgUpstreamResponseTime',
        'recurrentClients',
      ],
    );

    expect(h.stored, _fullOrder);
    expect(reorderedTitles(tester), hasLength(3));
    expect(saveReady(tester), false);
    expect(tester.takeException(), isNull);
  });
}
