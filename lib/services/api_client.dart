import 'dart:async';
import 'dart:convert';

import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:adguard_home_manager/models/blocked_services.dart';
import 'package:adguard_home_manager/models/rewrite_status.dart';
import 'package:adguard_home_manager/models/querylog_config.dart';
import 'package:adguard_home_manager/models/statistics_config.dart';
import 'package:adguard_home_manager/models/dns_info.dart';
import 'package:adguard_home_manager/models/encryption.dart';
import 'package:adguard_home_manager/models/dhcp.dart';
import 'package:adguard_home_manager/models/rewrite_rules.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';
import 'package:adguard_home_manager/models/server_info.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/models/clients_allowed_blocked.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/models/dns_statistics.dart';
import 'package:adguard_home_manager/classes/http_client.dart';
import 'package:adguard_home_manager/services/auth.dart';

class ApiResponse {
  final bool successful;
  final dynamic content;
  final int? statusCode;

  /// True when the server refused the session and the one silent re-login
  /// with the stored credentials did not fix it: the connection now needs the
  /// user to supply credentials again. This is the only thing a 401 is allowed
  /// to change for a caller — no screen branches on raw status codes.
  final bool needsCredentials;

  /// The server's own one-line reason for a refused write, e.g. `adding
  /// client: another client "x" uses the same MAC "y"`.
  ///
  /// AdGuard Home puts the reason for a 4xx in the response body, and the
  /// write wrappers used to drop it, so the page could only ever say "Client
  /// could not be updated" while the server had explained exactly what was
  /// wrong. It is null for a successful call and for a body that carried
  /// nothing readable; a caller that only reads [successful] is unaffected.
  final String? message;

  const ApiResponse({
    required this.successful,
    this.content,
    this.statusCode,
    this.message,
    this.needsCredentials = false,
  });
}

class ApiClientV2 {
  final Server server;

  ApiClientV2({
    required this.server
  }) {
    // Wire the 401 hook once for the process: every client shares the same
    // static transport, and the recovery itself is per-server (it logs in
    // with the credentials stored on the row that just answered 401).
    HttpRequestClient.recoverSession ??= ServerAuth.reloginSilently;
  }

  /// The most the UI is asked to show for one refused write.
  static const int _maxMessageLength = 240;

  /// The response a write wrapper hands back.
  ///
  /// [content] keeps whatever the wrapper had already returned, so a caller
  /// reading it (the filter-list page reads the raw body of `add_url`) is
  /// untouched; [message] carries the server's reason, which used to be thrown
  /// away. The status code is only passed on by the wrappers that already
  /// passed it, because several screens branch on it and must not start
  /// branching where they did not before.
  ApiResponse _writeResult(
    HttpResponse result, {
    Object? content,
    int? statusCode,
  }) =>
      ApiResponse(
        successful: result.successful,
        content: content,
        statusCode: statusCode,
        message: _failureMessage(result),
        needsCredentials: result.statusCode == 401,
      );

  /// The reason the server gave for a non-2xx answer, or null when it gave
  /// none.
  ///
  /// `aghhttp.Error` writes a single plain-text line and `jsonDecode` of that
  /// throws, so the body is read as text first and only picked apart as JSON
  /// when it looks like JSON. An HTML error page — the answer of a proxy in
  /// front of the server — carries nothing a user can act on, so the page
  /// itself is dropped, but the status code is kept: it is the one thing that
  /// page says, and it separates a proxy that is down from a server that
  /// refused the credentials.
  static String? _failureMessage(HttpResponse result) {
    if (result.successful) return null;

    final fromBody = result.body == null ? null : _messageFromBody(result.body!);
    if (fromBody != null) return fromBody;

    // No readable body: first why the request never got an answer at all, then
    // what the answer said.
    return _transportMessage(result.exception) ?? _statusMessage(result.statusCode);
  }

  /// The least that can be said when the server answered a status code with
  /// nothing readable in the body — the 502 page of a reverse proxy in front
  /// of AdGuard Home, or a bare 401.
  static String? _statusMessage(int? statusCode) {
    if (statusCode == null) return null;

    if (statusCode == 401 || statusCode == 403) {
      return 'the server refused the credentials of this connection (HTTP $statusCode)';
    }
    if (statusCode == 404) {
      return 'this server has no such endpoint (HTTP 404)';
    }
    if (statusCode == 405) {
      return 'this server does not allow that method (HTTP 405)';
    }
    if (statusCode >= 500) {
      return 'the server answered HTTP $statusCode; a proxy in front of it may '
          'be answering instead';
    }
    return 'the server answered HTTP $statusCode';
  }

  /// The answer of a read that failed.
  ///
  /// The read wrappers used to answer every failure with a bare
  /// `ApiResponse(successful: false)`, so a screen could only ever say
  /// "could not be loaded" whether the server was down, refused the login, or
  /// handed back the HTML page of the proxy sitting in front of it. The status
  /// code is deliberately not passed on here: no screen branched on it for a
  /// read, and starting to would change behaviour this fix does not intend.
  ApiResponse _readFailure(HttpResponse result, String endpoint) => ApiResponse(
    successful: false,
    message: _failureMessage(result) ?? _unreadableMessage(endpoint),
    // The status code itself stays dropped for reads, but a 401 that survived
    // the silent re-login is the one thing the provider must act on.
    needsCredentials: result.statusCode == 401,
  );

