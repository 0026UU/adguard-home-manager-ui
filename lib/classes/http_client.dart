import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adguard_home_manager/models/server.dart';

/// The deadline for an ordinary request.
///
/// The control endpoints answer in well under a second, so a request that
/// takes longer than this is a request that is not going to be answered.
const int defaultRequestTimeoutSeconds = 10;

/// The deadline for the calls the server itself takes minutes with.
///
/// `POST /control/filtering/refresh` re-downloads every enabled list: against
/// a stock v1.0.0-b.2 with one 190k-rule list it was measured at 92-126
/// seconds, which is far past the ordinary cap, so the request was cut off
/// before the answer arrived. `POST /control/version.json` with `recheck_now`
/// reaches out to GitHub and `POST /control/update` replaces the binary. Those
/// callers ask for this deadline explicitly instead of the global cap being
/// raised, so a GET against a host that answers nothing still gives up after
/// ten seconds.
const int longRunningRequestTimeoutSeconds = 300;

enum ExceptionType { socket, timeout, handshake, http, unknown }

/// Waits for [duration]. Injectable so tests can run the retry backoff
/// without burning real seconds.
typedef HttpDelay = Future<void> Function(Duration duration);

/// How many times an idempotent request is attempted in total (the first
/// attempt plus two retries) before the failure is surfaced to the caller.
const int transientRetryMaxAttempts = 3;

/// The wait before each retry of a transient failure. Short on purpose: the
/// failures this absorbs are blips (a socket dropped mid-handover, a proxy
/// restarting), and the poll loops that sit on top have their own budget.
const List<Duration> transientRetryBackoff = [
  Duration(milliseconds: 300),
  Duration(milliseconds: 900),
  Duration(seconds: 2),
];

class HttpResponse {
  final bool successful;
  final String? body;
  final int? statusCode;
  final ExceptionType? exception;

  const HttpResponse({
    required this.successful,
    required this.body,
    required this.statusCode,
    this.exception,
  });

  /// True when the failure looks like something that fixes itself: the
  /// connection never completed (socket/handshake/timeout/reset — a reset
  /// surfaces as [ExceptionType.socket] or [ExceptionType.http]), or a proxy
  /// in front of the server answered 502/503/504 while it restarted.
  ///
  /// A 401 is deliberately not transient: it needs the session-recovery path,
  /// not another blind attempt.
  bool get isTransient {
    if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
      return true;
    }
    return exception == ExceptionType.socket ||
        exception == ExceptionType.timeout ||
        exception == ExceptionType.handshake ||
        exception == ExceptionType.http;
  }
}

String getConnectionString({
  required Server server,
  required String urlPath,
}) {
  return "${server.connectionMethod}://${server.domain}${server.port != null ? ':${server.port}' : ""}${server.path ?? ""}/control$urlPath";
}

class HttpRequestClient {
  /// Called with the server's stored credentials when a request answers 401:
  /// one silent re-login, and the request is replayed once when it succeeds.
  /// Wired to `ServerAuth.reloginSilently` by [ApiClientV2]; left null in
  /// tests that want the raw 401. Implementations must never log credentials.
  static Future<bool> Function(Server server)? recoverSession;

  /// Test seam for the retry backoff: when set, every wait between attempts
  /// goes through it instead of [Future.delayed].
  static HttpDelay? delayOverride;

  /// While one silent re-login is in flight, every other 401 waits on the
  /// same attempt instead of starting its own: the overview poll issues its
  /// calls in parallel batches, and a handful of logins within a second is
  /// exactly what AdGuard Home's rate limiter (429) exists for.
  static Future<bool>? _recoveryInFlight;

  /// A re-login the server refused suppresses further attempts until this
  /// instant: the poll loops keep asking, and each 401 must not walk up to a
  /// door that was just locked — that is how a session expiry turns into a
  /// lockout.
  static DateTime _recoverySuppressedUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// How long a refused re-login keeps further attempts suppressed.
  static const Duration recoverySuppressWindow = Duration(seconds: 30);

  /// Test seam for the suppression window.
  static DateTime Function()? nowOverride;

