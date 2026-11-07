import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/logs/details/log_details_screen.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'surface.dart';

/// The entry the web UI draws in full: every field class the b.2 query log
/// API can carry, so every row AdGuard Home shows must show here too.
const _fullJson = {
  'answer': [
    {'type': 'A', 'value': '0.0.0.0', 'ttl': 10},
    {'type': 'AAAA', 'value': '::', 'ttl': 300},
  ],
  'answer_dnssec': true,
  'cached': true,
  'client': '203.0.113.9',
  'client_info': {
    'name': '办公 Mac',
    'whois': {
      'city': 'Beijing',
      'country': 'CN',
      'orgname': 'Example Org',
      'network': '203.0.113.0/24',
      'location': '39.9,116.4',
      'category': 'business',
    },
    'disallowed_rule': '',
    'disallowed': false,
  },
  'client_proto': 'doh',
  'ecs': '1.2.3.0/24',
  'elapsedMs': '1889.2157',
  'filterId': 7,
  'original_answer': [
    {'type': 'A', 'value': '142.251.45.14', 'ttl': 600},
  ],
  'question': {'class': 'IN', 'name': 'doubleclick.net', 'type': 'AAAA'},
  'reason': 'FilteredBlackList',
  'rule': '||doubleclick.net^',
  'rules': [
    {'filter_list_id': 7, 'text': '||doubleclick.net^'},
    {'filter_list_id': 7, 'text': '||doubleclick.com^'},
  ],
  'service_name': 'YouTube',
  'size': 59,
  'status': 'NOERROR',
  'time': '2026-11-06T17:18:39.5554267+08:00',
  'upstream': '9.9.9.10:53',
};

/// An entry that carries nothing but the question: every optional field is
/// absent, so the web UI hides those lines and the sheet must hide them too.
const _sparseJson = {
  'cached': false,
  'client': '127.0.0.1',
  'client_info': {
    'name': '',
    'whois': {},
    'disallowed_rule': '',
    'disallowed': false,
  },
  'client_proto': '',
  'elapsedMs': 'not-a-number',
  'question': {'class': '', 'name': 'bare.test', 'type': 'A'},
  'reason': 'NotFilteredNotFound',
  'rules': [],
  'time': '2026-11-06T09:00:00Z',
};

