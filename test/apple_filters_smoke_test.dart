import 'dart:async';

import 'package:flutter/cupertino.dart';
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
import 'package:adguard_home_manager/models/dns_statistics.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/models/filtering_status.dart' hide Filter;
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
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

void _seed(FilteringProvider provider, {bool fails = false}) {
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
  provider.setFilteringLoadStatus(
      fails ? LoadStatus.error : LoadStatus.loaded, false);

  // The catalog of services is a second endpoint; the page reads it as loaded
  // data so the grid can be checked without an API client.
  provider.setBlockedServiceListData([
    BlockedService(id: 'netflix', name: 'Netflix', iconSvg: '', rules: const []),
    BlockedService(id: 'twitch', name: 'Twitch', iconSvg: '', rules: const []),
  ]);
  provider.setBlockedServicesListLoadStatus(LoadStatus.loaded, false);
}

Future<FilteringProvider> _filteringProvider({bool fails = false}) async {
  final provider = FilteringProvider();
  _seed(provider, fails: fails);
  return provider;
}

/// The services page with its write held open, so a test can tap twice before
/// the server has answered the first time.
class _PendingServices extends FilteringProvider {
  _PendingServices() {
    _seed(this);
  }

  /// Every list the page posted, in the order it posted them.
  final List<List<String>> posted = [];

  final Completer<void> gate = Completer<void>();

  @override
  Future<bool> updateBlockedServices(List<String> values) async {
    posted.add(values);
    await gate.future;
    return true;
  }
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
  bool fails = false,
  FilteringProvider? filtering,
}) async {
  final appConfigProvider = await _appConfigProvider();
  final filteringProvider = filtering ?? await _filteringProvider(fails: fails);
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
        debugShowCheckedModeBanner: false,
        // The Apple toast attaches to the root navigator's overlay, so without
        // this key the page would save correctly but never say so.
        navigatorKey: globalNavigatorKey,
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
  bool fails = false,
  FilteringProvider? filtering,
  void Function(Filter, String)? onOpenDetailsModal,
}) async {
  await _pump(
    tester,
    FiltersPage(
      actions: const [],
      onOpenDetailsModal: onOpenDetailsModal ?? (_, __) {},
    ),
    protectionOn: protectionOn,
    fails: fails,
    filtering: filtering,
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

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the page leads with the protections', (tester) async {
    await _pumpPage(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(l.protectionSwitches), findsOneWidget);
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

    // List 0 (100 rules) blocks and List 9 (109 rules) allows: the footnote
    // counts both kinds, because the page now shows both kinds.
    expect(find.text(l.listsEnabledWithRules(2, 209)), findsOneWidget);
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

  testWidgets('the page keeps both kinds of list in their own sections',
      (tester) async {
    var detailsId = -1;
    var detailsType = '';

    await _pumpPage(
      tester,
      onOpenDetailsModal: (list, type) {
        detailsId = list.id;
        detailsType = type;
      },
    );

    expect(find.text(l.blacklists), findsOneWidget);
    expect(find.text('List 0'), findsOneWidget);
    expect(find.text(l.addList), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('List 0'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('List 0'));
    await tester.pumpAndSettle();

    expect(detailsId, 0);
    expect(detailsType, 'blacklist');

    // The allowlists the server keeps have a section of their own, below the
    // blocklists, with the same row behaviour.
    await _scrollTo(tester, find.text(l.whitelists));
    expect(find.text('List 9'), findsOneWidget);

    await tester.tap(find.text('List 9'));
    await tester.pumpAndSettle();

    expect(detailsId, 9);
    expect(detailsType, 'whitelist');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rules preview colours each kind of rule', (tester) async {
    await _pumpPage(tester);
    await _scrollTo(tester, find.text(l.customRulesPreview));

    expect(find.text(l.customRules), findsOneWidget);
    expect(find.text(l.editRules), findsOneWidget);
    expect(find.text(l.rulesCount(3, '3')), findsOneWidget);

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

  testWidgets('clearing every blocked service asks before it writes',
      (tester) async {
    final services = _PendingServices();
    await _pumpPage(tester, filtering: services);

    await _scrollTo(tester, find.text(l.clearAll));
    await tester.tap(find.text(l.clearAll));
    await tester.pumpAndSettle();

    // The header action used to post the empty list on the tap that opened it,
    // so one stray touch switched the whole block list off with no way back.
    expect(find.byType(AppleAlertDialog), findsOneWidget);
    expect(find.text(l.clearBlockedServicesConfirm), findsOneWidget);
    expect(services.posted, isEmpty);

    await tester.tap(
      find.descendant(
        of: find.byType(AppleAlertDialog),
        matching: find.text(l.cancel),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppleAlertDialog), findsNothing);
    expect(services.posted, isEmpty);

    await tester.tap(find.text(l.clearAll));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AppleAlertDialog),
        matching: find.text(l.clearAll),
      ),
    );
    await tester.pump();

    expect(services.posted, [<String>[]]);

    services.gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a refused filter read can be asked for again', (tester) async {
    await _pumpPage(tester, fails: true);

    expect(find.text(l.filtersNotLoaded), findsOneWidget);
    // Nothing is left on the tab to pull once the lists are gone: the pull
    // handle belongs to the list that failed to arrive.
    expect(find.widgetWithText(AppleFormButton, l.refresh), findsOneWidget);
  });

  testWidgets('a second service tap waits for the first write to answer',
      (tester) async {
    final services = _PendingServices();
    await _pumpPage(tester, filtering: services);

    await _scrollTo(tester, find.text(l.blockByService));

    await tester.tap(find.text('Twitch'));
    await tester.pump();

    await tester.tap(find.text('Twitch'));
    await tester.pump();

    // The second tap reads the same snapshot the first one did, so posting it
    // too would let the older list win and flip the chip back under a toast
    // that says the change was saved.
    expect(services.posted, [
      ['netflix', 'twitch'],
    ]);

    services.gate.complete();
    await tester.pumpAndSettle();

    expect(find.text(l.blockedServicesUpdated), findsOneWidget);
    expect(services.posted.length, 1);
  });
}