  /// Forgets the in-flight and suppressed state of session recovery. Tests
  /// call it between cases; a caller that switches servers should too, since
  /// the suppression of one server's credentials must not gate the next one's.
  static void resetSessionRecovery() {
    _recoveryInFlight = null;
    _recoverySuppressedUntil = DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// One silent re-login for a 401, deduplicated across concurrent callers
  /// and suppressed for [recoverySuppressWindow] after a refusal.
  static Future<bool> _recoverSessionOnce(Server server) {
    final DateTime Function() now = nowOverride ?? DateTime.now;
    if (now().isBefore(_recoverySuppressedUntil)) {
      return Future.value(false);
    }
    return _recoveryInFlight ??= () async {
      try {
        final bool recovered = await recoverSession!(server) == true;
        if (!recovered) {
          _recoverySuppressedUntil = now().add(recoverySuppressWindow);
        }
        return recovered;
      } finally {
        _recoveryInFlight = null;
      }
    }();
  }

  /// Runs [attempt], absorbing the failures that fix themselves.
  ///
  /// Order matters: a 401 is answered with one silent re-login and one replay
  /// (only when [recoverSession] is wired), a transient transport failure or
  /// 502/503/504 is retried up to [transientRetryMaxAttempts] total attempts
  /// with [transientRetryBackoff] in between, and everything else — a 400, a
  /// 404, a 500 with a reason in its body — is surfaced as it is.
  static Future<HttpResponse> _resilient({
    required Server server,
    required bool retryTransient,
    required HttpDelay? delay,
    required Future<HttpResponse> Function() attempt,
  }) async {
    final HttpDelay wait = delay ?? delayOverride ?? Future.delayed;
    HttpResponse result = await attempt();
    int attempts = 1;
    bool reloginAttempted = false;
    while (!result.successful) {
      if (!reloginAttempted && result.statusCode == 401 && recoverSession != null) {
        reloginAttempted = true;
        if (await _recoverSessionOnce(server)) {
          result = await attempt();
          continue;
        }
        // The stored credentials were refused again: this is not a blip, so
        // the 401 goes back to the caller, which marks the connection as
        // needing credentials instead of retrying behind the user's back.
        break;
      }
      if (retryTransient && result.isTransient && attempts < transientRetryMaxAttempts) {
        final int backoffIndex = attempts - 1 < transientRetryBackoff.length - 1
            ? attempts - 1
            : transientRetryBackoff.length - 1;
        await wait(transientRetryBackoff[backoffIndex]);
        attempts += 1;
        result = await attempt();
        continue;
      }
      break;
    }
    return result;
  }

  static Future<HttpResponse> get({
    required String urlPath,
    required Server server,
    int timeout = defaultRequestTimeoutSeconds,
    bool retryTransient = true,
    HttpDelay? delay,
  }) => _resilient(
    server: server,
    retryTransient: retryTransient,
    delay: delay,
    attempt: () => _getOnce(urlPath: urlPath, server: server, timeout: timeout),
  );

  static Future<HttpResponse> _getOnce({
    required String urlPath,
    required Server server,
    int timeout = defaultRequestTimeoutSeconds,
  }) async{
    final String connectionString = getConnectionString(server: server, urlPath: urlPath);
    HttpClient? httpClient;
    try {
      // Without a connect timeout the operating system decides how long the
      // "Connecting…" sheet spins against a host that answers nothing.
      httpClient = HttpClient()
        ..connectionTimeout = Duration(seconds: timeout);
      HttpClientRequest request = await httpClient.getUrl(Uri.parse(connectionString));
      if (server.authToken != null) {
        request.headers.set('Authorization', 'Basic ${server.authToken}');
      }
      HttpClientResponse response = await request.close().timeout(
        Duration(seconds: timeout)
      );
      // The deadline covers the whole exchange, not only the request: a server
      // that accepts and never replies must not hang the caller.
      String reply = await response
          .transform(utf8.decoder)
          .join()
          .timeout(Duration(seconds: timeout));
      return HttpResponse(
        successful: response.statusCode >= 400 ? false : true, 
        body: reply, 
        statusCode: response.statusCode
      );   
    } on SocketException {
      return const HttpResponse(
        successful: false, 
        body: null, 
        statusCode: null,
        exception: ExceptionType.socket
      );   
    } on TimeoutException {
      return const HttpResponse(
        successful: false, 
        body: null, 
        statusCode: null,
        exception: ExceptionType.timeout
      );  
    } on HandshakeException {
      return const HttpResponse(
        successful: false, 
        body: null, 
        statusCode: null,
        exception: ExceptionType.handshake
      );  
    } on HttpException {
      return const HttpResponse(
        successful: false, 
        body: null, 
        statusCode: null,
        exception: ExceptionType.http
      );  
    } catch (e) {
      return const HttpResponse(
        successful: false, 
        body: null, 
        statusCode: null,
        exception: ExceptionType.unknown
      );  
    } finally {
      // Every call owns its client, so the sockets of a call that was cut off
      // by its own deadline have to go with it. Leaving them behind was not
      // only a leak: AdGuard Home answers the requests of a busy refresh with
      // `json decode: read tcp 127.0.0.1:31090->127.0.0.1:56902: i/o timeout`
      // once the abandoned connection is still in the way, so the retry that
      // followed the first timeout failed for the same reason twice.
      httpClient?.close(force: true);
    }
  }

  /// POST is not retried on transient failures by default: a write that timed
  /// out may still have been applied, and applying it twice is worse than
  /// reporting the blip. The 401 session-recovery replay is the one exception
  /// and it is safe because a refused login means the body was never acted on.
  static Future<HttpResponse> post({
    required String urlPath,
    required Server server,
    dynamic body,
    int timeout = defaultRequestTimeoutSeconds,
    bool retryTransient = false,
    HttpDelay? delay,
  }) => _resilient(
    server: server,
    retryTransient: retryTransient,
    delay: delay,
    attempt: () => _postOnce(
      urlPath: urlPath,
      server: server,
      body: body,
      timeout: timeout,
    ),
  );

  static Future<HttpResponse> _postOnce({
    required String urlPath,
    required Server server,
    dynamic body,
    int timeout = defaultRequestTimeoutSeconds,
  }) async{
    final String connectionString = getConnectionString(server: server, urlPath: urlPath);
    HttpClient? httpClient;
    try {
      // Without a connect timeout the operating system decides how long the
      // "Connecting…" sheet spins against a host that answers nothing.
      httpClient = HttpClient()
        ..connectionTimeout = Duration(seconds: timeout);
      HttpClientRequest request = await httpClient.postUrl(Uri.parse(connectionString));
      if (server.authToken != null) {
        request.headers.set('Authorization', 'Basic ${server.authToken}');
      }
      request.headers.set('content-type', 'application/json');
      request.add(utf8.encode(json.encode(body)));
      HttpClientResponse response = await request.close().timeout(
        Duration(seconds: timeout)
      );
      // The deadline covers the whole exchange, not only the request: a server
      // that accepts and never replies must not hang the caller.
      String reply = await response
          .transform(utf8.decoder)
          .join()
          .timeout(Duration(seconds: timeout));
      return HttpResponse(
        successful: response.statusCode >= 400 ? false : true, 
        body: reply, 
        statusCode: response.statusCode
      );  
    } on SocketException {
      return const HttpResponse(
        successful: false, 
        body: null, 
        statusCode: null,
        exception: ExceptionType.socket
      );   
    } on TimeoutException {
      return const HttpResponse(
        successful: false, 
        body: null, 
        statusCode: null,
        exception: ExceptionType.timeout
      );  
    } on HttpException {
      return const HttpResponse(
        successful: false, 
        body: null, 
        statusCode: null,
        exception: ExceptionType.http
      );  
    } on HandshakeException {
      return const HttpResponse(
        successful: false, 
        body: null, 
        statusCode: null,
        exception: ExceptionType.handshake
      );  
    } catch (e) {
      return const HttpResponse(
        successful: false, 
        body: null, 
        statusCode: null,
        exception: ExceptionType.unknown
      );  
    } finally {
      // See HttpRequestClient.get: a call that was cut off must not leave its
      // socket behind for the next one to trip over.
      httpClient?.close(force: true);
    }
  }

  /// The PUTs of this API all replace a whole settings object, so replaying
  /// one after a blip writes the same state again — idempotent, and retried.
  static Future<HttpResponse> put({
    required String urlPath,
    required Server server,
    dynamic body,
    int timeout = defaultRequestTimeoutSeconds,
    bool retryTransient = true,
    HttpDelay? delay,
  }) => _resilient(
    server: server,
    retryTransient: retryTransient,
    delay: delay,
    attempt: () => _putOnce(
      urlPath: urlPath,
      server: server,
      body: body,
      timeout: timeout,
    ),
  );

  static Future<HttpResponse> _putOnce({
    required String urlPath,
    required Server server,
    dynamic body,
    int timeout = defaultRequestTimeoutSeconds,
  }) async{
    final String connectionString = getConnectionString(server: server, urlPath: urlPath);
    HttpClient? httpClient;
    try {
      // Without a connect timeout the operating system decides how long the
      // "Connecting…" sheet spins against a host that answers nothing.
      httpClient = HttpClient()
        ..connectionTimeout = Duration(seconds: timeout);
      HttpClientRequest request = await httpClient.putUrl(Uri.parse(connectionString));
      if (server.authToken != null) {
        request.headers.set('Authorization', 'Basic ${server.authToken}');
      }
      request.headers.set('content-type', 'application/json');
      request.add(utf8.encode(json.encode(body)));
      HttpClientResponse response = await request.close().timeout(
        Duration(seconds: timeout)
      );
      // The deadline covers the whole exchange, not only the request: a server
      // that accepts and never replies must not hang the caller.
      String reply = await response
          .transform(utf8.decoder)
          .join()
          .timeout(Duration(seconds: timeout));
      return HttpResponse(
        successful: response.statusCode >= 400 ? false : true, 
        body: reply, 
        statusCode: response.statusCode
      );  
    } on SocketException {
      return const HttpResponse(
        successful: false, 
        body: null, 
        statusCode: null,
        exception: ExceptionType.socket
      );   
    } on TimeoutException {
      return const HttpResponse(
        successful: false, 
        body: null, 
        statusCode: null,
        exception: ExceptionType.timeout
      );  
    } on HttpException {
      return const HttpResponse(
        successful: false, 
        body: null, 
        statusCode: null,
        exception: ExceptionType.http
      );  
    } on HandshakeException {
      return const HttpResponse(
        successful: false, 
        body: null, 
        statusCode: null,
        exception: ExceptionType.handshake
      );  
    } catch (e) {
      return const HttpResponse(
        successful: false, 
        body: null, 
        statusCode: null,
        exception: ExceptionType.unknown
      );  
    } finally {
      // See HttpRequestClient.get: a call that was cut off must not leave its
      // socket behind for the next one to trip over.
      httpClient?.close(force: true);
    }
  }
}