Future<void> _pump(WidgetTester tester, Log log) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final status = StatusProvider()
    ..setFilteringStatus(FilteringStatus(
      filters: [
        Filter(
          url: 'https://example.org/list.txt',
          name: 'AdGuard DNS filter',
          id: 7,
          rulesCount: 2,
          enabled: true,
        ),
      ],
      whitelistFilters: [],
      userRules: [],
      interval: 24,
      enabled: true,
    ));
  setTestSurface(tester, const Size(1000, 2400));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<StatusProvider>.value(value: status),
        ChangeNotifierProvider(
          create: (_) => AppConfigProvider(sharedPreferencesInstance: prefs),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: globalNavigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        theme: appleTheme(Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LogDetailsScreen(log: log, twoColumns: true),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String? _valueOf(WidgetTester tester, String label) {
  final rows = tester.widgetList<AppleDetailRow>(find.byType(AppleDetailRow));
  for (final row in rows) {
    if (row.label == label) return row.value;
  }
  return null;
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('a fully populated entry renders every web UI row', (tester) async {
    await _pump(tester, Log.fromJson(Map<String, dynamic>.from(_fullJson)));
    final time = DateTime.parse(_fullJson['time'] as String).toLocal();

    // Section captions the web UI groups the record under.
    expect(find.text(l.logQueryDetails), findsOneWidget);
    expect(find.text(l.logResponseDetails), findsOneWidget);
    expect(find.text(l.logClientDetails), findsOneWidget);

    final expected = <String, String>{
      l.time: DateFormat.Hms('en').format(time),
      l.date: DateFormat.yMd('en').format(time),
      l.domain: 'doubleclick.net',
      l.logDetailEcs: '1.2.3.0/24',
      l.type: 'AAAA',
      l.logProtocol: 'DNS-over-HTTPS',
      l.logDetailDnssec: l.logDetailValidatedWithDnssec,
      l.status: l.queryBlocked,
      l.logReason: l.logReasonBlockedByFilter,
      l.logDetailSource: 'AdGuard DNS filter',
      l.logDetailServedFromCache: l.yes,
      l.dnsServer: '9.9.9.10:53',
      l.elapsedTime: '1889.2 ms',
      l.responseCode: 'NOERROR',
      l.response: 'A  0.0.0.0  TTL 10\nAAAA  ::  TTL 300',
      l.logDetailServiceName: 'YouTube',
      l.logDetailRules: '||doubleclick.net^\n||doubleclick.com^',
      l.logDetailOriginalResponse: 'A  142.251.45.14  TTL 600',
      l.logDetailAddress: '203.0.113.9',
      l.deviceName: '办公 Mac',
      l.logDetailCountry: 'CN',
      l.logDetailNetwork: 'Example Org',
    };
    expected.forEach((label, value) {
      expect(_valueOf(tester, label), value, reason: 'row "$label"');
    });
    // The rendered order matches the web UI modal row by row.
    expect(
      tester.widgetList<AppleDetailRow>(find.byType(AppleDetailRow))
          .map((row) => row.label),
      expected.keys.toList(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a sparse entry omits every absent field row', (tester) async {
    await _pump(tester, Log.fromJson(Map<String, dynamic>.from(_sparseJson)));

    expect(find.text(l.logDetailWhois), findsNothing);
    final labels = tester
        .widgetList<AppleDetailRow>(find.byType(AppleDetailRow))
        .map((row) => row.label)
        .toSet();
    for (final absent in [
      l.clas,
      l.logDetailEcs,
      l.logDetailSource,
      l.logDetailRules,
      l.logDetailServiceName,
      l.responseCode,
      l.response,
      l.logDetailOriginalResponse,
      l.logDetailDnssec,
      l.dnsServer,
      l.elapsedTime,
      l.responseSize,
      l.deviceName,
      l.logDetailCountry,
      l.logDetailNetwork,
      l.logDetailCategory,
    ]) {
      expect(labels, isNot(contains(absent)), reason: 'row "$absent"');
    }
    expect(_valueOf(tester, l.domain), 'bare.test');
    expect(_valueOf(tester, l.type), 'A');
    expect(_valueOf(tester, l.logProtocol), l.logProtocolPlain);
    expect(_valueOf(tester, l.status), l.logStatusProcessed);
    expect(_valueOf(tester, l.logReason), l.logStatusProcessed);
    expect(_valueOf(tester, l.logDetailServedFromCache), l.no);
    expect(_valueOf(tester, l.logDetailAddress), '127.0.0.1');
    expect(_valueOf(tester, l.date), isNotNull);
    expect(_valueOf(tester, l.time), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a custom rule block reads the custom rules source', (tester) async {
    final json = Map<String, dynamic>.from(_fullJson)
      ..['filterId'] = 0
      ..remove('service_name');
    await _pump(tester, Log.fromJson(json));
    expect(_valueOf(tester, l.logDetailSource), l.logSourceCustomRules);
    expect(_valueOf(tester, l.logDetailServiceName), isNull);
  });

  test('ecs, service name and whois survive a model roundtrip', () {
    final log = Log.fromJson(Map<String, dynamic>.from(_fullJson));
    expect(log.ecs, '1.2.3.0/24');
    expect(log.serviceName, 'YouTube');
    expect(log.clientInfo?.whois.country, 'CN');
    final round = Log.fromJson(log.toJson());
    expect(round.ecs, log.ecs);
    expect(round.serviceName, log.serviceName);
    expect(round.clientInfo?.whois.city, 'Beijing');
    expect(round.clientInfo?.whois.category, 'business');
  });
}
