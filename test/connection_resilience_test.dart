import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/classes/http_client.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/services/api_client.dart';
import 'package:adguard_home_manager/services/auth.dart';

/// The stats body AdGuard Home answers `GET /control/stats` with, reduced to
/// the fields the model insists on.
Map<String, dynamic> _statsBody() => {
  'time_units': 'hours',
  'top_queried_domains': [],
  'top_clients': [],
  'top_blocked_domains': [],
  'dns_queries': [],
  'blocked_filtering': [],
  'replaced_safebrowsing': [],
  'replaced_parental': [],
  'num_dns_queries': 0,
  'num_blocked_filtering': 0,
  'num_replaced_safebrowsing': 0,
  'num_replaced_safesearch': 0,
  'num_replaced_parental': 0,
  'avg_processing_time': 0,
};

/// A loopback AdGuard Home the test can break on purpose.
class _Backend {
  _Backend(this.httpServer) {
    httpServer.listen(_handle);
  }

  final HttpServer httpServer;

  /// While false, every control endpoint answers [failWith].
  bool healthy = true;
  int failWith = HttpStatus.serviceUnavailable;

  /// Statuses handed out to the next requests, one per request, before the
  /// healthy bodies resume. Lets a test script "one blip, then fine".
  final List<int> failQueue = [];

  /// How many upcoming GETs answer 401 (an expired session), decrementing.
  int unauthorizedGets = 0;

  /// How many upcoming requests have their socket destroyed without a reply
  /// (a connection reset), decrementing.
  int destroyedRequests = 0;

  int loginAnswers = HttpStatus.ok;
  int loginHits = 0;
  final List<String> requests = [];

