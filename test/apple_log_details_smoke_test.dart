import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

Log _log({
  String reason = 'NotFilteredNotFound',
  String? domain = 'ads.example.com',
  int? size = 124,
  bool cached = false,
  String elapsed = '1.234',
  List<Answer>? answers,
}) => Log.fromJson({
      'cached': cached,
      'client': '192.168.1.20',
      'client_info': {
        'name': 'livingroom-mac',
        'whois': {},
        'disallowed_rule': '',
        'disallowed': false,
      },
      'client_proto': '53',
      'elapsedMs': elapsed,
      'question': {'class': 'IN', 'name': domain, 'type': 'A'},
      'reason': reason,
      'rules': [],
      'status': 'NOERROR',
      'time': '2024-05-01T12:00:00Z',
      'upstream': '8.8.8.8:53',
      'answer': (answers ?? [Answer(type: 'A', value: '10.0.0.1', ttl: 300)])
          .map((answer) => answer.toJson())
          .toList(),
      if (size != null) 'size': size,
    });

class _Status extends StatusProvider {
  final calls = <Map<String, String>>[];
  Completer<bool>? pending;
  bool result = true;
  bool throws = false;

  _Status({bool loaded = true}) {
    if (loaded) {
      setFilteringStatus(FilteringStatus(
        filters: [],
        whitelistFilters: [],
        userRules: [],
        interval: 24,
        enabled: true,
      ));
    }
  }

  @override
  Future<bool> blockUnblockDomain({
    required String domain,
    required String newStatus,
  }) async {
    calls.add({'domain': domain, 'status': newStatus});
    if (throws) throw StateError('connection interrupted');
    return pending == null ? result : await pending!.future;
  }
}

