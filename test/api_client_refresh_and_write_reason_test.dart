import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/services/api_client.dart';

/// A stand-in for AdGuard Home v1.0.0-b.2, answering the leaf paths with the
/// bodies the real server answers, so the two repairs in the API layer — the
/// deadline plus the refresh shape, and the reason a refused write carries —
/// are covered without a live server.
///
/// What `POST /control/filtering/refresh` answers here is what it answered on
/// the test instance: one integer, `{"updated": 1}`, and a plain-text line for
/// a refusal.
void main() {
  late HttpServer stub;
  late ApiClientV2 api;

  /// The body of `GET /control/filtering/status`, as the first read sees it.
  late Map<String, dynamic> filteringStatus;

  /// The same body after the refresh, when a test wants a list to come back
  /// with data.
  late Map<String, dynamic> filteringStatusAfterRefresh;

  /// Whether the second and later status reads report the post-refresh body.
  bool mutateStatusAfterRefresh = false;

  int refreshStatus = 200;
  String refreshBody = '{"updated": 0}';
  Duration refreshDelay = Duration.zero;

  final List<String> seenPaths = [];
  final Map<String, String> seenBodies = {};

  setUp(() async {
    final goodList = {
      'url': 'https://good.example/list.txt',
      'name': 'Good list',
      'last_updated': '2026-11-06T17:56:13+08:00',
      'id': 1,
      'rules_count': 5,
      'enabled': true,
    };
    final brokenList = {
      'url': 'https://this-list-does-not-exist.invalid/blocklist.txt',
      'name': 'Broken list',
      'last_updated': '2026-11-06T17:56:13+08:00',
      'id': 3,
      // A list that never downloaded anything keeps a rules count of zero,
      // and that is the only signal the endpoint leaves for a failure.
      'rules_count': 0,
      'enabled': true,
    };
    filteringStatus = {
      'filters': [goodList, brokenList,
        {
          'url': 'https://disabled.example/list.txt',
          'name': 'Disabled list',
          'id': 4,
          'rules_count': 0,
          'enabled': false,
        },
      ],
      'whitelist_filters': null,
      'user_rules': <String>[],
      'interval': 24,
      'enabled': true,
    };
    filteringStatusAfterRefresh = {
      ...filteringStatus,
      'filters': [
        {...goodList, 'rules_count': 9},
        brokenList,
        filteringStatus['filters'][2],
      ],
    };

    mutateStatusAfterRefresh = false;
    refreshStatus = 200;
    refreshBody = '{"updated": 0}';
    refreshDelay = Duration.zero;
    seenPaths.clear();
    seenBodies.clear();

    stub = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var statusReads = 0;
    stub.listen((request) async {
      final path = request.uri.path;
      seenPaths.add(path);
      if (request.method != 'GET') {
        seenBodies[path] = await utf8.decoder.bind(request).join();
      }

      void reply(int code, String body) {
        request.response.statusCode = code;
        request.response.headers.contentType = ContentType.text;
        request.response.write(body);
        request.response.close();
      }

      // The package's language version predates the fall-through-free switch
      // statement, so the stub routes with plain returns.
      if (path == '/control/filtering/status') {
        statusReads++;
        reply(
          200,
          jsonEncode(
            mutateStatusAfterRefresh && statusReads > 1
                ? filteringStatusAfterRefresh
                : filteringStatus,
          ),
        );
        return;
      }
      if (path == '/control/filtering/refresh') {
        unawaited(
          Future.delayed(refreshDelay, () => reply(refreshStatus, refreshBody)),
        );
        return;
      }
      if (path == '/control/clients/add') {
        reply(
          400,
          'adding client: another client "mac-probe-a" uses the same MAC '
          '"aa:bb:cc:dd:ee:0f"\n',
        );
        return;
      }
      if (path == '/control/clients/update') {
        reply(400, 'updating client: client "gone" is not found\n');
        return;
      }
      if (path == '/control/filtering/set_rules') {
        reply(400, 'invalid rule: ||^\n');
        return;
      }
      if (path == '/control/dhcp/add_static_lease') {
        reply(400, 'static lease with ip 192.0.2.5 already exists\n');
        return;
      }
      if (path == '/control/tls/configure') {
        reply(400, 'invalid server certificate chain\n');
        return;
      }
      if (path == '/control/rewrite/add') {
        reply(
          400,
          '{"message":"normalizing: invalid CNAME target \\"\\": domain name '
          'is empty"}\n',
        );
        return;
      }
      if (path == '/control/protection') {
        // The answer of a proxy in front of the server: a refusal with
        // nothing in it a user can act on.
        reply(502, '<html><body>502 Bad Gateway</body></html>');
        return;
      }
      reply(200, '{}');
    });

    api = ApiClientV2(
      server: Server(
        id: 'stub',
        name: 'stub',
        connectionMethod: 'http',
        domain: stub.address.host,
        port: stub.port,
        defaultServer: false,
        runningOnHa: false,
      ),
    );
  });

  tearDown(() async {
    await stub.close(force: true);
  });

  group('POST /filtering/refresh', () {
    test(
      'is given the time the server needs and reads the real b.2 body',
      () async {
        // Measured against the test instance: 92-126 seconds for one 190k-rule
        // list. The stub reproduces the shape of that problem at a size a test
        // can wait for — twelve seconds, one past the cap the call used to
        // share with an ordinary GET, when it was cut off every single time.
        refreshDelay = const Duration(seconds: 12);
        refreshBody = '{"updated": 1}';
        mutateStatusAfterRefresh = true;
        final started = DateTime.now();

        final result = await api.updateLists();
        final elapsed = DateTime.now().difference(started);

        expect(
          result.successful,
          isTrue,
          reason: 'the refresh failed: ${result.message}',
        );
        expect(
          elapsed,
          greaterThan(const Duration(seconds: 10)),
          reason: 'the answer arrived inside the old ten second cap, so the '
              'call was never really given the longer deadline',
        );
        expect(result.message, isNull);

        final data = result.content as Map<String, dynamic>;
        expect(data['updated'], 1, reason: 'the count the server reported: $data');
        expect(data['total'], 2, reason: 'the two enabled lists of this server');
        expect(data['updated_lists'], ['Good list']);
        expect(data['failed'], ['Broken list']);

        // Only the kind with an enabled list is refreshed — the whitelist of
        // this server is empty — and it is refreshed once, with the body the
        // endpoint takes. Two refreshes at once would trip the non-blocking
        // lock the handler answers 500 with.
        expect(
          seenPaths.where((p) => p == '/control/filtering/refresh').length,
          1,
          reason: 'the whitelist has nothing enabled: $seenPaths',
        );
        expect(
          jsonDecode(seenBodies['/control/filtering/refresh']!),
          {'whitelist': false},
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('a refusal says so with the words of the server', () async {
      refreshStatus = 500;
      refreshBody = 'filters update procedure is already running\n';

      final result = await api.updateLists();

      expect(result.successful, isFalse);
      expect(result.message, 'filters update procedure is already running');
    });

    test('names the list that came back with nothing', () async {
      refreshBody = '{"updated": 1}';

      final result = await api.updateLists();

      expect(result.successful, isTrue, reason: result.message);
      final data = result.content as Map<String, dynamic>;
      expect(data['updated'], 1);
      expect(data['failed'], ['Broken list']);
      // Nothing moved in the status of this stub, so no list is claimed to
      // have come back with new rules.
      expect(data['updated_lists'], isEmpty);
    });
  });

  group('the reason a refused write carries', () {
    test('reaches the caller of clients/add', () async {
      final result = await api.postAddClient(data: {'name': 'x'});

      expect(result.successful, isFalse);
      expect(
        result.message,
        'adding client: another client "mac-probe-a" uses the same MAC '
        '"aa:bb:cc:dd:ee:0f"',
      );
      expect(result.content, isNull, reason: 'the content these wrappers '
          'returned as nothing stays nothing');
      expect(result.statusCode, isNull, reason: 'pages branch on the status '
          'code of the wrappers that already reported one, so the others must '
          'not start now');
    });

    test('reaches the caller of clients/update', () async {
      final result = await api.postUpdateClient(data: {'name': 'gone'});

      expect(result.successful, isFalse);
      expect(result.message, 'updating client: client "gone" is not found');
    });

    test('reaches the caller of filtering/set_rules', () async {
      final result = await api.setCustomRules(rules: ['||^']);

      expect(result.successful, isFalse);
      expect(result.message, 'invalid rule: ||^');
    });

    test('reaches the caller of dhcp/add_static_lease', () async {
      final result = await api.createStaticLease(data: {'ip': '192.0.2.5'});

      expect(result.successful, isFalse);
      // The sentinel content the lease page switches on is left alone: this
      // stub's wording is not one of the two the wrapper recognises.
      expect(result.content, isNull);
      expect(result.message, contains('already exists'));
    });

    test('reaches the caller of tls/configure', () async {
      final result = await api.saveEncryptionSettings(data: {});

      expect(result.successful, isFalse);
      expect(result.content, 'invalid server certificate chain\n');
      expect(result.message, 'invalid server certificate chain');
    });

    test('is taken from a JSON body when the server sends one', () async {
      final result = await api.addDnsRewriteRule(data: {'domain': 'x'});

      expect(result.successful, isFalse);
      expect(
        result.message,
        'normalizing: invalid CNAME target "": domain name is empty',
      );
    });

    test('is not the html page of whatever sits in front', () async {
      final result = await api.updateGeneralProtection(enable: false);

      expect(result.successful, isFalse);
      // The proxy's page is not a reason and never reaches the caller, but the
      // status it answered with is worth naming instead of hiding.
      expect(result.message, isNot(contains('<html>')));
      expect(
        result.message,
        'the server answered HTTP 502; a proxy in front of it may be answering '
            'instead',
      );
    });

    test('names the transport failure when there is no body at all', () async {
      final closed = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = closed.port;
      await closed.close(force: true);

      final result = await ApiClientV2(
        server: Server(
          id: 'dead',
          name: 'dead',
          connectionMethod: 'http',
          domain: '127.0.0.1',
          port: deadPort,
          defaultServer: false,
          runningOnHa: false,
        ),
      ).setBlockedServices(data: const ['youtube']);

      expect(result.successful, isFalse);
      expect(
        result.message,
        anyOf(
          'the server could not be reached',
          'the server did not answer in time',
        ),
        reason: 'the transport failure was left undescribed: ${result.message}',
      );
    });

    test('stays absent for a write the server accepted', () async {
      final result = await api.updateFiltering(enable: true);

      expect(result.successful, isTrue);
      expect(result.message, isNull);
    });
  });
}