  static Future<_Backend> start() async =>
      _Backend(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  Server server({String? user, String? password}) => Server(
    id: 'resilience-test',
    name: 'Resilience test',
    connectionMethod: 'http',
    domain: httpServer.address.address,
    port: httpServer.port,
    user: user,
    password: password,
    defaultServer: true,
    runningOnHa: false,
  );

  int countRequests(String method, String path) =>
      requests.where((r) => r == '$method $path').length;

  Future<void> _handle(HttpRequest request) async {
    final String path = request.uri.path;
    requests.add('${request.method} $path');

    if (path == '/control/login') {
      loginHits += 1;
      request.response.statusCode = healthy ? loginAnswers : failWith;
      await request.response.close();
      return;
    }

    if (destroyedRequests > 0) {
      destroyedRequests -= 1;
      final socket = await request.response.detachSocket(writeHeaders: false);
      socket.destroy();
      return;
    }

    if (!healthy) {
      request.response.statusCode = failWith;
      await request.response.close();
      return;
    }

    if (failQueue.isNotEmpty) {
      request.response.statusCode = failQueue.removeAt(0);
      await request.response.close();
      return;
    }

    if (request.method == 'GET' && unauthorizedGets > 0) {
      unauthorizedGets -= 1;
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
      return;
    }

    final String? body = _bodyFor(path);
    if (body == null) {
      request.response.statusCode = HttpStatus.notFound;
    } else {
      request.response.headers.contentType = ContentType.json;
      request.response.write(body);
    }
    await request.response.close();
  }

  static String? _bodyFor(String path) {
    switch (path) {
      case '/control/status':
        return jsonEncode({
          'version': 'v1.0.0',
          'protection_enabled': true,
          'protection_disabled_duration': 0,
          'dhcp_available': false,
          'running': true,
        });
      case '/control/stats':
        return jsonEncode(_statsBody());
      case '/control/filtering/status':
        return jsonEncode({
          'filters': [],
          'whitelist_filters': [],
          'user_rules': [],
          'interval': 24,
          'enabled': true,
        });
      case '/control/safesearch/status':
        return jsonEncode({
          'enabled': true,
          'bing': true,
          'duckduckgo': true,
          'google': true,
        });
      case '/control/safebrowsing/status':
        return jsonEncode({'enabled': false});
      case '/control/parental/status':
        return jsonEncode({'enabled': false});
      case '/control/clients':
        return jsonEncode({'clients': [], 'auto_clients': []});
      default:
        return null;
    }
  }

  Future<void> close() async {
    await httpServer.close(force: true);
  }
}

void main() {
  late _Backend backend;
  late List<Duration> recordedDelays;

  setUp(() async {
    backend = await _Backend.start();
    recordedDelays = [];
    // The retry backoff is a clock the test owns: waits are recorded instead
    // of slept, so a whole retry budget costs microseconds.
    HttpRequestClient.delayOverride = (duration) {
      recordedDelays.add(duration);
      return Future.value();
    };
    HttpRequestClient.resetSessionRecovery();
  });

  tearDown(() async {
    await backend.close();
    HttpRequestClient.delayOverride = null;
    HttpRequestClient.recoverSession = null;
    HttpRequestClient.resetSessionRecovery();
  });

  group('transient failures are retried on idempotent requests', () {
    test('a single 503 blip on a GET is absorbed and never reaches the caller',
        () async {
      backend.failQueue.add(HttpStatus.serviceUnavailable);

      final result = await HttpRequestClient.get(
        urlPath: '/status',
        server: backend.server(),
      );

      expect(result.successful, true);
      expect(result.statusCode, HttpStatus.ok);
      expect(backend.countRequests('GET', '/control/status'), 2);
      expect(recordedDelays, [const Duration(milliseconds: 300)]);
    });

    test('a destroyed socket (connection reset) is transient and retried',
        () async {
      backend.destroyedRequests = 1;

      final result = await HttpRequestClient.get(
        urlPath: '/status',
        server: backend.server(),
      );

      expect(result.successful, true);
      expect(backend.countRequests('GET', '/control/status'), 2);
    });

    test('a GET gives up after the retry budget and reports the 503',
        () async {
      backend.failQueue.addAll([
        HttpStatus.serviceUnavailable,
        HttpStatus.badGateway,
        HttpStatus.gatewayTimeout,
        HttpStatus.serviceUnavailable,
      ]);

      final result = await HttpRequestClient.get(
        urlPath: '/status',
        server: backend.server(),
      );

      expect(result.successful, false);
      expect(result.statusCode, HttpStatus.gatewayTimeout);
      expect(backend.countRequests('GET', '/control/status'),
          transientRetryMaxAttempts);
      expect(recordedDelays, [
        const Duration(milliseconds: 300),
        const Duration(milliseconds: 900),
      ]);
    });

    test('a PUT of settings is treated as idempotent and retried', () async {
      backend.failQueue.add(HttpStatus.serviceUnavailable);

      final result = await HttpRequestClient.put(
        urlPath: '/status',
        server: backend.server(),
        body: {},
      );

      // The fixture answers the replay with the status body, so the retried
      // PUT succeeds — the point is that the blip was retried at all.
      expect(backend.countRequests('PUT', '/control/status'), 2);
      expect(result.successful, true);
    });

    test('an ordinary POST is never retried after a transient failure',
        () async {
      backend.failQueue.addAll([
        HttpStatus.serviceUnavailable,
        HttpStatus.serviceUnavailable,
      ]);

      final result = await HttpRequestClient.post(
        urlPath: '/filtering/config',
        server: backend.server(),
        body: {'enabled': true},
      );

      expect(result.successful, false);
      expect(backend.countRequests('POST', '/control/filtering/config'), 1);
      expect(recordedDelays, isEmpty);
    });

    test('a 404 is not transient and is surfaced as it is', () async {
      final result = await HttpRequestClient.get(
        urlPath: '/does_not_exist',
        server: backend.server(),
      );

      expect(result.successful, false);
      expect(result.statusCode, HttpStatus.notFound);
      expect(backend.countRequests('GET', '/control/does_not_exist'), 1);
    });

    test('the login call retries transient refusals but not a verdict',
        () async {
      backend.healthy = false;
      backend.failWith = HttpStatus.serviceUnavailable;

      final refused = await ServerAuth.login(
        backend.server(user: 'u', password: 'p'),
      );
      expect(refused, AuthStatus.serverError);
      expect(backend.loginHits, transientRetryMaxAttempts);
      expect(recordedDelays, [
        const Duration(milliseconds: 300),
        const Duration(milliseconds: 900),
      ]);

      backend.healthy = true;
      backend.loginAnswers = HttpStatus.unauthorized;
      backend.loginHits = 0;
      recordedDelays.clear();

      final verdict = await ServerAuth.login(
        backend.server(user: 'u', password: 'wrong'),
      );
      expect(verdict, AuthStatus.invalidCredentials);
      expect(backend.loginHits, 1);
      expect(recordedDelays, isEmpty);
    });
  });

  group('session recovery on 401', () {
    test('one silent re-login with the stored credentials replays the request',
        () async {
      backend.unauthorizedGets = 1;
      final api = ApiClientV2(server: backend.server(user: 'u', password: 'p'));

      final result = await api.getServerVersion();

      expect(result.successful, true);
      expect(result.content, 'v1.0.0');
      expect(backend.loginHits, 1);
      expect(backend.countRequests('GET', '/control/status'), 2);
      expect(result.needsCredentials, false);
    });

    test('a refused re-login surfaces 401 as needing credentials, once',
        () async {
      backend.unauthorizedGets = 10;
      backend.loginAnswers = HttpStatus.unauthorized;
      final api = ApiClientV2(server: backend.server(user: 'u', password: 'p'));

      final result = await api.getServerVersion();

      expect(result.successful, false);
      expect(result.needsCredentials, true);
      // Exactly one silent re-login and no replay loop behind the user's back.
      expect(backend.loginHits, 1);
      expect(backend.countRequests('GET', '/control/status'), 1);
    });

    test('a 401 without stored credentials is not a recoverable session',
        () async {
      backend.unauthorizedGets = 10;
      final api = ApiClientV2(server: backend.server());

      final result = await api.getServerVersion();

      expect(result.successful, false);
      expect(result.needsCredentials, true);
      expect(backend.loginHits, 0);
    });
  });

  group('the status poll keeps the connection through blips', () {
    late ServersProvider servers;
    late StatusProvider status;

    StatusProvider buildStatus({
      Duration autoReconnectInterval = const Duration(seconds: 5),
    }) {
      servers = ServersProvider()
        ..setSelectedServer(backend.server())
        ..setApiClient2(ApiClientV2(server: backend.server()));
      return StatusProvider(autoReconnectInterval: autoReconnectInterval)
        ..update(servers);
    }

    tearDown(() {
      status.dispose();
      servers.dispose();
    });

    test('one failed poll then success stays connected throughout', () async {
      status = buildStatus();

      // The first poll works: the provider has an answer to stay on.
      expect(await status.getServerStatus(), true);
      expect(status.loadStatus, LoadStatus.loaded);

      // The server stops answering for one whole poll — every endpoint fails
      // its complete retry budget — and the connection is still kept.
      backend.healthy = false;
      expect(await status.getServerStatus(withLoadingIndicator: false), false);
      expect(status.loadStatus, LoadStatus.loaded);
      expect(status.reconnecting, true);
      expect(status.consecutivePollFailures, 1);
      expect(status.serverStatus, isNotNull);

      // The server answers again and the next poll is a plain success.
      backend.healthy = true;
      expect(await status.getServerStatus(withLoadingIndicator: false), true);
      expect(status.loadStatus, LoadStatus.loaded);
      expect(status.reconnecting, false);
      expect(status.consecutivePollFailures, 0);
    });

    test('three consecutive failed polls disconnect', () async {
      status = buildStatus();
      expect(await status.getServerStatus(), true);

      backend.healthy = false;
      for (int poll = 1; poll < StatusProvider.maxConsecutivePollFailures; poll++) {
        expect(await status.getServerStatus(withLoadingIndicator: false), false);
        expect(status.loadStatus, LoadStatus.loaded,
            reason: 'poll $poll is inside the budget');
      }

      expect(await status.getServerStatus(withLoadingIndicator: false), false);
      expect(status.consecutivePollFailures,
          StatusProvider.maxConsecutivePollFailures);
      expect(status.loadStatus, LoadStatus.error);
    });

    test('a dropped connection recovers on its own when the server returns',
        () async {
      status = buildStatus(
        autoReconnectInterval: const Duration(milliseconds: 100),
      );
      expect(await status.getServerStatus(), true);

      backend.healthy = false;
      for (int i = 0; i < StatusProvider.maxConsecutivePollFailures; i++) {
        await status.getServerStatus(withLoadingIndicator: false);
      }
      expect(status.loadStatus, LoadStatus.error);

      // The server comes back and nobody touches the app: the background
      // reconnect poll has to find it, refetch, and clear the error state.
      backend.healthy = true;
      await Future.delayed(const Duration(milliseconds: 500));

      expect(status.loadStatus, LoadStatus.loaded);
      expect(status.reconnecting, false);
      expect(status.consecutivePollFailures, 0);
      expect(status.serverStatus, isNotNull);
    });

    test('a session the re-login could not save asks for credentials at once',
        () async {
      servers = ServersProvider()
        ..setSelectedServer(backend.server(user: 'u', password: 'p'))
        ..setApiClient2(
          ApiClientV2(server: backend.server(user: 'u', password: 'p')),
        );
      status = StatusProvider()..update(servers);

      expect(await status.getServerStatus(), true);

      // The session expires and the stored credentials are refused: this is
      // not a blip, so the first poll already asks for credentials instead of
      // burning the whole budget against a locked door.
      backend.unauthorizedGets = 1000;
      backend.loginAnswers = HttpStatus.unauthorized;

      expect(await status.getServerStatus(withLoadingIndicator: false), false);
      expect(status.loadStatus, LoadStatus.error);
      expect(status.needsCredentials, true);
      expect(status.reconnecting, false);
      expect(backend.loginHits, 1);
    });
  });
}