Future<_Status> _pump(
  WidgetTester tester, {
  Log? log,
  _Status? status,
  bool pane = false,
  Size surface = const Size(390, 844),
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Locale locale = const Locale('en'),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  status ??= _Status();
  setTestSurface(tester, surface);
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
        theme: appleTheme(brightness),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: pane
            ? LogDetailsScreen(log: log ?? _log(), twoColumns: true)
            : Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => showLogDetails(context, log: log ?? _log()),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (!pane) {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
  return status;
}

AppleDetailRow _row(WidgetTester tester, String label) => tester
    .widgetList<AppleDetailRow>(find.byType(AppleDetailRow))
    .singleWhere((row) => row.label == label);

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('sheet has the AdGuard Home rows and two equal footer actions',
      (tester) async {
    await _pump(tester);
    expect(find.byType(AppleSheet), findsOneWidget);
    expect(find.byType(AppleDetailCard), findsNWidgets(3));
    expect(find.byType(AppleListSection), findsNothing);
    expect(find.byType(ApplePill), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.globe), findsNothing);
    expect(
      tester.widgetList<AppleDetailRow>(find.byType(AppleDetailRow))
          .map((row) => row.label),
      [l.time, l.date, l.domain, l.type, l.logProtocol,
        l.status, l.logReason, l.logDetailServedFromCache, l.dnsServer,
        l.elapsedTime, l.responseCode, l.response,
        l.logDetailAddress, l.deviceName],
    );
    for (final label in [l.time, l.date, l.type, l.responseCode,
        l.response, l.dnsServer, l.elapsedTime, l.logDetailAddress]) {
      expect(_row(tester, label).mono, isTrue);
    }
    expect(_row(tester, l.deviceName).value, 'livingroom-mac');
    expect(_row(tester, l.logDetailAddress).value, '192.168.1.20');
    expect(_row(tester, l.response).value, 'A  10.0.0.1  TTL 300');
    expect(_row(tester, l.elapsedTime).value, '1.2 ms');
    expect(_row(tester, l.logDetailServedFromCache).value, l.no);
    final buttons = find.descendant(
      of: find.byType(AppleFormFooter), matching: find.byType(AppleFormButton));
    expect(tester.getSize(buttons.first), tester.getSize(buttons.last));
    expect(tester.getSize(buttons.first).height, 48);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 1000.0]) {
    testWidgets('close stays at the sheet right inset at width $width',
        (tester) async {
      await _pump(tester, surface: Size(width, 844));
      final sheet = tester.getRect(find.byType(AppleSheet));
      final close = tester.getRect(find.byType(IconButton));
      expect(close.right, closeTo(sheet.right - 20, 0.1));
      expect(tester.getRect(find.byType(ApplePill)).left,
          closeTo(sheet.left + 20, 0.1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('long status keeps close reachable at large text scale',
      (tester) async {
    await _pump(tester,
      log: _log(reason: 'NotFilteredError'),
      surface: const Size(320, 568), textScale: 2);
    final sheet = tester.getRect(find.byType(AppleSheet));
    final close = tester.getRect(find.byType(IconButton));
    expect(close.right, closeTo(sheet.right - 20, 0.1));
    expect(tester.getRect(find.byType(ApplePill)).right,
        lessThanOrEqualTo(close.left - 8));
    expect(find.byType(IconButton).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chinese elapsed label matches the prototype', (tester) async {
    await _pump(tester, locale: const Locale('zh', 'CN'));
    expect(_row(tester, '处理耗时').value, '1.2 ms');
    expect(tester.takeException(), isNull);
  });

  for (final entry in {
    'FilteredBlackList': 'blocked',
    'NotFilteredWhiteList': 'allowed',
    'NotFilteredNotFound': 'upstream',
    'Rewrite': 'rewrite',
    'Whatever': 'unknown',
    'NotFilteredError': 'error',
  }.entries) {
    testWidgets('${entry.value} status is not confused with a block', (tester) async {
      await _pump(tester, log: _log(reason: entry.key));
      final expected = {
        'blocked': l.queryBlocked,
        'allowed': l.queryAllowed,
        'upstream': l.queryUpstream,
        'rewrite': l.rewrite,
        'error': l.processedErrorRow,
        'unknown': l.unknownResult,
      }[entry.value];
      // The header pill keeps the app's vocabulary; the status row has to read
      // like the AdGuard Home web UI, which knows four statuses.
      final expectedRow = {
        'blocked': l.queryBlocked,
        'allowed': l.queryAllowed,
        'upstream': l.logStatusProcessed,
        'rewrite': l.logStatusRewritten,
        'error': l.logStatusProcessed,
        'unknown': l.logStatusProcessed,
      }[entry.value];
      expect(_row(tester, l.status).value, expectedRow);
      expect(tester.widget<ApplePill>(find.byType(ApplePill)).label, expected);
      expect(find.text(l.addToBlockList), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cache is allowed rather than falsely marked as an upstream call',
      (tester) async {
    await _pump(tester, log: _log(cached: true));
    expect(_row(tester, l.status).value, l.logStatusProcessed);
    expect(_row(tester, l.logDetailServedFromCache).value, l.yes);
  });

  testWidgets('missing size answers and invalid elapsed values omit their rows',
      (tester) async {
    await _pump(tester, log: _log(size: null, answers: [], elapsed: 'NaN'));
    final labels = tester.widgetList<AppleDetailRow>(find.byType(AppleDetailRow))
        .map((row) => row.label);
    expect(labels, isNot(contains(l.responseSize)));
    expect(labels, isNot(contains(l.response)));
    expect(labels, isNot(contains(l.elapsedTime)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('every answer renders as its own line with type value and ttl',
      (tester) async {
    await _pump(tester, log: _log(answers: [
      Answer(type: 'A', value: '10.0.0.1', ttl: 60),
      Answer(type: 'A', value: '10.0.0.2', ttl: 60),
      Answer(type: 'AAAA', value: '::1', ttl: 300),
    ]));
    expect(_row(tester, l.response).value,
        'A  10.0.0.1  TTL 60\nA  10.0.0.2  TTL 60\nAAAA  ::1  TTL 300');
  });

  testWidgets('copy writes the domain and keeps the sheet open', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = call.arguments['text'];
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await _pump(tester);
    await tester.tap(find.text(l.copyDomain));
    await tester.pumpAndSettle();
    expect(copied, 'ads.example.com');
    expect(find.byType(AppleSheet), findsOneWidget);
    expect(find.text(l.domainCopiedClipboard), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('block waits for success and prevents duplicate submissions',
      (tester) async {
    final status = _Status()..pending = Completer<bool>();
    await _pump(tester, status: status);
    await tester.tap(find.text(l.addToBlockList));
    await tester.pumpAndSettle();
    expect(find.byType(AppleSheet), findsOneWidget);
    expect(find.text(l.savingUserFilters), findsOneWidget);
    await tester.tap(find.text(l.savingUserFilters));
    expect(status.calls, [{'domain': 'ads.example.com', 'status': 'block'}]);
    status.pending!.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(AppleSheet), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(find.text(l.addedToBlockList), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  for (final throws in [false, true]) {
    testWidgets('failed block stays open and can retry (throws=$throws)',
        (tester) async {
      final status = _Status()..result = false..throws = throws;
      await _pump(tester, status: status);
      await tester.tap(find.text(l.addToBlockList));
      await tester.pumpAndSettle();
      expect(find.byType(AppleSheet), findsOneWidget);
      expect(find.text(l.userFilteringRulesNotUpdated), findsOneWidget);
      status.result = true;
      status.throws = false;
      await tester.tap(find.text(l.addToBlockList));
      await tester.pumpAndSettle();
      expect(status.calls.length, 2);
      expect(find.byType(AppleSheet), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dismiss during save does not pop the underlying page',
      (tester) async {
    final status = _Status()..pending = Completer<bool>();
    await _pump(tester, status: status);
    await tester.tap(find.text(l.addToBlockList));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l.close));
    await tester.pumpAndSettle();
    status.pending!.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.byType(AppleSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('null domain disables copy and block rather than closing the sheet',
      (tester) async {
    final status = await _pump(tester, log: _log(domain: null));
    final buttons = tester.widgetList<AppleFormButton>(find.byType(AppleFormButton));
    expect(buttons.every((button) => button.onPressed == null), isTrue);
    await tester.tap(find.text(l.copyDomain));
    await tester.tap(find.text(l.addToBlockList));
    expect(find.byType(AppleSheet), findsOneWidget);
    expect(status.calls, isEmpty);
  });

  testWidgets('unavailable filtering disables block without disabling copy',
      (tester) async {
    await _pump(tester, status: _Status(loaded: false));
    final buttons = tester.widgetList<AppleFormButton>(find.byType(AppleFormButton)).toList();
    expect(buttons.first.onPressed, isNotNull);
    expect(buttons.last.onPressed, isNull);
  });

  testWidgets('wide pane shares the card and does not add a back button',
      (tester) async {
    await _pump(tester, pane: true, surface: const Size(1000, 900));
    expect(find.byType(AppleScreen), findsOneWidget);
    expect(find.byType(AppleSheet), findsNothing);
    expect(find.byType(AppleDetailRow), findsNWidgets(14));
    expect(find.byIcon(CupertinoIcons.back), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small window and large text keep actions reachable', (tester) async {
    await _pump(tester,
      log: _log(domain: '${'long-label.' * 12}example.org'),
      surface: const Size(320, 568), textScale: 1.5);
    expect(find.text(l.copyDomain).hitTestable(), findsOneWidget);
    expect(find.text(l.addToBlockList).hitTestable(), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('query response size survives JSON roundtrip', () {
    expect(Log.fromJson(_log().toJson()).size, 124);
    expect(Log.fromJson(_log(size: null).toJson()).size, isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('log detail ${brightness.name} golden', (tester) async {
      await _pump(tester, brightness: brightness);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/log_detail_${brightness.name}.png'));
      expect(tester.takeException(), isNull);
    });
  }
}
