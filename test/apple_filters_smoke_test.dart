import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/blocked_services.dart';
import 'package:adguard_home_manager/models/dns_statistics.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/models/filtering_status.dart' hide Filter;
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/filters/custom_rules_list.dart';
import 'package:adguard_home_manager/screens/filters/filters_list.dart';
import 'package:adguard_home_manager/screens/filters/filters_page.dart';
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
    blockedServices: ['netflix'],
    interval: 24,
    enabled: true,
  ));
  provider.setFilteringLoadStatus(LoadStatus.loaded, false);

  // The catalog of services is a second endpoint; the page reads it as loaded
  // data so the grid can be checked without an API client.
  provider.setBlockedServiceListData([
    BlockedService(id: 'netflix', name: 'Netflix', iconSvg: '', rules: const []),
    BlockedService(id: 'twitch', name: 'Twitch', iconSvg: '', rules: const []),
  ]);
  provider.setBlockedServicesListLoadStatus(LoadStatus.loaded, false);

  return provider;
}

ServerStatus _status({bool protectionOn = true}) => ServerStatus(
  stats: DnsStatistics(
    timeUnits: 'hour',
    topQueriedDomains: const [],
    topClients: const [],
    topBlockedDomains: const [],
    topUpstreamResponses: null,
    topUpstreamsAvgTime: null,
    dnsQueries: const [],
    blockedFiltering: const [],
    replacedSafebrowsing: const [],
    replacedParental: const [],
    numDnsQueries: 0,
    numBlockedFiltering: 0,
    numReplacedSafebrowsing: 0,
    numReplacedSafesearch: 0,
    numReplacedParental: 0,
    avgProcessingTime: 0.0,
  ),
  clients: const [],
  filteringStatus: FilteringStatus(
    filters: const [],
    whitelistFilters: const [],
    userRules: const [],
    interval: 0,
    enabled: true,
  ),
  timeGeneralDisabled: 0,
  generalEnabled: protectionOn,
  filteringEnabled: true,
  safeSearchEnabled: false,
  safeBrowsingEnabled: true,
  parentalControlEnabled: false,
  serverVersion: 'v0.107.0',
  safeSeachBing: false,
  safeSearchGoogle: false,
  safeSearchDuckduckgo: false,
  safeSearchEcosia: false,
  safeSearchPixabay: false,
  safeSearchYandex: false,
  safeSearchYoutube: false,
  dhcpAvailable: false,
);

Future<AppConfigProvider> _appConfigProvider() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return AppConfigProvider(sharedPreferencesInstance: prefs);
}

Future<void> _pump(
  WidgetTester tester,
  Widget body, {
  bool protectionOn = true,
}) async {
  final appConfigProvider = await _appConfigProvider();
  final filteringProvider = await _filteringProvider();
  final statusProvider = StatusProvider()
    ..setServerStatusData(data: _status(protectionOn: protectionOn))
    ..setServerStatusLoad(LoadStatus.loaded);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appConfigProvider),
        ChangeNotifierProvider.value(value: filteringProvider),
        ChangeNotifierProvider(create: (_) => statusProvider),
        // No client is attached, so the page shows the data the providers hold.
        ChangeNotifierProvider(create: (_) => ServersProvider()),
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

/// The mobile page, built with the data the providers hold.
Future<void> _pumpPage(
  WidgetTester tester, {
  bool protectionOn = true,
  void Function(Filter, String)? onOpenDetailsModal,
}) async {
  await _pump(
    tester,
    FiltersPage(
      actions: const [],
      onOpenDetailsModal: onOpenDetailsModal ?? (_, __) {},
    ),
    protectionOn: protectionOn,
  );
}

