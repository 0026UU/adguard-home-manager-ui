import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/blocked_services.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/filters/filters_page.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'surface.dart';

// The server the user reported from keeps 19 lists — 12 that block and 7 that
// allow — and the page used to draw one mixed group from the blocklists alone.
// These tests pin that every list of both arrays reaches a row, in a section
// of its own, with the section's count in the header.

Filter _list(int index, {bool enabled = true}) => Filter(
  url: 'https://example.org/list-$index.txt',
  name: 'List $index',
  lastUpdated: null,
  id: index,
  rulesCount: index,
  enabled: enabled,
);

FilteringProvider _provider({
  required List<Filter> filters,
  required List<Filter> whitelistFilters,
}) {
  final provider = FilteringProvider();
  provider.setFilteringData(Filtering(
    filters: filters,
    whitelistFilters: whitelistFilters,
    userRules: const [],
    blockedServices: const [],
    interval: 24,
    enabled: true,
  ));
  provider.setFilteringLoadStatus(LoadStatus.loaded, false);
  // The services grid spins forever while its endpoint is "loading", and a
  // spinner that never stops is a pumpAndSettle that never settles: the grid
  // is not what these tests look at, so it gets an answered catalogue.
  provider.setBlockedServiceListData([
    BlockedService(id: 'netflix', name: 'Netflix', iconSvg: '', rules: const []),
  ]);
  provider.setBlockedServicesListLoadStatus(LoadStatus.loaded, false);
  return provider;
}

Future<void> _pump(WidgetTester tester, FilteringProvider filtering) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  setTestSurface(tester, const Size(390, 844));

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: AppConfigProvider(sharedPreferencesInstance: prefs),
        ),
        ChangeNotifierProvider.value(value: filtering),
        // No status and no client: the page skips the protections and draws
        // the list sections from the filtering data alone.
        ChangeNotifierProvider(create: (_) => StatusProvider()),
        ChangeNotifierProvider(create: (_) => ServersProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: globalNavigatorKey,
        theme: appleLightTheme(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: FiltersPage(actions: const [], onOpenDetailsModal: (_, __) {}),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

/// Walks the page's slivers from the top, handing every built row to [visit].
///
/// The list cards build lazily, so the rows that prove "all 19 render" only
/// exist while they are on screen; scrolling the whole page and collecting on
/// the way is what counts them.
Future<void> _walk(WidgetTester tester, void Function() visit) async {  final scrollable = find.byType(Scrollable).first;
  double pixels() => tester.state<ScrollableState>(scrollable).position.pixels;

  visit();
  while (true) {
    final before = pixels();
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pumpAndSettle();
    visit();
    if (pixels() == before) break;
  }
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('12 blocklists and 7 allowlists all reach a row, in two sections',
      (tester) async {
    await _pump(
      tester,
      _provider(
        filters: [for (var i = 0; i < 12; i++) _list(i)],
        whitelistFilters: [for (var i = 12; i < 19; i++) _list(i)],
      ),
    );

    expect(tester.takeException(), isNull);

    // The blocklist section leads, with its own count in the header meta.
    expect(find.text(l.blacklists), findsOneWidget);
    expect(find.text(l.filterListsCount(12)), findsOneWidget);

    // The allowlists have a section of their own below, not one mixed run.
    await _dragUntil(tester, find.text(l.whitelists));
    expect(find.text(l.whitelists), findsOneWidget);
    expect(find.text(l.filterListsCount(7)), findsOneWidget);

    // Back to the top, then walk the whole page collecting every row that
    // gets built on the way down.
    await _dragUntil(tester, find.text(l.blacklists), delta: -300);
    final seenBlock = <String>{};
    final seenAllow = <String>{};
    await _walk(tester, () {
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final value = text.data ?? '';
        if (value.startsWith('List ')) {
          final index = int.parse(value.substring(5));
          (index < 12 ? seenBlock : seenAllow).add(value);
        }
      }
    });

    expect(seenBlock, hasLength(12));
    expect(seenAllow, hasLength(7));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an allowlist section with nothing in it shows the empty card',
      (tester) async {
    await _pump(
      tester,
      _provider(
        filters: [_list(0)],
        whitelistFilters: const [],
      ),
    );

    await _dragUntil(tester, find.text(l.whitelists));

    // The section keeps its shape instead of leaving a blank gap: the empty
    // treatment names what is missing.
    expect(find.text(l.noWhiteLists), findsOneWidget);
    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(find.text(l.filterListsCount(0)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Drags the page by [delta] until [finder] is built, one settled frame per
/// step. `scrollUntilVisible` landed mid-collapse frames that tripped a
/// sub-pixel overflow in the large title; whole settled steps do not.
Future<void> _dragUntil(
  WidgetTester tester,
  Finder finder, {
  double delta = 120,
  int maxSteps = 60,
}) async {
  for (var step = 0; step < maxSteps && finder.evaluate().isEmpty; step++) {
    await tester.drag(find.byType(Scrollable).first, Offset(0, -delta));
    await tester.pumpAndSettle();
  }
  await tester.pumpAndSettle();
}
