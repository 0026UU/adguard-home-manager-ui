import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/models/dns_statistics.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/services/api_client.dart';

const _preservedRules = <String>[
  '||sub.example.com^',
  '@@||sub.example.com^',
  '||notexample.com^',
  '||example.com.other^',
  '||other.test^',
  r'||example.com^$client=192.0.2.1',
  r'@@||example.com^$client=192.0.2.1',
  r'||example.com^$important',
  r'@@||example.com^$important',
  r'||EXAMPLE.COM.^$important',
  r'||example.com^$dnstype=A',
  r'@@||example.com^$domain=other.test',
  r'||example.com^$dnsrewrite=NOERROR;A;192.0.2.1',
  r'||example.com^$badfilter',
  '! example.com is mentioned in a comment',
  '# example.com',
  '! ||example.com^',
  r'/example\.com/',
  '0.0.0.0 example.com',
  'example.com',
  '@@example.com',
  '||example.com',
  '||example.com/path^',
  '||*.example.com^',
  '||example.com^|',
  '||example.com^ custom',
  ' ||example.com^',
  '||example.com^ ',
  '||example.com^\n',
  '||example.com^\n||another.test^',
  '||example.com..^',
  '',
];

FilteringStatus _latestFiltering() => FilteringStatus(
  filters: [
    Filter(
      url: 'https://filters.example/block.txt',
      name: 'Latest blocklist',
      id: 7,
      rulesCount: 123,
      enabled: true,
      lastUpdated: DateTime.utc(2026, 1, 2),
    ),
  ],
  whitelistFilters: [
    Filter(
      url: 'https://filters.example/allow.txt',
      name: 'Latest allowlist',
      id: 8,
      rulesCount: 45,
      enabled: false,
    ),
  ],
  userRules: [
    '||example.com^',
    _preservedRules.first,
    '@@||example.com^',
    ..._preservedRules.skip(1),
    '||EXAMPLE.COM^',
    '@@||ExAmPlE.CoM^',
    '||example.com.^',
    '@@||EXAMPLE.COM.^',
    '||example.com^',
  ],
  interval: 48,
  enabled: false,
);

FilteringStatus _cachedFiltering(String rule) => FilteringStatus(
  filters: [],
  whitelistFilters: [],
  userRules: [rule],
  interval: 12,
  enabled: true,
);

ServerStatus _serverStatus(FilteringStatus filtering) => ServerStatus(
  stats: DnsStatistics(
    timeUnits: 'hours',
    topQueriedDomains: const [],
    topClients: const [],
    topBlockedDomains: const [],
    topUpstreamResponses: null,
    topUpstreamsAvgTime: null,
    dnsQueries: const [5],
    blockedFiltering: const [2],
    replacedSafebrowsing: const [1],
    replacedParental: const [0],
    numDnsQueries: 5,
    numBlockedFiltering: 2,
    numReplacedSafebrowsing: 1,
    numReplacedSafesearch: 0,
    numReplacedParental: 0,
    avgProcessingTime: 0.01,
  ),
  clients: [],
  filteringStatus: filtering,
  timeGeneralDisabled: 30000,
  generalEnabled: false,
  filteringEnabled: true,
  safeSearchEnabled: false,
  safeBrowsingEnabled: true,
  parentalControlEnabled: false,
  serverVersion: 'v0.107.99',
  safeSeachBing: true,
  safeSearchGoogle: false,
  safeSearchDuckduckgo: null,
  safeSearchEcosia: true,
  safeSearchPixabay: false,
  safeSearchYandex: null,
  safeSearchYoutube: true,
  dhcpAvailable: true,
);

List<Object?> _otherServerFields(ServerStatus status) => [
  status.stats,
  status.clients,
  status.timeGeneralDisabled,
  status.disabledUntil,
  status.generalEnabled,
  status.filteringEnabled,
  status.safeSearchEnabled,
  status.safeBrowsingEnabled,
  status.parentalControlEnabled,
  status.serverVersion,
  status.safeSeachBing,
  status.safeSearchGoogle,
  status.safeSearchDuckduckgo,
  status.safeSearchEcosia,
  status.safeSearchPixabay,
  status.safeSearchYandex,
  status.safeSearchYoutube,
  status.dhcpAvailable,
];

class _ObservedApi extends ApiClientV2 {
  _ObservedApi({required super.server});

  FilteringStatus? fetchedFiltering;
  Exception? getException;
  Exception? postException;

  @override
  Future<ApiResponse> getFilteringRules() async {
    if (getException != null) throw getException!;
    final result = await super.getFilteringRules();
    if (result.successful) {
      fetchedFiltering = result.content as FilteringStatus;
    }
    return result;
  }

