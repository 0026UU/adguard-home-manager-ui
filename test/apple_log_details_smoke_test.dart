import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/logs/details/log_details_screen.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

Log _log({String reason = 'FilteredBlackList'}) => Log(
      cached: true,
      client: '192.168.1.20',
      clientProto: '53',
      elapsedMs: '1.234',
      question: Question(
        questionClass: 'IN',
        name: 'ads.example.com',
        type: 'A',
      ),
      reason: reason,
      rules: [Rule(filterListId: 7, text: '||ads.example.com^')],
      status: 'NOERROR',
      time: DateTime.utc(2024, 5, 1, 12),
      upstream: '8.8.8.8:53',
      answer: [Answer(type: 'A', value: '10.0.0.1', ttl: 300)],
      rule: '||ads.example.com^',
    );

FilteringStatus _status({List<Filter> filters = const []}) => FilteringStatus(
      filters: filters,
      whitelistFilters: const [],
      userRules: const [],
      interval: 0,
      enabled: true,
    );

Filter _filter() => Filter(
      url: 'https://example.com/ads.txt',
      name: 'AdGuard DNS filter',
      id: 7,
      rulesCount: 100,
      enabled: true,
    );

Future<void> _pump(
  WidgetTester tester, {
  required Log log,
  required bool dialog,
  bool twoColumns = false,
  FilteringStatus? status,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final statusProvider = StatusProvider();
  if (status != null) statusProvider.setFilteringStatus(status);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => statusProvider),
        ChangeNotifierProvider(
          create: (_) => AppConfigProvider(sharedPreferencesInstance: prefs),
        ),
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
        home: dialog
            ? Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (context) => LogDetailsScreen(
                            log: log, dialog: true, twoColumns: false),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              )
            : LogDetailsScreen(
                log: log,
                dialog: false,
                twoColumns: twoColumns,
              ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  if (dialog) {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the details dialog groups the query as inset sections',
      (tester) async {
    await _pump(tester,
        log: _log(), dialog: true, status: _status(filters: [_filter()]));

    expect(find.text(l.logDetails), findsOneWidget);
    for (final section in [
      l.status,
      l.request,
      l.response,
      l.client,
      l.rules,
      l.answers
    ]) {
      expect(find.text(section.toUpperCase()), findsOneWidget);
    }
    // Blocked by a rule, cached, and the answer carries its own type pill.
    expect(find.text(l.blockedBlacklistRow), findsOneWidget);
    expect(find.text('CACHE'), findsOneWidget);
    expect(find.text('TTL: 300'), findsOneWidget);
    expect(find.byType(ApplePill), findsNWidgets(2));
    expect(find.text('AdGuard DNS filter'), findsOneWidget);
    expect(find.byType(AppleListSection), findsNWidgets(6));
    // The reason the server answered with reads as a row of its own.
    expect(find.text(l.logReason), findsOneWidget);
    expect(find.text('FilteredBlackList'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the header action offers to allow a blocked query',
      (tester) async {
    await _pump(tester, log: _log(), dialog: true);

    expect(find.byIcon(CupertinoIcons.checkmark_circle_fill), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.slash_circle_fill), findsNothing);
    // Once in the header, once as the domain badge.
    expect(find.byIcon(CupertinoIcons.globe), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an allowed query offers to block it instead', (tester) async {
    await _pump(tester, log: _log(reason: 'NotFilteredNotFound'), dialog: true);

    expect(find.byIcon(CupertinoIcons.slash_circle_fill), findsOneWidget);
    expect(find.text(l.processedRow), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unknown reason still reads as a row', (tester) async {
    await _pump(tester, log: _log(reason: 'Whatever'), dialog: true);

    expect(find.text('Unknown'), findsOneWidget);
    expect(find.byType(AppleListTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rules from an unknown list are left out', (tester) async {
    await _pump(tester, log: _log(), dialog: true, status: _status());

    expect(find.text(l.rules.toUpperCase()), findsNothing);
    expect(find.text('AdGuard DNS filter'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pushed screen gets a back button', (tester) async {
    await _pump(tester, log: _log(), dialog: false);

    expect(find.byType(AppleScreen), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.back), findsOneWidget);
    // The screen shows its status action only once the lists are loaded.
    expect(find.byIcon(CupertinoIcons.checkmark_circle_fill), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the embedded pane has no back button of its own',
      (tester) async {
    await _pump(
      tester,
      log: _log(),
      dialog: false,
      twoColumns: true,
      status: _status(filters: [_filter()]),
    );

    expect(find.byIcon(CupertinoIcons.back), findsNothing);
    expect(find.byIcon(CupertinoIcons.checkmark_circle_fill), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