/// The page is one long scroll, so the groups below the title have to be
/// brought on screen before they are built.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable).first,
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

  testWidgets('the page leads with the protections', (tester) async {
    await _pumpPage(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(l.protectionSwitches.toUpperCase()), findsOneWidget);
    expect(find.text(l.ruleFilteringHelper), findsOneWidget);
    expect(find.text(l.safeBrowsingHelper), findsOneWidget);

    // Rule filtering and safe browsing are on, safe search and parental are off.
    final switches = tester
        .widgetList<CupertinoSwitch>(find.byType(CupertinoSwitch))
        .toList();
    expect(switches.take(4).map((s) => s.value).toList(), [true, true, false, false]);

    expect(find.text(l.pauseProtection), findsOneWidget);
    expect(find.text(l.running), findsOneWidget);
  });

  testWidgets('the title line counts what is working', (tester) async {
    await _pumpPage(tester);

    // Only list 0 is enabled, and its rules are what the server is actually
    // applying; the allowlists are not counted, because the page does not
    // show them.
    expect(find.text(l.listsEnabledWithRules('1', '100')), findsOneWidget);
  });

  testWidgets('the pause row offers the durations', (tester) async {
    await _pumpPage(tester);

    await tester.tap(find.text(l.pauseProtection));
    await tester.pumpAndSettle();

    expect(find.text(l.seconds(30)), findsOneWidget);
    expect(find.text(l.minutes(10)), findsOneWidget);
    expect(find.text(l.hours(24)), findsOneWidget);
    expect(find.text(l.resumeProtection), findsNothing);
  });

  testWidgets('a paused protection offers to resume instead', (tester) async {
    await _pumpPage(tester, protectionOn: false);

    expect(find.text(l.paused), findsOneWidget);
    expect(find.text(l.protectionPausedHelper), findsOneWidget);

    await tester.tap(find.text(l.pauseProtection));
    await tester.pumpAndSettle();

    expect(find.text(l.resumeProtection), findsOneWidget);
  });

  testWidgets('the page keeps the blocklists and the way to add one', (tester) async {
    var detailsId = -1;
    var detailsType = '';

    await _pumpPage(
      tester,
      onOpenDetailsModal: (list, type) {
        detailsId = list.id;
        detailsType = type;
      },
    );

    expect(find.text(l.filterLists), findsOneWidget);
    expect(find.text('List 0'), findsOneWidget);
    expect(find.text(l.addList), findsOneWidget);

    await tester.tap(find.text('List 0'));
    await tester.pumpAndSettle();

    expect(detailsId, 0);
    expect(detailsType, 'blacklist');

    // The allowlists the server also keeps have no place in this design, so
    // the page leaves them out rather than inventing a group for them.
    expect(find.text(l.whitelists), findsNothing);
    expect(find.text('List 9'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rules preview colours each kind of rule', (tester) async {
    await _pumpPage(tester);
    await _scrollTo(tester, find.text(l.customRulesPreview));

    expect(find.text(l.customRules.toUpperCase()), findsOneWidget);
    expect(find.text(l.editRules), findsOneWidget);
    expect(find.text(l.rulesCount('3')), findsOneWidget);

    final preview = tester.widgetList<Text>(find.byType(Text))
        .where((text) => (text.textSpan?.toPlainText() ?? '').contains('||ads.example.org^'))
        .toList();
    expect(preview, hasLength(1));

    final spans = (preview.single.textSpan! as TextSpan).children!.cast<TextSpan>();
    final colours = <String, Color>{
      for (final span in spans)
        if (span.text != '\n') span.text!: span.style!.color!,
    };

    expect(colours['||ads.example.org^'], AppleColors.red(Brightness.light));
    expect(colours['@@allowed.example.org'], AppleColors.green(Brightness.light));
    expect(colours['! comment line'], AppleColors.label3(Brightness.light));
  });

  testWidgets('the service grid marks the blocked services', (tester) async {
    await _pumpPage(tester);

    await _scrollTo(tester, find.text(l.blockByService));

    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Twitch'), findsOneWidget);
    // Blocking something is worth pointing out, so the group offers a way back.
    expect(find.text(l.clearAll), findsOneWidget);

    expect(
      tester.widget<Text>(find.text('Netflix')).style!.color,
      AppleColors.red(Brightness.light),
    );
    expect(
      tester.widget<Text>(find.text('Twitch')).style!.color,
      AppleColors.label2(Brightness.light),
    );
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