  @override
  Future<ApiResponse> postFilteringRules({
    required Map<String, List<String>> data,
  }) async {
    if (postException != null) throw postException!;
    return super.postFilteringRules(data: data);
  }
}

class _FilteringHttpServer {
  _FilteringHttpServer(this.httpServer, this.latest) {
    httpServer.listen(_handle);
  }

  final HttpServer httpServer;
  final FilteringStatus latest;
  final requests = <String>[];
  final postedBodies = <Map<String, dynamic>>[];
  final postReceived = Completer<void>();
  Completer<void>? releasePost;
  int getStatusCode = HttpStatus.ok;
  int postStatusCode = HttpStatus.ok;
  String? getBody;
  String? disconnectMethod;

  static Future<_FilteringHttpServer> start(FilteringStatus latest) async =>
      _FilteringHttpServer(
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
        latest,
      );

  Server get server => Server(
    id: 'filtering-test',
    name: 'Filtering test',
    connectionMethod: 'http',
    domain: httpServer.address.address,
    port: httpServer.port,
    defaultServer: true,
    runningOnHa: false,
  );

  Future<void> _handle(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    requests.add('${request.method} ${request.uri.path}');
    if (request.method == disconnectMethod) {
      final socket = await request.response.detachSocket(writeHeaders: false);
      socket.destroy();
      return;
    }
    request.response.headers.contentType = ContentType.json;
    if (request.method == 'GET' &&
        request.uri.path == '/control/filtering/status') {
      request.response.statusCode = getStatusCode;
      request.response.write(getBody ?? jsonEncode(latest.toJson()));
    } else if (request.method == 'POST' &&
        request.uri.path == '/control/filtering/set_rules') {
      postedBodies.add(jsonDecode(body) as Map<String, dynamic>);
      if (!postReceived.isCompleted) postReceived.complete();
      if (releasePost != null) await releasePost!.future;
      request.response.statusCode = postStatusCode;
      request.response.write('{}');
    } else {
      request.response.statusCode = HttpStatus.notFound;
    }
    await request.response.close();
  }

  Future<void> close() async {
    if (releasePost != null && !releasePost!.isCompleted) {
      releasePost!.complete();
    }
    await httpServer.close(force: true);
  }
}

