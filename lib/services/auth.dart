import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:adguard_home_manager/classes/http_client.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/services/local_network_permission.dart';

enum AuthStatus { 
  success, 
  invalidCredentials, 
  manyAttepts, 
  serverError, 
  socketException,
  timeoutException,
  handshakeException,
  unknown 
}

class ServerAuth {
  /// Login is the one non-idempotent call that is retried: a refused login
  /// changes nothing on the server, so a blip during it is worth absorbing
  /// with the same budget the idempotent reads have.
  static Future<AuthStatus> login(Server server, {HttpDelay? delay}) async {
    final HttpDelay wait = delay ?? HttpRequestClient.delayOverride ?? Future.delayed;
    AuthStatus status = await _loginOnce(server);
    int attempts = 1;
    while (_isTransientStatus(status) && attempts < transientRetryMaxAttempts) {
      final int backoffIndex = attempts - 1 < transientRetryBackoff.length - 1
          ? attempts - 1
          : transientRetryBackoff.length - 1;
      await wait(transientRetryBackoff[backoffIndex]);
      attempts += 1;
      status = await _loginOnce(server);
    }
    return status;
  }

  /// True for the outcomes that say "the login never happened" rather than
  /// "the credentials were refused": the transport broke fast, or a proxy in
  /// front of the server answered that it is unavailable. 400/401/403/429 are
  /// final.
  ///
  /// A timeout is deliberately not retried here even though it is transient
  /// everywhere else: login is the interactive "Connecting…" sheet, which has
  /// already waited its own ten seconds, and retrying would make the user
  /// watch the spinner for the whole budget three times over.
  static bool _isTransientStatus(AuthStatus status) =>
      status == AuthStatus.socketException ||
      status == AuthStatus.handshakeException ||
      status == AuthStatus.serverError;

  /// The session-recovery hook [HttpRequestClient.recoverSession] calls when a
  /// request answered 401: one silent login with the credentials stored for
  /// this server. Returns false when there is nothing to log in with, so the
  /// caller surfaces the 401 and the connection is marked as needing
  /// credentials. Nothing here may log or embed the credentials.
  static Future<bool> reloginSilently(Server server) async {
    if (server.user == null || server.password == null) {
      return false;
    }
    return await login(server) == AuthStatus.success;
  }

  static Future<AuthStatus> _loginOnce(Server server) async {
    try {
      // Android 17+ blocks LAN sockets until the user grants local network
      // access; request it before opening the socket (no-op elsewhere).
      await LocalNetworkPermission.ensureGranted(server.domain);
      final body = {
        "name": server.user,
        "password": server.password
      };
      final connectionString = "${server.connectionMethod}://${server.domain}${server.port != null ? ':${server.port}' : ""}${server.path ?? ""}/control/login";
      // The connect itself is what hangs against a port nobody listens on, so
      // the deadline has to cover it too — otherwise "Save" spins for the
      // operating system's own retry budget (~20s) before saying anything.
      HttpClient httpClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      HttpClientRequest request = await httpClient
          .postUrl(Uri.parse(connectionString))
          .timeout(const Duration(seconds: 10));
      request.headers.set('content-type', 'application/json');
      request.headers.contentLength = utf8.encode(jsonEncode(body)).length;
      request.add(utf8.encode(json.encode(body)));
      HttpClientResponse response = await request.close().timeout(const Duration(seconds: 10));
      httpClient.close();
      if (response.statusCode == 200) {
        return AuthStatus.success;
      }
      else if (response.statusCode == 400 || response.statusCode == 401 || response.statusCode == 403) {
        return AuthStatus.invalidCredentials;
      }
      else if (response.statusCode == 429) {
        return AuthStatus.manyAttepts;
      }
      else if (response.statusCode >= 500) {
        // 502/503/504 are the answers of a proxy restarting in front of the
        // server; a login refused by those is a blip, not a verdict, so they
        // join the 500 in the retried bucket.
        return AuthStatus.serverError;
      }
      else {
        return AuthStatus.unknown;
      }
    } on SocketException {
      return AuthStatus.socketException;
    } on TimeoutException {
      return AuthStatus.timeoutException;
    } on HandshakeException {
      return AuthStatus.handshakeException;
    } on HttpException {
      // Server closed the connection mid-request (wrong http/https scheme,
      // wrong port, proxy interference...): the HTTP exchange never completed.
      return AuthStatus.socketException;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      return AuthStatus.unknown;
    }
  }

  static Future<AuthStatus> loginHA(Server server) async {
    try {
      await LocalNetworkPermission.ensureGranted(server.domain);
      final result = await HttpRequestClient.get(urlPath: "/status", server: server);
      if (result.successful) {
        return AuthStatus.success;
      }
      else if (result.statusCode == 401 || result.statusCode == 403) {
        return AuthStatus.invalidCredentials;
      }
      else if (result.exception == ExceptionType.socket || result.exception == ExceptionType.http) {
        return AuthStatus.socketException;
      }
      else if (result.exception == ExceptionType.timeout) {
        return AuthStatus.timeoutException;
      }
      else if (result.exception == ExceptionType.handshake) {
        return AuthStatus.handshakeException;
      }
      else {
        return AuthStatus.unknown;
      }
    } on SocketException {
      return AuthStatus.socketException;
    } on TimeoutException {
      return AuthStatus.timeoutException;
    } on HandshakeException {
      return AuthStatus.handshakeException;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      return AuthStatus.unknown;
    }
  }
}