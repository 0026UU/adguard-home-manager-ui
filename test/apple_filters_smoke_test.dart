import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/screens/filters/custom_rules_list.dart';
import 'package:adguard_home_manager/screens/filters/filters_list.dart';
import 'package:adguard_home_manager/screens/filters/filters_tabs_view.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

Filter _list(int index, {bool enabled = true}) => Filter(
  url: 'https://example.org/list-$index.txt',
  name: 'List $index',
  lastUpdated: null,
  id: index,
  rulesCount: 100 + index,
  enabled: enabled,
);

Future<FilteringProvider> _filteringProvider() async {
  final provider = FilteringProvider();
  provider.setFilteringData(Filtering(
    filters: [_list(0), _list(1, enabled: false)],
    whitelistFilters: [_list(9)],
    userRules: const [
      '||ads.example.org^',
      '@@allowed.example.org',
      '! comment line',
    ],
    blockedServices: const [],
    interval: 24,
    enabled: true,
  ));
  provider.setFilteringLoadStatus(LoadStatus.loaded, false);
  return provider;
}

Future<AppConfigProvider> _appConfigProvider() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return AppConfigProvider(sharedPreferencesInstance: prefs);
}

Future<void> _pump(WidgetTester tester, Widget body) async {
  final appConfigProvider = await _appConfigProvider();
  final filteringProvider = await _filteringProvider();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appConfigProvider),
        ChangeNotifierProvider.value(value: filteringProvider),
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
        home: body,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

/// Screen shell used by the list tests: the same collapsing-title + tab body
/// the real screen builds.
Future<void> _pumpList(WidgetTester tester, Widget list) async {
  await _pump(
    tester,
    AppleScreen(
      title: 'Filters',
      header: AppleSegmented(
        labels: const ['Lists', 'Rules'],
        selectedIndex: 0,
        onChanged: (_) {},
      ),
      body: list,
    ),
  );
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('filter lists carry one switch per row', (tester) async {
    await _pumpList(
      tester,
      FiltersList(
        loadStatus: LoadStatus.loaded,
        scrollController: ScrollController(),
        type: 'blacklist',
        data: [_list(0), _list(1, enabled: false)],
        onOpenDetailsScreen: (_, __) {},
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('List 0'), findsOneWidget);
    // The design layer switches a list from the row itself rather than
    // showing a status capsule, so the state is the switch position.
    expect(find.byType(ApplePill), findsNothing);
    final switches = tester
        .widgetList<CupertinoSwitch>(find.byType(CupertinoSwitch))
        .toList();
    expect(switches, hasLength(2));
    expect(switches[0].value, isTrue);
    expect(switches[1].value, isFalse);
  });

  testWidgets('opening a list row reports the filter and its type', (tester) async {
    Filter? opened;
    String? openedType;

    await _pumpList(
      tester,
      FiltersList(
        loadStatus: LoadStatus.loaded,
        scrollController: ScrollController(),
        type: 'whitelist',
        data: [_list(3)],
        onOpenDetailsScreen: (filter, type) {
          opened = filter;
          openedType = type;
        },
      ),
    );

    await tester.tap(find.text('List 3'));
    await tester.pumpAndSettle();

    expect(opened?.id, 3);
    expect(openedType, 'whitelist');
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom rules are labelled by their kind', (tester) async {
    var removed = '';

    await _pumpList(
      tester,
      CustomRulesList(
        loadStatus: LoadStatus.loaded,
        scrollController: ScrollController(),
        data: const ['||ads.example.org^', '@@allowed.example.org'],
        onRemoveCustomRule: (rule) => removed = rule,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(l.blocked), findsOneWidget);
    expect(find.text(l.allowed), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.trash).first);
    await tester.pumpAndSettle();

    expect(removed, '||ads.example.org^');
  });

  testWidgets('the lists tab switcher drives the screen', (tester) async {
    var detailsId = -1;
    late AppConfigProvider appConfig;

    await _pump(
      tester,
      Builder(
        builder: (context) {
          appConfig = Provider.of<AppConfigProvider>(context);
          return FiltersTabsView(
            appConfigProvider: appConfig,
            actions: const [],
            onOpenDetailsModal: (filter, _) => detailsId = filter.id,
            onRemoveCustomRule: (_) {},
          );
        },
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(l.whitelists), findsOneWidget);
    expect(find.text('List 9'), findsOneWidget);

    await tester.tap(find.text(l.customRules));
    await tester.pumpAndSettle();

    expect(find.text('||ads.example.org^'), findsOneWidget);
    expect(appConfig.selectedFiltersTab, 2);

    await tester.tap(find.text(l.blacklists));
    await tester.pumpAndSettle();

    expect(find.text('List 0'), findsOneWidget);

    await tester.tap(find.text('List 1'));
    await tester.pumpAndSettle();

    expect(detailsId, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty list falls back to the Apple empty state', (tester) async {
    await _pumpList(
      tester,
      FiltersList(
        loadStatus: LoadStatus.loaded,
        scrollController: ScrollController(),
        type: 'blacklist',
        data: const [],
        onOpenDetailsScreen: (_, __) {},
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(find.text(l.noBlackLists), findsOneWidget);
  });
}