void main() {
  late FilteringStatus latest;
  late FilteringStatus cachedFiltering;
  late FilteringStatus loadedFiltering;
  late ServerStatus cachedServer;
  late Map<String, dynamic> latestBefore;
  late Map<String, dynamic> cachedBefore;
  late Map<String, dynamic> loadedBefore;
  late _FilteringHttpServer http;
  late _ObservedApi api;
  late ServersProvider servers;
  late StatusProvider status;
  late List<FilteringStatus?> notifications;

  setUp(() async {
    latest = _latestFiltering();
    cachedFiltering = _cachedFiltering('||stale.example^');
    loadedFiltering = _cachedFiltering('@@||older.example^');
    cachedServer = _serverStatus(cachedFiltering);
    latestBefore = latest.toJson();
    cachedBefore = cachedFiltering.toJson();
    loadedBefore = loadedFiltering.toJson();
    http = await _FilteringHttpServer.start(latest);
    api = _ObservedApi(server: http.server);
    servers = ServersProvider()
      ..setSelectedServer(api.server)
      ..setApiClient2(api);
    status = StatusProvider()
      ..update(servers)
      ..setServerStatusData(data: cachedServer)
      ..setFilteringStatus(loadedFiltering);
    cachedServer.disabledUntil = DateTime.utc(2030, 1, 1);
    notifications = [];
    status.addListener(() => notifications.add(status.filteringStatus));
  });

  tearDown(() async {
    await http.close();
    status.dispose();
    servers.dispose();
  });

  void expectSourcesUnchanged() {
    expect(cachedFiltering.toJson(), cachedBefore);
    expect(loadedFiltering.toJson(), loadedBefore);
    expect(latest.toJson(), latestBefore);
    if (api.fetchedFiltering != null) {
      expect(api.fetchedFiltering!.toJson(), latestBefore);
    }
  }

  void expectNoStateChange() {
    expect(status.serverStatus, same(cachedServer));
    expect(status.serverStatus!.filteringStatus, same(cachedFiltering));
    expect(status.filteringStatus, same(loadedFiltering));
    expect(notifications, isEmpty);
    expectSourcesUnchanged();
  }

  for (final action in ['block', 'unblock']) {
    for (final domain in ['example.com', 'EXAMPLE.COM', 'ExAmPlE.CoM.']) {
      test('$action $domain replaces only exact simple domain rules', () async {
        http.releasePost = Completer<void>();
        final expectedRules = [
          ..._preservedRules,
          action == 'block' ? '||example.com^' : '@@||example.com^',
        ];
        final pending = status.blockUnblockDomain(
          domain: domain,
          newStatus: action,
        );
        await http.postReceived.future;

        expect(http.requests, [
          'GET /control/filtering/status',
          'POST /control/filtering/set_rules',
        ]);
        expect(http.postedBodies, [
          {'rules': expectedRules},
        ]);
        expect(api.fetchedFiltering, isNotNull);
        expectNoStateChange();

        http.releasePost!.complete();
        expect(await pending, isTrue);
        final updated = status.filteringStatus!;
        expect(updated.toJson(), {
          ...latestBefore,
          'user_rules': expectedRules,
        });
        expect(updated, isNot(same(cachedFiltering)));
        expect(updated, isNot(same(loadedFiltering)));
        expect(updated, isNot(same(api.fetchedFiltering)));
        expect(status.serverStatus, isNot(same(cachedServer)));
        expect(status.serverStatus!.filteringStatus, same(updated));
        expect(_otherServerFields(status.serverStatus!),
            _otherServerFields(cachedServer));
        expect(status.serverStatus!.stats, same(cachedServer.stats));
        expect(status.serverStatus!.clients, same(cachedServer.clients));
        expect(notifications, [updated]);
        expectSourcesUnchanged();
      });
    }

    test('$action failure leaves distinct caches and fetched state unchanged',
        () async {
      http.postStatusCode = HttpStatus.internalServerError;
      http.releasePost = Completer<void>();
      final pending = status.blockUnblockDomain(
        domain: 'example.com',
        newStatus: action,
      );
      await http.postReceived.future;
      expectNoStateChange();
      http.releasePost!.complete();

      expect(await pending, isFalse);
      expect(http.postedBodies, [
        {
          'rules': [
            ..._preservedRules,
            action == 'block' ? '||example.com^' : '@@||example.com^',
          ],
        },
      ]);
      expectNoStateChange();
    });
  }

  test('failed POST does not mutate a filtering object shared by both caches',
      () async {
    loadedFiltering = cachedFiltering;
    loadedBefore = cachedBefore;
    status.setFilteringStatus(cachedFiltering);
    notifications.clear();
    http.postStatusCode = HttpStatus.badRequest;

    expect(await status.blockUnblockDomain(
      domain: 'example.com',
      newStatus: 'block',
    ), isFalse);
    expectNoStateChange();
  });

  for (final code in [HttpStatus.unauthorized, HttpStatus.internalServerError]) {
    test('GET failure $code returns false without POST or state changes',
        () async {
      http.getStatusCode = code;
      expect(await status.blockUnblockDomain(
        domain: 'example.com',
        newStatus: 'block',
      ), isFalse);
      expect(http.requests, ['GET /control/filtering/status']);
      expect(http.postedBodies, isEmpty);
      expectNoStateChange();
    });
  }

  test('malformed GET response returns false without posting cached rules',
      () async {
    http.getBody = 'not JSON';
    expect(await status.blockUnblockDomain(
      domain: 'example.com',
      newStatus: 'block',
    ), isFalse);
    expect(http.requests, ['GET /control/filtering/status']);
    expectNoStateChange();
  });

  for (final method in ['GET', 'POST']) {
    test('$method transport failure leaves state untouched', () async {
      http.disconnectMethod = method;
      expect(await status.blockUnblockDomain(
        domain: 'example.com',
        newStatus: 'block',
      ), isFalse);
      expect(http.requests, [
        'GET /control/filtering/status',
        if (method == 'POST') 'POST /control/filtering/set_rules',
      ]);
      expectNoStateChange();
    });

    test('$method API exception returns false without state changes', () async {
      if (method == 'GET') {
        api.getException = Exception('GET failed');
      } else {
        api.postException = Exception('POST failed');
      }
      expect(await status.blockUnblockDomain(
        domain: 'example.com',
        newStatus: 'block',
      ), isFalse);
      expect(http.requests,
          method == 'GET' ? isEmpty : ['GET /control/filtering/status']);
      expectNoStateChange();
    });
  }

  final maxLabel = 'a'.padRight(63, 'a');
  final maxDomain = '$maxLabel.$maxLabel.$maxLabel.${'b'.padRight(61, 'b')}';
  final validDomains = <String, String>{
    'a': 'a',
    'localhost': 'localhost',
    '3com.example': '3com.example',
    'my-host.example': 'my-host.example',
    'XN--BCHER-KVA.example.': 'xn--bcher-kva.example',
    '_sip._tcp.example.com.': '_sip._tcp.example.com',
    'selector._domainkey.example.com': 'selector._domainkey.example.com',
    '1.0.0.127.in-addr.arpa.': '1.0.0.127.in-addr.arpa',
    '$maxLabel.example': '$maxLabel.example',
    maxDomain: maxDomain,
    '$maxDomain.': maxDomain,
  };
  for (final entry in validDomains.entries) {
    test('accepts DNS name ${entry.key}', () async {
      expect(await status.blockUnblockDomain(
        domain: entry.key,
        newStatus: 'block',
      ), isTrue);
      expect(http.postedBodies, [
        {'rules': [...latest.userRules, '||${entry.value}^']},
      ]);
      expectSourcesUnchanged();
    });
  }

  test('rejects invalid DNS names and Adblock injection without any request',
      () async {
    final invalidDomains = [
      '',
      '.',
      '..',
      '.example.com',
      'example..com',
      'example.com..',
      '-example.com',
      'example-.com',
      '$maxLabel' 'a.example',
      '$maxDomain' 'b',
      '$maxDomain' 'b.',
      ' example.com',
      'example.com ',
      'exa mple.com',
      'https://example.com',
      'example.com:443',
      'example.com/path',
      'example.com?query',
      'user@example.com',
      '*.example.com',
      '||example.com^',
      '@@||example.com^',
      'example.com^',
      r'example.com$important',
      r'example.com^$client=192.0.2.1',
      'example.com|other.test',
      'example.com,other.test',
      'example.com#comment',
      'example.com!comment',
      r'example\.com',
      'example.com%0a',
      'example.com\n||other.test^',
      'bücher.example',
      'K.example',
      'example。com',
      'example.com\u200b',
      'example.com\u2028',
      'example.com\u2029',
      'example.com\u00a0',
      for (var code = 0; code <= 32; code++) ...[
        '${String.fromCharCode(code)}example.com',
        'exam${String.fromCharCode(code)}ple.com',
        'example.com${String.fromCharCode(code)}',
      ],
      'example.com\x7f',
    ];
    for (final domain in invalidDomains) {
      for (final action in ['block', 'unblock']) {
        expect(await status.blockUnblockDomain(
          domain: domain,
          newStatus: action,
        ), isFalse, reason: '$action ${jsonEncode(domain)}');
      }
    }
    expect(http.requests, isEmpty);
    expectNoStateChange();
  });

  test('rejects unsupported actions without a request', () async {
    for (final action in ['', 'allow', 'BLOCK', 'remove']) {
      expect(await status.blockUnblockDomain(
        domain: 'example.com',
        newStatus: action,
      ), isFalse);
    }
    expect(http.requests, isEmpty);
    expectNoStateChange();
  });

  test('missing ServersProvider returns false without a request', () async {
    status.update(null);
    expect(await status.blockUnblockDomain(
      domain: 'example.com',
      newStatus: 'block',
    ), isFalse);
    expect(http.requests, isEmpty);
    expectNoStateChange();
  });

  test('missing API returns false without a request', () async {
    final withoutApi = ServersProvider();
    addTearDown(withoutApi.dispose);
    status.update(withoutApi);
    expect(await status.blockUnblockDomain(
      domain: 'example.com',
      newStatus: 'block',
    ), isFalse);
    expect(http.requests, isEmpty);
    expectNoStateChange();
  });

  test('missing server status returns false without a request', () async {
    final disconnected = StatusProvider()..update(servers);
    addTearDown(disconnected.dispose);
    var changes = 0;
    disconnected.addListener(() => changes++);
    expect(await disconnected.blockUnblockDomain(
      domain: 'example.com',
      newStatus: 'block',
    ), isFalse);
    expect(disconnected.serverStatus, isNull);
    expect(disconnected.filteringStatus, isNull);
    expect(changes, 0);
    expect(http.requests, isEmpty);
  });

  test('success initializes a previously absent filtering cache', () async {
    final fresh = StatusProvider()
      ..update(servers)
      ..setServerStatusData(data: _serverStatus(cachedFiltering));
    addTearDown(fresh.dispose);
    expect(fresh.filteringStatus, isNull);
    expect(await fresh.blockUnblockDomain(
      domain: 'example.com',
      newStatus: 'unblock',
    ), isTrue);
    expect(fresh.serverStatus!.filteringStatus, same(fresh.filteringStatus));
    expect(fresh.filteringStatus!.userRules,
        [..._preservedRules, '@@||example.com^']);
    expectSourcesUnchanged();
  });

  test('empty latest rules do not reintroduce stale cached rules', () async {
    latest.userRules.clear();
    latestBefore = latest.toJson();
    expect(await status.blockUnblockDomain(
      domain: 'example.com',
      newStatus: 'block',
    ), isTrue);
    expect(http.postedBodies, [
      {'rules': ['||example.com^']},
    ]);
    expect(status.filteringStatus!.userRules, ['||example.com^']);
    expectSourcesUnchanged();
  });
}
