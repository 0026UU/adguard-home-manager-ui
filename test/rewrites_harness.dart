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
import 'package:adguard_home_manager/models/rewrite_rules.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/rewrite_rules_provider.dart';
import 'package:adguard_home_manager/screens/settings/dns_rewrites/dns_rewrites.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

// The rewrite page reads `/rewrite/list` and writes back through
// `/rewrite/add`, `/rewrite/update` and `/rewrite/delete`. No test here can
// reach a server, so the provider below answers from the fixtures and records
// what the taps asked for.

/// The six rules the design layer draws on the rewrite page.
List<RewriteRules> rewriteFixture({bool disablePrinter = false}) => [
  RewriteRules(domain: 'nas.local', answer: '192.168.1.5', enabled: true),
  RewriteRules(domain: 'router.lan', answer: '192.168.1.1', enabled: true),
  RewriteRules(
    domain: 'printer.local',
    answer: '192.168.1.66',
    enabled: !disablePrinter,
  ),
  RewriteRules(domain: 'jellyfin.tv', answer: '192.168.1.5', enabled: true),
  RewriteRules(domain: 'vault', answer: '10.8.0.2', enabled: true),
  RewriteRules(domain: '*.dev', answer: '127.0.0.1', enabled: true),
];

/// A rewrite provider that never touches the API client.
class RewriteStub extends RewriteRulesProvider {
  RewriteStub(List<RewriteRules> rules, {this.succeeds = true})
      : stored = List<RewriteRules>.from(rules);

  final List<RewriteRules> stored;
  final bool succeeds;

  /// Keeps the page in its loading state until the test releases the gate.
  bool blocks = false;

  final List<RewriteRules> added = [];
  final List<List<RewriteRules>> edited = [];
  final List<RewriteRules> deleted = [];
  int fetches = 0;

  /// Holds a write open so the test can see the blocking progress dialog.
  bool blockWrites = false;

  final Completer<void> gate = Completer<void>();
  final Completer<void> writes = Completer<void>();

  /// A real call answers after the frame, so the page never hears about new
  /// data while it is still building.
  Future<void> _settled() => Future<void>.delayed(Duration.zero);

  Future<void> _answered() async {
    await _settled();
    if (blockWrites) await writes.future;
  }

  @override
  Future<bool> fetchData({bool? showLoading}) async {
    await _settled();
    if (blocks) await gate.future;
    fetches++;
    if (!succeeds) {
      setRewriteRulesLoadStatus(LoadStatus.error, true);
      return false;
    }
    setRewriteRulesData(stored);
    setRewriteRulesLoadStatus(LoadStatus.loaded, true);
    return true;
  }

  @override
  Future<bool> addDnsRewrite(RewriteRules rule) async {
    await _answered();
    if (!succeeds) return false;
    added.add(rule);
    stored.add(rule);
    setRewriteRulesData(stored);
    return true;
  }

  @override
  Future<bool> editDnsRewrite(RewriteRules newRule, RewriteRules oldRule) async {
    await _answered();
    if (!succeeds) return false;
    edited.add([newRule, oldRule]);
    stored[stored.indexOf(oldRule)] = newRule;
    setRewriteRulesData(stored);
    return true;
  }

  @override
  Future<bool> deleteDnsRewrite(RewriteRules rule) async {
    await _answered();
    if (!succeeds) return false;
    deleted.add(rule);
    stored.removeWhere((item) => item.domain == rule.domain);
    setRewriteRulesData(stored);
    return true;
  }
}

class RewriteHarness {
  RewriteHarness(this.stub, this.appConfig);

  final RewriteStub stub;
  final AppConfigProvider appConfig;
}

/// Pumps the rewrite page the way the settings list pushes it.
///
/// The route is pushed rather than used as the home widget because the page
/// draws its own back capsule, which only appears when there is a route to go
/// back to. The surface is tall by default so every rule stays tappable: a
/// [CustomScrollView] only builds what fits its viewport.
Future<RewriteHarness> pumpRewrites(
  WidgetTester tester, {
  List<RewriteRules>? rules,
  bool succeeds = true,
  bool blocks = false,
  bool blockWrites = false,
  Brightness brightness = Brightness.light,
  Size surface = const Size(390, 1400),
  bool settle = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final stub = RewriteStub(
    rules ?? rewriteFixture(),
    succeeds: succeeds,
  )..blocks = blocks
  ..blockWrites = blockWrites;
  final appConfig = AppConfigProvider(sharedPreferencesInstance: prefs);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfigProvider>.value(value: appConfig),
        ChangeNotifierProvider<RewriteRulesProvider>.value(value: stub),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: globalNavigatorKey,
        theme: brightness == Brightness.dark ? appleDarkTheme() : appleLightTheme(),
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
                    builder: (_) => const DnsRewritesScreen(),
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
  // A gated load keeps its spinner turning, so settling would never finish.
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  return RewriteHarness(stub, appConfig);
}
