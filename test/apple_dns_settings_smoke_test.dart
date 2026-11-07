import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/screens/settings/dns/bootstrap_dns.dart';
import 'package:adguard_home_manager/screens/settings/dns/cache_config.dart';
import 'package:adguard_home_manager/screens/settings/dns/clear_dns_cache_dialog.dart';
import 'package:adguard_home_manager/screens/settings/dns/dns_server_settings.dart';
import 'package:adguard_home_manager/screens/settings/dns/test_upstream_dns_modal.dart';
import 'package:adguard_home_manager/screens/settings/dns/upstream_dns.dart';
import 'package:adguard_home_manager/screens/settings/dns/rate_limit_allowlist_modal.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'dns_settings_harness.dart';

// DNS settings is the page the design layer draws from `/dns_info`. Every row
// either reads a field of that answer or opens the screen that has always
// edited the field, and the two switches on the page write the same payloads
// those screens write. The tests below hold the page to that.

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the upstreams are one Apple group under the page title', (tester) async {
    final h = await pumpDns(tester);

    expect(tester.takeException(), isNull);
    // The page read `/dns_info` exactly once while opening.
    expect(h.api.reads, 1);

    // The collapsing title carries the page name and its one-line summary.
    expect(
      find.descendant(
        of: find.byType(AppleLargeTitle),
        matching: find.text(l.dnsSettings),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppleLargeTitle),
        matching: find.text(l.dnsSettingsSubtitle),
      ),
      findsOneWidget,
    );
    expect(find.byType(AppleBackButton), findsOneWidget);

    // Two groups, each with its own caption.
    expect(find.byType(AppleListSection), findsNWidgets(2));
    expect(find.text(l.upstreamDns), findsOneWidget);
    expect(find.text(l.advancedSettings), findsOneWidget);
    expect(find.widgetWithText(AppleHeaderAction, l.add), findsOneWidget);

    // One row per upstream, drawn as code, then the rows around them.
    expect(find.widgetWithText(AppleListTile, '9.9.9.9'), findsOneWidget);
    expect(find.widgetWithText(AppleListTile, 'tls://dns.example.com'), findsOneWidget);
    expect(find.widgetWithText(AppleListTile, '1.1.1.1'), findsOneWidget);
    expect(find.widgetWithText(AppleListTile, l.bootstrapDns), findsOneWidget);
    expect(find.widgetWithText(AppleListTile, l.fallbackDnsServers), findsOneWidget);
    expect(find.widgetWithText(AppleListTile, l.dotDoqUpstreams), findsOneWidget);

    // The two switches the design layer draws for this page.
    expect(find.byType(AppleSwitchListTile), findsNWidgets(2));
    expect(find.byType(CupertinoSwitch), findsNWidgets(2));
    expect(
      tester.widget<AppleSwitchListTile>(
        find.widgetWithText(AppleSwitchListTile, l.enableEdns),
      ).value,
      true,
    );

    // No Material chrome is left on the page itself.
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Card), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    for (final scaffold in tester.widgetList<Scaffold>(find.byType(Scaffold))) {
      expect(scaffold.appBar, isNull);
    }
  });

  testWidgets('every value is the field the server sent', (tester) async {
    await pumpDns(tester);

    String row(String title) =>
        tester.widget<AppleListTile>(find.widgetWithText(AppleListTile, title)).value!;

    // One of the three upstreams is reached over TLS. The count sits in the
    // capsule before the disclosure, not in the value slot, which is what
    // squeezed the title onto a second line.
    expect(
      tester.widget<AppleListTile>(
        find.widgetWithText(AppleListTile, l.dotDoqUpstreams),
      ).value,
      isNull,
    );
    expect(find.widgetWithText(ApplePill, '1'), findsOneWidget);
    expect(row(l.rateLimit), l.queriesPerSecond(20));
    expect(row(l.dnsCacheSize), '4 MB');
    expect(row(l.overrideMinimumTtl), l.seconds(10));
    expect(row(l.overrideMaximumTtl), l.seconds(600));

    expect(
      tester.widget<AppleListTile>(find.widgetWithText(AppleListTile, l.bootstrapDns))
          .subtitle,
      '9.9.9.9 · 149.112.112.112',
    );
    // An upstream row is code, not a title.
    expect(
      tester.widget<AppleListTile>(find.widgetWithText(AppleListTile, '9.9.9.9')).mono,
      true,
    );
    // A list of upstreams is not a disclosure.
    expect(
      tester.widget<AppleListTile>(find.widgetWithText(AppleListTile, '9.9.9.9'))
          .showChevron,
      false,
    );
  });

  testWidgets('a rate limit of zero says disabled, not zero', (tester) async {
    await pumpDns(tester, info: dnsInfoFixture(ratelimit: 0, cacheSize: null));

    expect(
      tester.widget<AppleListTile>(find.widgetWithText(AppleListTile, l.rateLimit)).value,
      l.disabled,
    );
    // A cache the server never sized leaves the value away instead of a zero.
    expect(
      tester.widget<AppleListTile>(find.widgetWithText(AppleListTile, l.dnsCacheSize)).value,
      isNull,
    );
  });

  testWidgets('a server without upstreams or fallbacks draws neither list', (tester) async {
    await pumpDns(
      tester,
      info: dnsInfoFixture(upstreamDns: [], fallbackDns: null, bootstrapDns: []),
    );

    expect(find.widgetWithText(AppleListTile, l.noUpstreamDns), findsOneWidget);
    expect(find.widgetWithText(AppleListTile, l.dotDoqUpstreams), findsOneWidget);
    // Nothing encrypted to count, so the capsule stays away instead of
    // reporting a bare zero.
    expect(find.byType(ApplePill), findsNothing);
    expect(tester.widget<AppleListTile>(
      find.widgetWithText(AppleListTile, l.dotDoqUpstreams),
    ).trailing, isNull);
    expect(find.widgetWithText(AppleListTile, l.fallbackDnsServers), findsNothing);
    expect(
      tester.widget<AppleListTile>(find.widgetWithText(AppleListTile, l.bootstrapDns))
          .subtitle,
      l.noBootstrapDns,
    );
  });

  testWidgets('the parallel switch writes the mode and nothing else', (tester) async {
    final h = await pumpDns(tester, blockWrites: true);

    // The mode the server reported was "fastest_addr", so the switch is off.
    // Only the switch itself answers, the way an iOS row does.
    final parallel = find.byType(CupertinoSwitch).at(0);
    expect(
      tester.widget<AppleSwitchListTile>(
        find.widgetWithText(AppleSwitchListTile, l.parallelRequests),
      ).value,
      false,
    );
    expect(
      tester.widget<AppleSwitchListTile>(
        find.widgetWithText(AppleSwitchListTile, l.parallelRequests),
      ).value,
      false,
    );

    await tester.tap(parallel);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The write blocks behind the progress dialog until the server answers.
    expect(find.text(l.savingConfig), findsOneWidget);

    h.api.writesGate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final payload = h.api.writes.single;
    expect(payload.keys.toList()..sort(), [
      'upstream_dns',
      'upstream_mode',
      'upstream_timeout',
    ].sorted());
    expect(payload['upstream_mode'], 'parallel');
    expect(payload['upstream_dns'], ['9.9.9.9', 'tls://dns.example.com', '1.1.1.1']);
    expect(payload['upstream_timeout'], 5000);
    expect(find.text(l.dnsConfigSaved), findsOneWidget);
    expect(
      tester.widget<AppleSwitchListTile>(
        find.widgetWithText(AppleSwitchListTile, l.parallelRequests),
      ).value,
      true,
    );

    // Switching back off returns to the mode the server had reported.
    h.api.writesGate = Completer<void>();
    await tester.tap(parallel);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    h.api.writesGate.complete();
    await tester.pumpAndSettle();

    expect(h.api.writes.last['upstream_mode'], 'fastest_addr');
    expect(
      tester.widget<AppleSwitchListTile>(
        find.widgetWithText(AppleSwitchListTile, l.parallelRequests),
      ).value,
      false,
    );

    // A report that arrives while a snackbar is still up waits half a second
    // behind it; let both run out.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the EDNS switch writes the payload of the settings screen', (tester) async {
    final h = await pumpDns(tester);

    await tester.tap(find.byType(CupertinoSwitch).at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final payload = h.api.writes.single;
    expect(payload.keys.toList()..sort(), [
      'blocking_ipv4',
      'blocking_ipv6',
      'blocking_mode',
      'blocked_response_ttl',
      'disable_ipv6',
      'dnssec_enabled',
      'edns_cs_custom_ip',
      'edns_cs_enabled',
      'edns_cs_use_custom',
      'ratelimit',
      'ratelimit_subnet_len_ipv4',
      'ratelimit_subnet_len_ipv6',
      'ratelimit_whitelist',
    ].sorted());
    expect(payload['edns_cs_enabled'], false);
    // Everything the page does not show travels back untouched.
    expect(payload['ratelimit'], 20);
    expect(payload['blocking_mode'], 'refused');
    expect(payload['ratelimit_subnet_len_ipv6'], 56);
    expect(find.text(l.dnsConfigSaved), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refused write reports what the server said', (tester) async {
    final h = await pumpDns(tester, writeSucceeds: false);

    await tester.tap(find.byType(CupertinoSwitch).at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(h.api.writes, hasLength(1));
    expect(find.text(l.dnsConfigNotSaved), findsOneWidget);
    // A write that failed never moves the switch.
    expect(
      tester.widget<AppleSwitchListTile>(
        find.widgetWithText(AppleSwitchListTile, l.enableEdns),
      ).value,
      true,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a row opens the screen that has always edited it', (tester) async {
    await pumpDns(tester);

    await tester.tap(find.widgetWithText(AppleHeaderAction, l.add));
    await tester.pumpAndSettle();
    expect(find.byType(UpstreamDnsScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppleListTile, l.bootstrapDns));
    await tester.pumpAndSettle();
    expect(find.byType(BootstrapDnsScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppleListTile, '9.9.9.9'));
    await tester.pumpAndSettle();
    expect(find.byType(UpstreamDnsScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppleListTile, l.rateLimit));
    await tester.pumpAndSettle();
    expect(find.byType(DnsServerSettingsScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppleListTile, l.dnsCacheSize));
    await tester.pumpAndSettle();
    expect(find.byType(CacheConfigDnsScreen), findsOneWidget);
  });

  testWidgets('the upstream editor writes what is typed into it',
      (tester) async {
    final h = await pumpDns(tester, blockWrites: true);

    await tester.tap(find.widgetWithText(AppleListTile, '9.9.9.9'));
    await tester.pumpAndSettle();
    expect(find.byType(UpstreamDnsScreen), findsOneWidget);

    // The editor is drawn by the design layer: no Material radio list, no bar
    // of buttons. Its own header is the collapsing one, so no Scaffold here
    // carries a Material bar of its own.
    expect(find.byType(RadioListTile), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    for (final scaffold in tester.widgetList<Scaffold>(find.byType(Scaffold))) {
      expect(scaffold.appBar, isNull);
    }
    expect(find.byType(AppleListSection), findsNWidgets(2));

    bool saveEnabled() =>
        tester.widget<IconButton>(find.ancestor(
          of: find.byTooltip(l.save),
          matching: find.byType(IconButton),
        )).onPressed !=
        null;

    // The timeout is the last field of the form and the one furthest down it.
    final timeoutField = find.descendant(
      of: find.byType(UpstreamDnsScreen),
      matching: find.byType(TextFormField).last,
    );
    await tester.ensureVisible(timeoutField);
    await tester.pumpAndSettle();

    // A timeout of nothing is not a timeout, so the save waits.
    await tester.enterText(timeoutField, '');
    await tester.pump();
    expect(saveEnabled(), false);

    await tester.enterText(timeoutField, '5000');
    await tester.pump();
    expect(saveEnabled(), true);

    await tester.enterText(
      find.descendant(
        of: find.byType(UpstreamDnsScreen),
        matching: find.byType(TextFormField),
      ).at(0),
      '208.67.222.222',
    );
    await tester.pump();

    // The mode rows belong to this screen, not to the switch the page behind
    // draws with some of the same words.
    final loadBalancing = find.descendant(
      of: find.byType(UpstreamDnsScreen),
      matching: find.widgetWithText(AppleListTile, l.loadBalancing),
    );
    await tester.ensureVisible(loadBalancing);
    await tester.pumpAndSettle();
    await tester.tap(loadBalancing);
    await tester.pump();

    await tester.tap(find.byTooltip(l.save));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The write blocks behind the progress dialog until the server answers.
    expect(find.text(l.savingConfig), findsOneWidget);

    h.api.writesGate.complete();
    await tester.pumpAndSettle();

    expect(h.api.writes, hasLength(1));
    final payload = h.api.writes.single;
    expect(payload['upstream_dns'], [
      '208.67.222.222',
      'tls://dns.example.com',
      '1.1.1.1',
    ]);
    expect(payload['upstream_mode'], '');
    expect(payload['upstream_timeout'], 5000);
    expect(find.text(l.dnsConfigSaved), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the rate limit allow list reaches the settings payload',
      (tester) async {
    final h = await pumpDns(tester, blockWrites: true);

    await tester.tap(find.widgetWithText(AppleListTile, l.rateLimit));
    await tester.pumpAndSettle();
    expect(find.byType(DnsServerSettingsScreen), findsOneWidget);

    final allowRow = find.widgetWithText(AppleListTile, l.rateLimitAllowlist);
    await tester.ensureVisible(allowRow);
    await tester.pumpAndSettle();
    await tester.tap(allowRow);
    await tester.pumpAndSettle();
    expect(find.byType(RateLimitAllowlistModal), findsOneWidget);

    // The server published no addresses, so the editor starts empty and the
    // add action of the design layer is what fills it.
    expect(find.byType(ElevatedButton), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(RateLimitAllowlistModal),
        matching: find.widgetWithText(AppleButton, l.addItem),
      ),
    );
    await tester.pumpAndSettle();

    final ipField = find.descendant(
      of: find.byType(RateLimitAllowlistModal),
      matching: find.byType(TextFormField),
    );
    bool confirmEnabled() =>
        tester.widget<AppleFormButton>(find.descendant(
          of: find.byType(RateLimitAllowlistModal),
          matching: find.widgetWithText(AppleFormButton, l.confirm),
        )).onPressed !=
        null;

    await tester.enterText(ipField, 'not-an-address');
    await tester.pump();
    expect(confirmEnabled(), false);
    expect(find.text(l.invalidIp), findsOneWidget);

    await tester.enterText(ipField, '10.8.0.9');
    await tester.pump();
    expect(confirmEnabled(), true);

    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();
    expect(find.byType(RateLimitAllowlistModal), findsNothing);

    await tester.tap(find.byTooltip(l.save));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(l.savingConfig), findsOneWidget);

    h.api.writesGate.complete();
    await tester.pumpAndSettle();

    expect(h.api.writes, hasLength(1));
    expect(h.api.writes.single['ratelimit_whitelist'], ['10.8.0.9']);
    expect(find.text(l.dnsConfigSaved), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the actions still test the upstreams and clear the cache', (tester) async {
    final h = await pumpDns(tester);

    await tester.tap(find.byTooltip(l.testUpstreamDnsServers));
    await tester.pumpAndSettle();
    expect(find.byType(TestUpstreamDnsModal), findsOneWidget);
    expect(find.text('tls://dns.example.com'), findsWidgets);

    await tester.tap(find.text(l.close));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(l.clearDnsCache));
    await tester.pumpAndSettle();
    expect(find.byType(ClearDnsCacheDialog), findsOneWidget);

    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();
    expect(h.api.cacheClears, isEmpty);

    await tester.tap(find.byTooltip(l.clearDnsCache));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.confirm));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(h.api.cacheClears, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the configuration loads behind an Apple spinner', (tester) async {
    final h = await pumpDns(tester, blocks: true, settle: false);

    expect(find.byType(AppleLoading), findsOneWidget);
    expect(find.text(l.loadingDnsConfig), findsOneWidget);
    expect(find.byType(AppleListTile), findsNothing);

    h.api.gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(AppleLoading), findsNothing);
    expect(find.byType(AppleListSection), findsNWidgets(2));
  });

  testWidgets('a failed read reports the Apple way', (tester) async {
    await pumpDns(tester, fails: true);

    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(find.text(l.dnsConfigNotLoaded), findsOneWidget);
    expect(find.byType(AppleListTile), findsNothing);
    expect(find.byIcon(CupertinoIcons.exclamationmark_triangle), findsOneWidget);

    // The pull handle belongs to the list, and the list is what never came,
    // so the card has to carry the retry itself.
    expect(find.widgetWithText(AppleFormButton, l.refresh), findsOneWidget);
  });

  testWidgets('the retry on the refused read asks the server again',
      (tester) async {
    await pumpDns(tester, fails: true);

    // The server behind this page answers fine; only the first status was
    // forced to error, so a retry that really retries lands on the config.
    await tester.tap(find.widgetWithText(AppleFormButton, l.refresh));
    await tester.pumpAndSettle();

    expect(find.byType(AppleEmptyState), findsNothing);
    expect(find.byType(AppleListSection), findsWidgets);
  });

  testWidgets('a refresh that finds no server stops showing the old config',
      (tester) async {
    final h = await pumpDns(tester);

    // The page read the config, so it is entitled to draw it.
    expect(find.byType(AppleListSection), findsWidgets);

    // The refresh then finds nobody on the other end. The upstreams from the
    // last good read are still in the provider, and a page that keeps drawing
    // them is claiming the server still agrees with them.
    h.api.succeeds = false;
    await tester.tap(find.byIcon(CupertinoIcons.arrow_clockwise));
    await tester.pumpAndSettle();

    expect(find.byType(AppleListSection), findsNothing);
    expect(find.text(l.dnsConfigNotLoaded), findsOneWidget);
    expect(find.widgetWithText(AppleFormButton, l.refresh), findsOneWidget);
  });
}

extension on List<String> {
  List<String> sorted() => [...this]..sort();
}