  /// The body arrived and the server accepted it, but the model could not read
  /// it. This is what a reverse proxy in front of AdGuard Home looks like from
  /// here: a 200 with an HTML login page in it.
  ///
  /// A `FormatException` from `jsonDecode` and a `TypeError` from a model that
  /// insists on a field the server no longer sends both land here, and both
  /// used to be reported as a server that had not answered.
  static String _unreadableMessage(String endpoint) =>
      'the server answered $endpoint with something this app cannot read';

  static String? _messageFromBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          for (final key in const ['message', 'error']) {
            final value = decoded[key];
            if (value is String && value.trim().isNotEmpty) {
              return _oneLine(value);
            }
          }
        }
      } on FormatException {
        // Not JSON after all: the raw text below is the reason.
      }
    }

    if (trimmed.startsWith('<')) return null;
    return _oneLine(trimmed);
  }

  static String _oneLine(String text) {
    final line = text.split('\n').first.trim();
    return line.length <= _maxMessageLength
        ? line
        : '${line.substring(0, _maxMessageLength)}...';
  }

  /// Why the request never reached the server, said in a way the user can act
  /// on. A body — and therefore a real reason — is absent in all of these.
  static String? _transportMessage(ExceptionType? exception) {
    switch (exception) {
      case ExceptionType.timeout:
        return 'the server did not answer in time';
      case ExceptionType.socket:
        return 'the server could not be reached';
      case ExceptionType.handshake:
        return 'the TLS handshake with the server failed';
      case ExceptionType.http:
        return 'the server sent a response that could not be read';
      case ExceptionType.unknown:
        return 'the request did not complete';
      case null:
        return null;
    }
  }

  Future<ApiResponse> getServerVersion() async {
    final result = await HttpRequestClient.get(urlPath: '/status', server: server);
    if (result.successful == true) {
      try {
        return ApiResponse(
          successful: true,
          content: jsonDecode(result.body!)['version']
        );
      } on FormatException {
        return _readFailure(result, '/status');
      } catch (e, stackTrace) {
        Sentry.captureException(e, stackTrace: stackTrace);
        return _readFailure(result, '/status');
      }
    }
    else {
      return _readFailure(result, '/status');
    }
  }

  Future<ApiResponse> getServerStatus() async {
    // AdGuard Home limits the amount of concurrent connections, so the seven
    // calls go out in batches. Each batch used to carry its own 10s deadline,
    // which let the Overview spin for four times that against a host that
    // answers nothing; one deadline now covers the whole exchange.
    Future<List<HttpResponse>> batch(List<String> paths) => Future.wait(
      paths.map((p) => HttpRequestClient.get(urlPath: p, server: server))
    );

    // The order is the order the batches below answer in, and
    // [exchangeFailure] needs it to name the endpoint that broke.
    const paths = [
      '/stats', '/status',
      '/filtering/status', '/safesearch/status',
      '/safebrowsing/status', '/parental/status',
      '/clients',
    ];

    Future<List<HttpResponse>> exchange() async => [
      ...await batch(['/stats', '/status']),
      ...await batch(['/filtering/status', '/safesearch/status']),
      ...await batch(['/safebrowsing/status', '/parental/status']),
      ...await batch(['/clients']),
    ];

    final List<HttpResponse> results;
    try {
      results = await exchange().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      // The whole exchange ran out of the one deadline it is now given. The
      // individual responses never got to say anything, so this is the only
      // thing there is to say, and it is a great deal more than the bare
      // failure the Overview used to turn into "could not be loaded".
      return const ApiResponse(
        successful: false,
        message: 'the server did not answer the overview requests in time',
      );
    }

    final index = results.indexWhere((e) => !e.successful);
    if (index != -1) {
      return ApiResponse(
        successful: false,
        message: _failureMessage(results[index]) ?? _unreadableMessage(paths[index]),
        needsCredentials: results[index].statusCode == 401,
      );
    }

    if (results.map((e) => e.body).every((e) => e != null)) {
      try {
        final Map<String, dynamic> mappedData = {
          'stats': jsonDecode(results[0].body!),
          'clients': jsonDecode(results[6].body!)['clients'],
          'status': jsonDecode(results[1].body!),
          'filtering': jsonDecode(results[2].body!),
          'safeSearch': jsonDecode(results[3].body!),
          'safeBrowsingEnabled': jsonDecode(results[4].body!),
          'parentalControlEnabled': jsonDecode(results[5].body!),
        };
        return ApiResponse(
          successful: true,
          content: ServerStatus.fromJson(mappedData)
        );
      } on FormatException {
        return ApiResponse(
          successful: false,
          message: _unreadableMessage('the overview requests'),
        );
      } catch (e, stackTrace) {
        Sentry.captureException(e, stackTrace: stackTrace);
        return ApiResponse(
          successful: false,
          message: _unreadableMessage('the overview requests'),
        );
      }
    }
    else {
      return ApiResponse(
        successful: false,
        message: _unreadableMessage('the overview requests'),
      );
    }
  }

  /// Statistics for one lookback window.
  ///
  /// `GET /control/stats` takes a single optional query, `recent`, which is
  /// the lookback period in milliseconds. AdGuard Home rejects the request
  /// with 400 when it is not a whole number of hours or when it is longer
  /// than the interval the server keeps (`GET /control/stats/config`), so the
  /// caller has to clamp it before asking.
  Future<ApiResponse> getStatistics({
    int? recentMs,
  }) async {
    final result = await HttpRequestClient.get(
      urlPath: recentMs != null ? '/stats?recent=$recentMs' : '/stats',
      server: server,
    );
    if (result.successful == true) {
      try {
        return ApiResponse(
          successful: true,
          content: DnsStatistics.fromJson(jsonDecode(result.body!))
        );
      } catch (e, stackTrace) {
        Sentry.captureException(e, stackTrace: stackTrace);
        return _readFailure(result, '/stats');
      }
    }
    else {
      // `recent` is the one query the server checks before it answers, and it
      // says so in the body: "recent: out of range: must be no greater than
      // 86400000". Losing that sentence is what made the Overview trend card
      // look broken rather than clamped.
      return _readFailure(result, '/stats');
    }
  }

  Future<ApiResponse> updateFiltering({
    required bool enable
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: "/filtering/config", 
      server: server,
      body: {
        'enabled': enable
      }
    );
    return _writeResult(result);
  }

  Future<ApiResponse> updateSafeBrowsing({
    required bool enable
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: enable == true
        ? "/safebrowsing/enable"
        : "/safebrowsing/disable", 
      server: server,
    );
    return _writeResult(result);
  }

  Future<ApiResponse> updateParentalControl({
    required bool enable
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: enable == true
        ? "/parental/enable"
        : "/parental/disable", 
      server: server,
    );
    return _writeResult(result);
  }

  Future<ApiResponse> updateGeneralProtection({
    required bool enable,
    int? time,
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: "/protection", 
      server: server,
      body: {
        'enabled': enable,
        'duration': time
      }
    );
    return _writeResult(result);
  }

  Future<ApiResponse> getClients() async {
    const paths = ['/clients', '/access/list'];
    final results = await Future.wait(
      paths.map((p) => HttpRequestClient.get(urlPath: p, server: server))
    );
    final index = results.indexWhere((e) => !e.successful);
    if (index != -1) {
      // Which of the two broke is what makes the sentence useful: the devices
      // page and the access page read different endpoints, and a proxy that
      // answers 502 for one of them is a different failure from a server that
      // refuses the credentials for both.
      return ApiResponse(
        successful: false,
        message: _failureMessage(results[index]) ?? _unreadableMessage(paths[index]),
        needsCredentials: results[index].statusCode == 401,
      );
    }
    if (results.map((e) => e.body).every((e) => e != null)) {
      try {
        final clients = Clients.fromJson(jsonDecode(results[0].body!));
        clients.clientsAllowedBlocked = ClientsAllowedBlocked.fromJson(jsonDecode(results[1].body!));
        return ApiResponse(
          successful: true,
          content: clients
        );
      } catch (e, stackTrace) {
        Sentry.captureException(
          e, 
          stackTrace: stackTrace, 
          hint: Hint.withMap({ "statusCode": results.map((e) => e.statusCode.toString()) })
        );
        return ApiResponse(
          successful: false,
          message: _unreadableMessage('/clients'),
        );
      }
    }
    else {
      return ApiResponse(
        successful: false,
        message: _unreadableMessage('/clients'),
      );
    }
  }

  Future<ApiResponse> requestAllowedBlockedClientsHosts({
    required Map<String, List<String>?> body
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: "/access/set",
      server: server,
      body: body
    );
    if (result.statusCode == 400) {
      return ApiResponse(
        successful: false,
        content: "client_another_list",
        message: _failureMessage(result),
      );
    }
    return _writeResult(result);
  }

  Future<ApiResponse> getLogs({
    int? count, 
    int? offset,
    DateTime? olderThan,
    DateTime? since,
    List<String>? reasons,
    List<String>? clients,
    String? search
  }) async {
    // Repeated parameters are ORed by the server, so a list value becomes
    // several query parameters with the same name.
    final queryParameters = <String, dynamic>{
      if (count != null) 'limit': count.toString(),
      if (offset != null) 'offset': offset.toString(),
      if (olderThan != null) 'older_than': olderThan.toUtc().toIso8601String(),
      if (since != null) 'since': since.toUtc().toIso8601String(),
      if (reasons != null && reasons.isNotEmpty) 'reason': reasons,
      if (clients != null && clients.isNotEmpty) 'client': clients,
      if (search != null) 'search': search,
    };
    final uri = Uri(
      path: '/querylog',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final result = await HttpRequestClient.get(
      urlPath: uri.toString(),
      server: server
    );
    if (result.successful == true) {
      try {
        return ApiResponse(
          successful: true,
          content: LogsData.fromJson(jsonDecode(result.body!))
        );
      } catch (e, stackTrace) {
        Sentry.captureException(
          e, 
          stackTrace: stackTrace, 
          hint: Hint.withMap({ "statusCode": result.statusCode.toString() })
        );
        return ApiResponse(
          successful: false,
          message: _unreadableMessage('/querylog'),
        );
      }
    }
    else {
      // v1.0.0-b.2 checks the `reason` values it is given against its own enum
      // and answers 400 with the offending one — `parsing params: reason: bad
      // enum value: "Filtered"` — which is the whole diagnosis of a filter
      // sheet that has outgrown the server. It used to be thrown away.
      return _readFailure(result, '/querylog');
    }
  }

  Future<ApiResponse> getFilteringRules() async {
    final result = await HttpRequestClient.get(urlPath: '/filtering/status', server: server);
    if (result.successful == true) {
      try {
        return ApiResponse(
          successful: true,
          content: FilteringStatus.fromJson(jsonDecode(result.body!))
        );
      } catch (e, stackTrace) {
        Sentry.captureException(
          e, 
          stackTrace: stackTrace, 
          hint: Hint.withMap({ "statusCode": result.statusCode.toString() })
        );
        return _readFailure(result, '/filtering/status');
      }
    }
    else {
      return _readFailure(result, '/filtering/status');
    }
  }

  Future<ApiResponse> postFilteringRules({
    required Map<String, List<String>> data, 
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/filtering/set_rules', 
      server: server,
      body: data
    );
    return _writeResult(result);
  }

  Future<ApiResponse> postAddClient({
    required Map<String, dynamic> data, 
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/clients/add', 
      server: server,
      body: data
    );
    return _writeResult(result);
  }

  Future<ApiResponse> postUpdateClient({
    required Map<String, dynamic> data, 
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/clients/update', 
      server: server,
      body: data
    );
    return _writeResult(result);
  }

  Future<ApiResponse> postDeleteClient({
    required String name, 
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/clients/delete', 
      server: server,
      body: {'name': name},
    );
    return _writeResult(result);
  }

  Future<ApiResponse> getFiltering() async {
    final results1 = await  HttpRequestClient.get(urlPath: '/filtering/status', server: server);
    final results2 = await HttpRequestClient.get(urlPath: '/blocked_services/list', server: server);
    if (results1.successful == true && results1.body != null) {
      try {
        return ApiResponse(
          successful: true,
          content: Filtering.fromJson({
            ...jsonDecode(results1.body!),
            "blocked_services": results2.body != null 
              ? jsonDecode(results2.body!)
              : []
          })
        );
      } catch (e, stackTrace) {
        Sentry.captureException(
          e, 
          stackTrace: stackTrace, 
          hint: Hint.withMap({ "statusCode": [results1.statusCode, results2.statusCode].map((e) => e.toString()) })
        );
        return ApiResponse(
          successful: false,
          message: _unreadableMessage('/filtering/status'),
        );
      }
    }
    else {
      // `blocked_services/list` is allowed to fail here — the page still draws
      // the lists — so the reason can only ever come from the status call.
      return _readFailure(results1, '/filtering/status');
    }
  }

  Future<ApiResponse> setCustomRules({
    required List<String> rules, 
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/filtering/set_rules', 
      server: server,
      body: {'rules': rules},
    );
    return _writeResult(result);
  }

  Future<ApiResponse> addFilteringList({
    required Map<String, dynamic> data, 
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/filtering/add_url', 
      server: server,
      body: data,
    );
    return _writeResult(
      result,
      content: result.body,
      statusCode: result.statusCode,
    );
  }

  Future<ApiResponse> updateFilterList({
    required Map<String, dynamic> data, 
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/filtering/set_url', 
      server: server,
      body: data,
    );
    return _writeResult(result);
  }

  Future<ApiResponse> deleteFilterList({
    required Map<String, dynamic> data, 
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/filtering/remove_url', 
      server: server,
      body: data,
    );
    return _writeResult(result);
  }

  Future<ApiResponse> getServerInfo() async {
    final result = await HttpRequestClient.get(urlPath: "/status", server: server);
    if (result.successful) {
      try {
        return ApiResponse(
          successful: true,
          content: ServerInfoData.fromJson(jsonDecode(result.body!))
        );
      } catch (e, stackTrace) {
        Sentry.captureException(
          e, 
          stackTrace: stackTrace, 
          hint: Hint.withMap({ "statusCode": result.statusCode.toString() })
        );
        return _readFailure(result, '/status');
      }
    }
    else {
      return _readFailure(result, '/status');
    }
  }

  /// Re-downloads every enabled filter list.
  ///
  /// `POST /control/filtering/refresh` on v1.0.0-b.x answers the openapi
  /// `FilterRefreshResponse`, one integer — `{"updated": 123}` — and the two
  /// slices it used to answer with (`updated` and `failed`, by name) never
  /// existed, so the outcome of a single list is not something the endpoint
  /// says. The server also stamps `last_updated` on a list whose download
  /// failed, so that cannot be the signal either. What survives is the rules
  /// count: a list that was asked to update and still has none produced
  /// nothing, so it failed, and that is what [ApiResponse.content] reports
  /// under `failed`.
  ///
  /// The refresh runs for minutes on a real server (measured at 92-126 seconds
  /// for a single 190k-rule list), so it asks for the long deadline; the two
  /// snapshots around it are ordinary GETs.
  Future<ApiResponse> updateLists() async {
    final before = await _readEnabledLists();
    if (before == null) {
      return const ApiResponse(successful: false, message: 'the server did not report the filter lists');
    }

    // One refresh per list kind that has enabled entries, blacklist first. The
    // handler takes a non-blocking lock and answers 500 "filters update
    // procedure is already running" when two refreshes overlap, so the pair is
    // issued in sequence rather than at once.
    final Map<String, dynamic> outcomes = {};
    for (final entry in const [
      ['blacklist', false],
      ['whitelist', true],
    ]) {
      final String kind = entry[0] as String;
      final bool whitelist = entry[1] as bool;
      if (!before.any((list) => list['whitelist'] == whitelist)) continue;

      final result = await HttpRequestClient.post(
        urlPath: '/filtering/refresh',
        server: server,
        body: {'whitelist': whitelist},
        timeout: longRunningRequestTimeoutSeconds,
      );
      if (!result.successful) {
        return _writeResult(result);
      }
      outcomes[kind] = _updatedCountOf(result.body);
    }

    final after = await _readEnabledLists();
    if (after == null) {
      return const ApiResponse(successful: false, message: 'the server did not report the filter lists');
    }

    final List<String> failed = [];
    final List<String> updatedLists = [];
    for (final entry in after) {
      final String name = entry['name'] as String;
      final int rules = entry['rulesCount'] as int;
      final int previous = (before
              .firstWhere(
                (other) => other['id'] == entry['id'] && other['whitelist'] == entry['whitelist'],
                orElse: () => const {'rulesCount': -1},
              )['rulesCount'] as int);
      if (rules == 0) {
        failed.add(name);
      } else if (previous != rules) {
        updatedLists.add(name);
      }
    }

    final int reported = outcomes.values
        .whereType<int>()
        .fold(0, (total, value) => total + value);

    return ApiResponse(
      successful: true,
      content: {
        // The key and its type are what they always were, so a caller that
        // only read the count keeps working.
        'updated': reported,
        'updated_lists': updatedLists,
        'failed': failed,
        'total': after.length,
      },
    );
  }

  /// The enabled filter lists, one map per list, or null when the server did
  /// not answer `GET /control/filtering/status`.
  Future<List<Map<String, dynamic>>?> _readEnabledLists() async {
    final result = await HttpRequestClient.get(
      urlPath: '/filtering/status',
      server: server,
    );
    if (!result.successful || result.body == null) return null;

    try {
      final decoded = jsonDecode(result.body!);
      if (decoded is! Map) return null;

      final lists = <Map<String, dynamic>>[];
      for (final entry in const [
        ['filters', false],
        ['whitelist_filters', true],
      ]) {
        final raw = decoded[entry[0] as String];
        if (raw is! List) continue;
        for (final filter in raw.whereType<Map>()) {
          if (filter['enabled'] != true) continue;
          lists.add({
            'id': filter['id'],
            'name': filter['name'] ?? '',
            'rulesCount': (filter['rules_count'] as num?)?.toInt() ?? 0,
            'whitelist': entry[1] as bool,
          });
        }
      }
      return lists;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// The `{"updated": N}` of the refresh response; anything that is not a
  /// number is reported as zero rather than as a crash.
  static int _updatedCountOf(String? body) {
    if (body == null) return 0;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final value = decoded['updated'];
        if (value is num) return value.toInt();
      }
    } on FormatException {
      return 0;
    }
    return 0;
  }

  Future<ApiResponse> checkHostFiltered({
    required String host
  }) async {
    final result = await HttpRequestClient.get(urlPath: '/filtering/check_host?name=$host', server: server);
    if (result.successful) {
      try {
        return ApiResponse(
          successful: true,
          content: jsonDecode(result.body!)
        );
      } on FormatException {
        // A proxy that answers the page with its own HTML does it with a 200,
        // and this call used to have no guard at all: the decode threw out of
        // the wrapper and the modal that opened it never got an answer.
        return ApiResponse(
          successful: false,
          message: _unreadableMessage('/filtering/check_host'),
        );
      }
    }
    else {
      return _readFailure(result, '/filtering/check_host');
    }
  }

  Future<ApiResponse> requestChangeUpdateFrequency({
    required Map<String, dynamic> data, 
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/filtering/config', 
      server: server,
      body: data,
    );
    return _writeResult(result);
  }

  Future<ApiResponse> setBlockedServices({
    required List<String> data,
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/blocked_services/set', 
      server: server,
      body: data,
    );
    return _writeResult(result);
  }

  /// The DHCP state, or the reason the server says it has none.
  ///
  /// AdGuard Home answers both DHCP reads with **501** and a one-line reason
  /// whenever the platform cannot serve DHCP — `{"message":"dhcp: not
  /// supported on windows: unsupported operation"}` on the v1.0.0-b.2 fixture,
  /// and the same shape for a server installed as a service on a host with no
  /// usable interface. The wrapper used to fold that into a bare failure, so
  /// the page could only say "could not be loaded" while the server had
  /// already explained the whole thing. `GET /control/status` says the same in
  /// `dhcp_available`, and the DHCP screen uses that to show its
  /// not-available card; the reason here is what the screen has when the
  /// status was read but DHCP still refused, or the server never answered.
  Future<ApiResponse> getDhcpData() async {
    const paths = ['/dhcp/interfaces', '/dhcp/status'];
    final results = await Future.wait(
      paths.map((p) => HttpRequestClient.get(urlPath: p, server: server))
    );
    final index = results.indexWhere((e) => !e.successful);
    if (index != -1) {
      return ApiResponse(
        successful: false,
        message: _failureMessage(results[index]) ?? _unreadableMessage(paths[index]),
        needsCredentials: results[index].statusCode == 401,
      );
    }
    if (results.map((e) => e.body).every((e) => e != null)) {
      try {
        List<NetworkInterface> interfaces = List<NetworkInterface>.from(jsonDecode(results[0].body!).entries.map((entry) => NetworkInterface.fromJson(entry.value)));
        return ApiResponse(
          successful: true,
          content: DhcpModel(
            networkInterfaces: interfaces, 
            dhcpStatus: jsonDecode(results[1].body!)['message'] != null
              ? null
              : DhcpStatus.fromJson(jsonDecode(results[1].body!))
          )
        );
      } catch (e, stackTrace) {
        Sentry.captureException(
          e, 
          stackTrace: stackTrace, 
          hint: Hint.withMap({ "statusCode": results.map((e) => e.statusCode.toString()) })
        );
        return ApiResponse(
          successful: false,
          message: _unreadableMessage('/dhcp/interfaces'),
        );
      }
    }
    else {
      return ApiResponse(
        successful: false,
        message: _unreadableMessage('/dhcp/interfaces'),
      );
    }
  }

  Future<ApiResponse> saveDhcpConfig({
    required Map<String, dynamic> data,
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/dhcp/set_config', 
      server: server,
      body: data,
    );
    return _writeResult(result);
  }

  Future<ApiResponse> resetDhcpConfig() async {
    final result = await HttpRequestClient.post(
      urlPath: '/dhcp/reset', 
      server: server,
      body: {},
    );
    return _writeResult(result);
  }

  Future<ApiResponse> deleteStaticLease({
    required Map<String, dynamic> data
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/dhcp/remove_static_lease', 
      server: server,
      body: data,
    );
    return _writeResult(result);
  }

  Future<ApiResponse> createStaticLease({
    required Map<String, dynamic> data
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/dhcp/add_static_lease', 
      server: server,
      body: data,
    );
    if (result.statusCode == 400 && result.body != null && result.body!.contains('static lease already exists')) {
      return ApiResponse(
        successful: false,
        content: "already_exists",
        statusCode: 400,
        message: _failureMessage(result),
      );
    }
    if (result.statusCode == 400 && result.body != null && result.body!.contains('server is unconfigured')) {
      return ApiResponse(
        successful: false,
        content: "server_not_configured",
        statusCode: 400,
        message: _failureMessage(result),
      );
    }
    return _writeResult(result);
  }

  Future<ApiResponse> restoreAllLeases() async {
    final result = await HttpRequestClient.post(
      urlPath: '/dhcp/reset_leases', 
      server: server,
      body: {},
    );
    return _writeResult(result);
  }

  Future<ApiResponse> getDnsRewriteSettings() async {
    final result = await HttpRequestClient.get(urlPath: '/rewrite/settings', server: server);
    if (result.successful) {
      try {
        final data = RewriteStatus.fromJson(jsonDecode(result.body!));
        return ApiResponse(
          successful: true,
          content: data
        );
      } catch (e, stackTrace) {
        Sentry.captureException(
          e, 
          stackTrace: stackTrace, 
          hint: Hint.withMap({ "statusCode": result.statusCode.toString() })
        );
        return _readFailure(result, '/rewrite/settings');
      }
    }
    else {
      return const ApiResponse(successful: false);
    }
  }

  Future<ApiResponse> updateDnsRewriteSettings({
    required Map<String, dynamic> data,
  }) async {
    final result = await HttpRequestClient.put(
      urlPath: '/rewrite/settings/update', 
      server: server,
      body: data,
    );
    return _writeResult(result);
  }

  Future<ApiResponse> getDnsRewriteRules() async {
    final result = await HttpRequestClient.get(urlPath: '/rewrite/list', server: server);
    if (result.successful) {
      try {
        final List<RewriteRules> data = List<RewriteRules>.from(
          jsonDecode(result.body!).map((item) => RewriteRules.fromJson(item))
        );
        return ApiResponse(
          successful: true,
          content: data
        );
      } catch (e, stackTrace) {
        Sentry.captureException(
          e, 
          stackTrace: stackTrace, 
          hint: Hint.withMap({ "statusCode": result.statusCode.toString() })
        );
        return _readFailure(result, '/rewrite/list');
      }
    }
    else {
      return const ApiResponse(successful: false);
    }
  }

  Future<ApiResponse> deleteDnsRewriteRule({
    required Map<String, dynamic> data,
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/rewrite/delete', 
      server: server,
      body: data,
    );
    return _writeResult(result);
  }

  Future<ApiResponse> addDnsRewriteRule({
    required Map<String, dynamic> data,
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/rewrite/add', 
      server: server,
      body: data,
    );
    return _writeResult(result);
  }

  Future<ApiResponse> getQueryLogInfo() async {
    final result = await HttpRequestClient.get(urlPath: '/querylog/config', server: server);
    if (result.successful) {
      try {
        return ApiResponse(
          successful: true,
          content: QueryLogConfig.fromJson(jsonDecode(result.body!))
        );
      } catch (e, stackTrace) {
        Sentry.captureException(
          e, 
          stackTrace: stackTrace, 
          hint: Hint.withMap({ "statusCode": result.statusCode.toString() })
        );
        return _readFailure(result, '/querylog/config');
      }
    }
    else {
      return const ApiResponse(successful: false);
    }
  }

  Future<ApiResponse> updateQueryLogParameters({
    required Map<String, dynamic> data,
  }) async {
    final result = await HttpRequestClient.put(
      urlPath: '/querylog/config/update', 
      server: server,
      body: data,
    );
    return _writeResult(result);
  }

  Future<ApiResponse> clearLogs() async {
    final result = await HttpRequestClient.post(
      urlPath: '/querylog_clear', 
      server: server,
      body: {},
    );
    return _writeResult(result);
  }

  Future<ApiResponse> getDnsInfo() async {
    final result = await HttpRequestClient.get(urlPath: '/dns_info', server: server);
    if (result.successful) {
      try {
        return ApiResponse(
          successful: true,
          content: DnsInfo.fromJson(jsonDecode(result.body!))
        );
      } catch (e, stackTrace) {
        Sentry.captureException(
          e, 
          stackTrace: stackTrace, 
          hint: Hint.withMap({ "statusCode": result.statusCode.toString() })
        );
        return _readFailure(result, '/dns_info');
      }
    }
    else {
      return const ApiResponse(successful: false);
    }
  }

  Future<ApiResponse> setDnsConfig({
    required Map<String, dynamic> data,
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/dns_config', 
      server: server,
      body: data,
    );
    if (result.statusCode == 400) {
      return ApiResponse(
        successful: result.successful,
        content: "data_not_valid",
        statusCode: result.statusCode,
        message: _failureMessage(result),
      );
    }
    return _writeResult(result);
  }

  Future<ApiResponse> getEncryptionSettings() async {
    final result = await HttpRequestClient.get(urlPath: '/tls/status', server: server);
    if (result.successful) {
      try {
        return ApiResponse(
          successful: true,
          content: EncryptionData.fromJson(jsonDecode(result.body!))
        );
      } catch (e, stackTrace) {
        Sentry.captureException(
          e, 
          stackTrace: stackTrace, 
          hint: Hint.withMap({ "statusCode": result.statusCode.toString() })
        );
        return _readFailure(result, '/tls/status');
      }
    }
    else {
      return const ApiResponse(successful: false);
    }
  }

  Future<ApiResponse> getBlockedServices() async {
    final result = await HttpRequestClient.get(urlPath: '/blocked_services/all', server: server);
    if (result.successful) {
      try {
        return ApiResponse(
          successful: true,
          content: List<BlockedService>.from(
            BlockedServicesFromApi.fromJson(jsonDecode(result.body!)).blockedServices
          )
        );
      } catch (e, stackTrace) {
        Sentry.captureException(
          e, 
          stackTrace: stackTrace, 
          hint: Hint.withMap({ "statusCode": result.statusCode.toString() })
        );
        return _readFailure(result, '/blocked_services/all');
      }
    }
    else {
      return const ApiResponse(successful: false);
    }
  }

  Future<ApiResponse> checkEncryptionSettings({
    required Map<String, dynamic> data,
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/tls/validate', 
      server: server,
      body: data,
    );
    try {
      return ApiResponse(
        successful: result.successful,
        content: result.body != null ? EncryptionValidationResult(
          isObject: true,
          encryptionValidation: EncryptionValidation.fromJson(jsonDecode(result.body!))
        ) : null
      );
    } on FormatException {
      return ApiResponse(
        successful: result.successful,
        content: result.body != null ? EncryptionValidationResult(
          isObject: false,
          message: result.body
        ) : null
      );
    } catch (e, stackTrace) {
      Sentry.captureException(
        e, 
        stackTrace: stackTrace, 
        hint: Hint.withMap({ "statusCode": result.statusCode.toString() })
      );
      return const ApiResponse(successful: false);
    }
  }

  Future<ApiResponse> saveEncryptionSettings({
    required Map<String, dynamic> data,
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/tls/configure', 
      server: server,
      body: data,
    );
    return _writeResult(result, content: result.body);
  }

  Future<ApiResponse> resetDnsCache() async {
    final result = await HttpRequestClient.post(
      urlPath: '/cache_clear', 
      server: server,
    );
    return _writeResult(result);
  }

  Future<ApiResponse> checkServerUpdates() async {
    final results = await Future.wait([
      // recheck_now makes the server ask GitHub before it answers, so this is
      // one of the calls that is given the long deadline.
      HttpRequestClient.post(
        urlPath: '/version.json',
        server: server,
        body: { "recheck_now": true },
        timeout: longRunningRequestTimeoutSeconds,
      ),
      HttpRequestClient.get(urlPath: '/status', server: server),
    ]);
    if (
      results.map((e) => e.successful).every((e) => e == true) &&
      results.map((e) => e.body).every((e) => e != null)
    ) {
      try {
        final Map<String, dynamic> obj = {
          ...jsonDecode(results[0].body!),
          'current_version': ServerInfoData.fromJson(jsonDecode(results[1].body!)).version
        };
        return ApiResponse(
          successful: true,
          content: obj
        );
      } catch (e, stackTrace) {
        Sentry.captureException(
          e, 
          stackTrace: stackTrace, 
          hint: Hint.withMap({ "statusCode": results.map((e) => e.statusCode.toString()) })
        );
        return ApiResponse(
          successful: false,
          message: _unreadableMessage('/version.json'),
        );
      }
    }
    else {
      String? reason;
      for (final response in results) {
        reason ??= _failureMessage(response);
      }
      return ApiResponse(
        successful: false,
        message: reason ?? _unreadableMessage('/version.json'),
      );
    }
  }

  Future<ApiResponse> requestUpdateServer() async {
    final result = await HttpRequestClient.post(
      urlPath: '/update', 
      server: server,
      timeout: longRunningRequestTimeoutSeconds,
    );
    return _writeResult(result);
  }

  /// PUT /safesearch/settings replaces the whole object, so a body that only
  /// carries "enabled" would silently switch every engine off. Merge with what
  /// the server currently reports before sending.
  Future<ApiResponse> updateSafeSearchSettings({
    required Map<String, bool> body
  }) async {
    final current = await HttpRequestClient.get(
      urlPath: '/safesearch/status',
      server: server,
    );

    final Map<String, bool> merged = {};
    if (current.body != null) {
      try {
        (jsonDecode(current.body!) as Map<String, dynamic>)
          .forEach((key, value) { if (value is bool) merged[key] = value; });
      } on FormatException {
        merged.clear();
      } on TypeError {
        merged.clear();
      }
    }
    merged.addAll(body);

    final result = await HttpRequestClient.put(
      urlPath: '/safesearch/settings', 
      server: server,
      body: merged
    );
    return _writeResult(result);
  }

  Future<ApiResponse> updateRewriteRule({
    required Map<String, dynamic> body
  }) async {
    final result = await HttpRequestClient.put(
      urlPath: '/rewrite/update', 
      server: server,
      body: body
    );
    return _writeResult(result);
  }

  /// Which upstreams the server can actually reach.
  ///
  /// v1.0.0-b.2 takes the four lists here — `upstream_dns`, `bootstrap_dns`,
  /// `fallback_dns`, `private_upstream` — and answers a map of the address it
  /// tried to the string `OK` or to the failure it got, which is what the
  /// dialog lists. Sending its `server`/`protocols` shape instead answers `{}`
  /// for every entry, so the picker would have shown an empty result over a
  /// server that had tested nothing.
  ///
  /// A body the client cannot decode is a failure with a reason, not an
  /// exception: this wrapper had no guard at all, and the modal that opens it
  /// would have died on the HTML page of a proxy answering 200.
  Future<ApiResponse> testUpstreamDns({
    required Map<String, dynamic> body
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/test_upstream_dns', 
      server: server,
      body: body
    );
    if (!result.successful) {
      return _writeResult(result);
    }
    try {
      return ApiResponse(
        successful: true,
        content: result.body != null ? jsonDecode(result.body!) : null,
      );
    } on FormatException {
      return ApiResponse(
        successful: false,
        message: _unreadableMessage('/test_upstream_dns'),
      );
    }
  }

  Future<ApiResponse> getStatisticsConfig() async {
    final result = await HttpRequestClient.get(urlPath: '/stats/config', server: server);
    if (result.successful) {
      try {
        return ApiResponse(
          successful: true,
          content: StatisticsConfig.fromJson(jsonDecode(result.body!))
        );
      } catch (e, stackTrace) {
        Sentry.captureException(
          e, 
          stackTrace: stackTrace, 
          hint: Hint.withMap({ "statusCode": result.statusCode.toString() })
        );
        return _readFailure(result, '/stats/config');
      }
    }
    else {
      return const ApiResponse(successful: false);
    }
  }

  Future<ApiResponse> updateStatisticsSettings({
    required Map<String, dynamic> body
  }) async {
    final result = await HttpRequestClient.put(
      urlPath: '/stats/config/update', 
      server: server,
      body: body
    );
    return _writeResult(result);
  }
}