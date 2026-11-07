import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/functions/base64.dart';
import 'package:adguard_home_manager/models/blocked_services.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/models/encryption.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';
import 'package:adguard_home_manager/models/safe_search.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/models/server_info.dart';
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/services/api_client.dart';

/// Drives the app's own API layer against a real AdGuard Home.
///
/// Nothing here is mocked: the payload is the map [Client.toJson] produces, so
/// a field the form collects but the request drops fails the test. The run is
/// opt-in because it writes to a server — set `AGH_LIVE_URL`, `AGH_LIVE_USER`
/// and `AGH_LIVE_PASS` in the environment. Credentials are read from there and
/// never from a file.
void main() {
  final url = Platform.environment['AGH_LIVE_URL'];
  final user = Platform.environment['AGH_LIVE_USER'];
  final pass = Platform.environment['AGH_LIVE_PASS'];

  final String? skip = url == null || user == null || pass == null
      ? 'set AGH_LIVE_URL, AGH_LIVE_USER and AGH_LIVE_PASS to run this against a real server'
      : null;

  const name = 'agh-ui-probe';

  late ApiClientV2 api;
  late List<String> tags;
  late List<String> catalog;

  setUpAll(() async {
    if (skip != null) return;

    final uri = Uri.parse(url!);
    api = ApiClientV2(
      server: Server(
        id: 'live',
        name: 'live',
        connectionMethod: uri.scheme,
        domain: uri.host,
        port: uri.hasPort ? uri.port : null,
        authToken: encodeBase64UserPass(user!, pass!),
        defaultServer: false,
        runningOnHa: false,
      ),
    );

    // A leftover of an earlier run that failed halfway would make the first
    // write below fail with "client already exists".
    await api.postDeleteClient(name: name);

    final clients = await api.getClients();
    expect(clients.successful, isTrue, reason: 'the server did not answer /clients');
    tags = (clients.content as Clients).supportedTags;

    // The catalog the services picker offers, read through the model the
    // picker builds its rows from.
    final services = await api.getBlockedServices();
    expect(services.successful, isTrue);
    catalog = (services.content as List<BlockedService>)
        .map((service) => service.id)
        .toList();

    expect(tags, isNotEmpty, reason: 'the server offers no tag to pick');
    expect(catalog, isNotEmpty, reason: 'the server offers no service to block');
  });

  Future<Client> readBack() async {
    final result = await api.getClients();
    expect(result.successful, isTrue);
    final entries = (result.content as Clients).clients
        .where((c) => c.name == name)
        .toList();
    expect(entries, hasLength(1), reason: 'the server does not list the entry');
    return entries.single;
  }

  Client entry({
    String entryName = name,
    // TEST-NET-1, so the probe cannot collide with an address a real server
    // already has a device on.
    List<String> ids = const ['192.0.2.11', 'aa:bb:cc:dd:ee:ff'],
    List<String> entryTags = const [],
    List<String> upstreams = const ['1.1.1.1', 'https://dns.example/dns-query'],
    List<String> rules = const [],
    bool useGlobalSettings = false,
    bool filteringEnabled = true,
    bool parentalEnabled = true,
    bool safebrowsingEnabled = true,
    SafeSearch? safeSearch,
    bool useGlobalBlockedServices = false,
    List<String> blockedServices = const [],
    bool ignoreQuerylog = true,
    bool ignoreStatistics = true,
    bool upstreamsCacheEnabled = true,
    int? upstreamsCacheSize = 4096,
    BlockedServicesSchedule? schedule,
  }) =>
      Client(
        name: entryName,
        ids: ids,
        tags: entryTags,
        upstreams: upstreams,
        rules: rules,
        useGlobalSettings: useGlobalSettings,
        filteringEnabled: filteringEnabled,
        parentalEnabled: parentalEnabled,
        safebrowsingEnabled: safebrowsingEnabled,
        safeSearch: safeSearch,
        useGlobalBlockedServices: useGlobalBlockedServices,
        blockedServices: blockedServices,
        ignoreQuerylog: ignoreQuerylog,
        ignoreStatistics: ignoreStatistics,
        upstreamsCacheEnabled: upstreamsCacheEnabled,
        upstreamsCacheSize: upstreamsCacheSize,
        blockedServicesSchedule: schedule,
      );

  group('the entry the client form saves', () {
    test(
      'is stored with every field the form collects',
      () async {
        final added = await api.postAddClient(
          data: entry(
            entryTags: [tags.first],
            blockedServices: [catalog.first],
            safeSearch: SafeSearch(
              enabled: true,
              bing: false,
              duckduckgo: true,
              ecosia: false,
              google: true,
              pixabay: false,
              yandex: false,
              youtube: true,
            ),
            schedule: BlockedServicesSchedule(
              timeZone: 'Europe/Madrid',
              mon: BlockedServicesScheduleDay(start: 28800000, end: 61200000),
              fri: BlockedServicesScheduleDay(start: 0, end: 21600000),
            ),
          ).toJson(),
        );
        expect(added.successful, isTrue, reason: 'the server refused the entry');

        final read = await readBack();

        expect(read.ids, ['192.0.2.11', 'aa:bb:cc:dd:ee:ff']);
        expect(read.tags, [tags.first]);
        expect(read.upstreams, ['1.1.1.1', 'https://dns.example/dns-query']);
        expect(read.useGlobalSettings, isFalse);
        expect(read.filteringEnabled, isTrue);
        expect(read.parentalEnabled, isTrue);
        expect(read.safebrowsingEnabled, isTrue);
        expect(read.useGlobalBlockedServices, isFalse);
        expect(read.blockedServices, [catalog.first]);
        expect(read.ignoreQuerylog, isTrue);
        expect(read.ignoreStatistics, isTrue);
        expect(read.upstreamsCacheEnabled, isTrue);
        expect(read.upstreamsCacheSize, 4096);

        // The per-device safe search is the field an earlier build dropped from
        // the request, so the server answered with the global default instead.
        expect(read.safeSearch, isNotNull, reason: 'safe search was not stored');
        expect(read.safeSearch!.enabled, isTrue);
        expect(read.safeSearch!.duckduckgo, isTrue);
        expect(read.safeSearch!.google, isTrue);
        expect(read.safeSearch!.youtube, isTrue);
        expect(read.safeSearch!.bing, isFalse);

        final stored = read.blockedServicesSchedule;
        expect(stored, isNotNull, reason: 'the schedule was not stored');
        expect(stored!.timeZone, 'Europe/Madrid');
        expect(stored.mon?.start, 28800000);
        expect(stored.mon?.end, 61200000);
        expect(stored.fri?.start, 0);
        expect(stored.fri?.end, 21600000);
        expect(stored.tue, isNull);
      },
      skip: skip,
    );

    test(
      'is rewritten in place by an edit',
      () async {
        final edited = await api.postUpdateClient(
          data: {
            'name': name,
            'data': entry(
              ids: const ['192.0.2.12'],
              upstreams: const [],
              useGlobalSettings: true,
              filteringEnabled: false,
              parentalEnabled: false,
              safebrowsingEnabled: false,
              useGlobalBlockedServices: true,
              ignoreQuerylog: false,
              ignoreStatistics: false,
              upstreamsCacheEnabled: false,
              upstreamsCacheSize: null,
              schedule: BlockedServicesSchedule(),
            ).toJson(),
          },
        );
        expect(edited.successful, isTrue, reason: 'the server refused the edit');

        final read = await readBack();

        expect(read.ids, ['192.0.2.12']);
        expect(read.tags, isEmpty);
        expect(read.upstreams, isEmpty);
        expect(read.useGlobalSettings, isTrue);
        expect(read.filteringEnabled, isFalse);
        expect(read.useGlobalBlockedServices, isTrue);
        expect(read.blockedServices, isEmpty);
        expect(read.ignoreQuerylog, isFalse);
        expect(read.upstreamsCacheEnabled, isFalse);
        expect(read.safeSearch?.enabled ?? false, isFalse);

        final stored = read.blockedServicesSchedule;
        expect(stored?.mon, isNull);
        expect(stored?.fri, isNull);
      },
      skip: skip,
    );

    test(
      'keeps the rules of the device itself',
      () async {
        final rules = ['||example.org^', '@@||allowed.example^'];

        await api.postDeleteClient(name: name);
        final added = await api.postAddClient(data: entry(rules: rules).toJson());
        expect(added.successful, isTrue, reason: 'the server refused the rules');

        final listed = await api.getClients();
        expect(listed.successful, isTrue);
        if (!(listed.content as Clients).supportsClientRules) {
          // A stock server takes the rules and drops them, which is why the
          // device page hides the group on one. There is nothing to read back.
          markTestSkipped('the server does not keep the rules of a device');
          return;
        }

        final read = await readBack();
        expect(read.rules, rules);
      },
      skip: skip,
    );

    test(
      'leaves the server when it is deleted',
      () async {
        final removed = await api.postDeleteClient(name: name);
        expect(removed.successful, isTrue);

        final result = await api.getClients();
        expect(result.successful, isTrue);
        expect(
          (result.content as Clients).clients.where((c) => c.name == name),
          isEmpty,
        );
      },
      skip: skip,
    );

    test(
      'a nameless entry is refused and not stored',
      () async {
        final refused = await api.postAddClient(
          data: entry(entryName: '').toJson(),
        );
        expect(refused.successful, isFalse);

        final result = await api.getClients();
        expect(
          (result.content as Clients).clients.where((c) => c.name.isEmpty),
          isEmpty,
        );
      },
      skip: skip,
    );

    test(
      'a tag the server does not offer is refused',
      () async {
        final refused = await api.postAddClient(
          data: entry(entryTags: const ['not-a-tag-of-this-server']).toJson(),
        );
        expect(refused.successful, isFalse);

        final result = await api.getClients();
        expect(
          (result.content as Clients).clients.where((c) => c.name == name),
          isEmpty,
        );
      },
      skip: skip,
    );
  });

  group('what /status answers', () {
    test(
      'the fields only the fork reports reach the model the page reads',
      () async {
        final result = await api.getServerInfo();
        expect(result.successful, isTrue, reason: 'the server did not answer /status');

        final data = result.content as ServerInfoData;

        // `arch` and `goos` are the fork's additions: stock AdGuard Home
        // answers neither and the page drops the row that would print them.
        // What has to hold on every server is that they arrive together or not
        // at all, so a half-read answer cannot leave the row showing
        // "windows/" or "/amd64".
        expect(
          data.arch == null,
          data.goos == null,
          reason: 'the platform row would print half an answer',
        );
        expect(data.startTime, isNotNull, reason: 'the server reported no start time');
        expect(data.startTime!.isBefore(DateTime.now()), isTrue);

        expect(data.httpPort, greaterThan(0));
        expect(data.dnsPort, greaterThan(0));
      },
      skip: skip,
    );
  });

  group('what /safesearch/settings keeps', () {
    test('a toggle that only carries the switch leaves the engines alone', () async {
      // The Overview switch used to PUT {"enabled":false} and nothing else.
      // The server replaces the whole object, so that single click silently
      // switched every search engine off.
      final seeded = await api.updateSafeSearchSettings(
        body: {
          'enabled': true,
          'bing': false,
          'duckduckgo': true,
          'ecosia': false,
          'google': true,
          'pixabay': false,
          'yandex': false,
          'youtube': true,
        },
      );
      expect(seeded.successful, isTrue, reason: 'the server refused the mix');

      final toggled = await api.updateSafeSearchSettings(
        body: {'enabled': false},
      );
      expect(toggled.successful, isTrue, reason: 'the server refused the toggle');

      final result = await api.getServerStatus();
      expect(result.successful, isTrue);

      final status = result.content as ServerStatus;
      expect(status.safeSearchEnabled, isFalse, reason: 'the switch did not move');
      expect(status.safeSearchGoogle, isTrue, reason: 'the toggle cleared google');
      expect(status.safeSearchDuckduckgo, isTrue, reason: 'the toggle cleared duckduckgo');
      expect(status.safeSearchYoutube, isTrue, reason: 'the toggle cleared youtube');
      expect(status.safeSeachBing, isFalse, reason: 'the toggle set bing');
    }, skip: skip);
  });

  group('what /tls/status answers', () {
    test(
      'a served certificate carries its fingerprint',
      () async {
        final result = await api.getEncryptionSettings();
        expect(result.successful, isTrue, reason: 'the server did not answer /tls/status');

        final data = result.content as EncryptionData;
        if (!data.enabled || !data.validCert) {
          // A server serving no certificate reports no fingerprint, and the
          // page leaves the row out instead of inventing one.
          expect(data.fingerprintSha256, isNull);
          return;
        }

        // The fork hashes the first certificate of the chain; a stock server
        // never sends the field at all.
        expect(data.fingerprintSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
      },
      skip: skip,
    );
  });

  group('what POST /filtering/refresh answers', () {
    test(
      'the refresh is allowed to take the minutes the server needs',
      () async {
        // v1.0.0-b.2 answers this endpoint with the openapi
        // FilterRefreshResponse — one integer, {"updated": N} — and nothing per
        // list, and re-downloading a single 190k-rule list was measured at
        // 92-126 seconds. The wrapper sent it with the same ten second cap as
        // an ordinary GET, so it was cut off before the answer arrived and the
        // page reported "Couldn't update lists" every single time.
        final before = await api.getFilteringRules();
        expect(
          before.successful,
          isTrue,
          reason: 'the server did not answer /filtering/status',
        );

        final status = before.content as FilteringStatus;
        final enabled = [...status.filters, ...status.whitelistFilters]
            .where((filter) => filter.enabled)
            .toList();
        if (enabled.isEmpty) {
          markTestSkipped('the server has no enabled list to refresh');
          return;
        }

        // A server that has just started is still refreshing the lists it was
        // handed at boot, and refuses with "already running" until that
        // finishes. Wait for it to be free first, or the timed call below
        // measures a refusal instead of a refresh.
        for (var attempt = 0; attempt < 12; attempt++) {
          final probe = await api.updateLists();
          final busy = !probe.successful &&
              (probe.message ?? '').contains('already running');
          if (!busy) break;
          await Future<void>.delayed(const Duration(seconds: 10));
        }

        final watch = Stopwatch()..start();
        final result = await api.updateLists();
        watch.stop();

        expect(
          result.successful,
          isTrue,
          reason: 'the refresh did not complete: ${result.message}',
        );
        // Longer than the cap the call used to be given means the server was
        // really asked to re-download and the answer was waited for.
        expect(
          watch.elapsed,
          greaterThan(const Duration(seconds: 10)),
          reason: 'the refresh came back inside the old ten second cap, so the '
              'server was never given the time to do the work',
        );

        final data = result.content as Map<String, dynamic>;
        final List<String> failed = data['failed'] as List<String>;
        final List<String> updatedLists = data['updated_lists'] as List<String>;
        final List<String> enabledNames = enabled.map((f) => f.name).toList();

        expect(
          data['updated'],
          isA<int>(),
          reason: 'the count of updated lists is what the page has always '
              'read: $data',
        );
        expect(data['total'], enabled.length);

        // A list the server has no rules for is the one the UI has to name:
        // b.2 stamps last_updated even on a failed download and counts only
        // the lists whose data changed, so the rules count is the signal left.
        expect(
          failed,
          containsAll(
            enabled
                .where((filter) => filter.rulesCount == 0)
                .map((filter) => filter.name)
                .toList(),
          ),
          reason: 'the lists that load no rules must be the ones reported',
        );
        expect(
          failed.toSet().intersection(updatedLists.toSet()),
          isEmpty,
          reason: 'a list cannot both fail and update',
        );
        for (final name in [...failed, ...updatedLists]) {
          expect(
            enabledNames,
            contains(name),
            reason: '$name is not an enabled list of this server',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 12)),
      skip: skip,
    );
  });

  group('what a refused write says', () {
    test(
      'the MAC already held by another client reaches the caller',
      () async {
        const holder = 'agh-ui-mac-holder';
        const intruder = 'agh-ui-mac-intruder';
        // A MAC from the range the other cases of this suite use would make
        // those entries the conflicting client, and the message would name an
        // entry this test did not create.
        const mac = 'f4:1d:f2:0a:1b:2c';

        await api.postDeleteClient(name: holder);
        await api.postDeleteClient(name: intruder);

        final first = await api.postAddClient(
          data: entry(entryName: holder, ids: const ['192.0.2.221', mac]).toJson(),
        );
        expect(first.successful, isTrue, reason: 'the server refused the holder: ${first.message}');

        final refused = await api.postAddClient(
          data: entry(entryName: intruder, ids: const ['192.0.2.222', mac]).toJson(),
        );
        expect(refused.successful, isFalse, reason: 'the server took the duplicate MAC');

        // The 400 body is the whole diagnosis — the server says who holds the
        // address — and the wrapper used to throw it away, leaving the page
        // with "Client could not be updated".
        expect(
          refused.message,
          allOf(contains(holder), contains('MAC'), contains(mac)),
          reason: 'the reason the server gave did not reach the caller: '
              '${refused.message}',
        );
        expect(refused.statusCode, isNull, reason: 'the wrappers that did not '
            'report a status code before must not start now');

        final listed = await api.getClients();
        expect(
          (listed.content as Clients).clients.where((c) => c.name == intruder),
          isEmpty,
        );

        await api.postDeleteClient(name: holder);
      },
      skip: skip,
    );

    test(
      'a client edit that names nothing reaches the caller',
      () async {
        final refused = await api.postUpdateClient(
          data: {
            'name': 'agh-ui-not-a-client',
            'data': entry(entryName: 'agh-ui-not-a-client').toJson(),
          },
        );
        expect(refused.successful, isFalse);
        expect(
          refused.message,
          allOf(contains('agh-ui-not-a-client'), contains('not found')),
          reason: 'the reason the server gave did not reach the caller: '
              '${refused.message}',
        );
      },
      skip: skip,
    );

    test(
      'a rewrite rule with no answer reaches the caller',
      () async {
        final refused = await api.addDnsRewriteRule(
          data: const {'domain': 'agh-ui-probe.test', 'answer': ''},
        );
        expect(refused.successful, isFalse);
        expect(
          refused.message,
          contains('empty'),
          reason: 'the reason the server gave did not reach the caller: '
              '${refused.message}',
        );
      },
      skip: skip,
    );

    test(
      'a filter list that is not on the server reaches the caller',
      () async {
        final refused = await api.updateFilterList(
          data: const {
            'data': {
              'url': 'https://agh-ui-probe.invalid/list.txt',
              'name': 'agh-ui-probe',
              'whitelist': false,
            },
          },
        );
        expect(refused.successful, isFalse);
        expect(
          refused.message,
          contains("doesn't exist"),
          reason: 'the reason the server gave did not reach the caller: '
              '${refused.message}',
        );
      },
      skip: skip,
    );

    test(
      'a write that succeeded carries no reason',
      () async {
        const written = 'agh-ui-was-written';
        await api.postDeleteClient(name: written);

        final added = await api.postAddClient(
          data: entry(entryName: written, ids: const ['192.0.2.223']).toJson(),
        );
        expect(added.successful, isTrue, reason: added.message);
        expect(added.message, isNull, reason: 'a 200 has nothing to explain');

        await api.postDeleteClient(name: written);

        final removed = await api.postDeleteClient(name: written);
        expect(removed.successful, isFalse);
        expect(
          removed.message,
          isNotNull,
          reason: 'the second delete is refused, and the refusal has a body',
        );
      },
      skip: skip,
    );
  });
}
