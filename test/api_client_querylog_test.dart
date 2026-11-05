import 'dart:convert';
import 'dart:io';

import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer httpServer;
  late ApiClientV2 api;
  late List<HttpRequest> requests;
  late String responseBody;
  late int responseStatusCode;

  setUp(() async {
    requests = [];
    responseBody = jsonEncode({'data': [], 'oldest': ''});
    responseStatusCode = HttpStatus.ok;
    httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    api = ApiClientV2(
      server: Server(
        id: 'querylog-test',
        name: 'Query log test',
        connectionMethod: 'http',
        domain: httpServer.address.address,
        port: httpServer.port,
        defaultServer: false,
        runningOnHa: false,
      ),
    );
    httpServer.listen((request) async {
      requests.add(request);
      request.response.statusCode = responseStatusCode;
      request.response.headers.contentType = ContentType.json;
      request.response.write(responseBody);
      await request.response.close();
    });
  });

  tearDown(() async {
    await httpServer.close(force: true);
  });

  Uri expectQuery(Map<String, String> expected) {
    expect(requests, hasLength(1));
    final request = requests.single;
    expect(request.method, 'GET');
    expect(request.uri.path, '/control/querylog');
    expect(request.uri.fragment, isEmpty);
    expect(request.uri.queryParameters, expected);
    // Check all values as well, so duplicate injected parameters cannot hide.
    expect(
      request.uri.queryParametersAll,
      expected.map((key, value) => MapEntry(key, [value])),
    );
    return request.uri;
  }

  /// Like [expectQuery], for the parameters the server receives more than once.
  Uri expectQueryAll(Map<String, List<String>> expected) {
    expect(requests, hasLength(1));
    final request = requests.single;
    expect(request.method, 'GET');
    expect(request.uri.path, '/control/querylog');
    expect(request.uri.queryParametersAll, expected);
    return request.uri;
  }

  Future<Uri> expectSuccess(
    Future<ApiResponse> pending,
    Map<String, String> expected,
  ) async {
    final response = await pending;
    expect(response.successful, isTrue);
    expect(response.content, isA<LogsData>());
    final logs = response.content as LogsData;
    expect(logs.data, isEmpty);
    expect(logs.oldest, isNull);
    return expectQuery(expected);
  }

  test('empty arguments send the query log route without a query', () async {
    final uri = await expectSuccess(api.getLogs(), {});
    expect(uri.hasQuery, isFalse);
    expect(uri.toString(), '/control/querylog');
  });

  for (final value in [0, 25]) {
    test('count $value is sent as limit without other parameters', () async {
      await expectSuccess(api.getLogs(count: value), {'limit': '$value'});
    });

    test('offset $value is sent without other parameters', () async {
      await expectSuccess(api.getLogs(offset: value), {'offset': '$value'});
    });

    test('count and offset $value are both retained', () async {
      await expectSuccess(api.getLogs(count: value, offset: value), {
        'limit': '$value',
        'offset': '$value',
      });
    });
  }

  const searches = {
    'empty string': '',
    'ampersand': 'one&two',
    'plus': 'one+two',
    'hash': 'one#two',
    'quotes': '"double" \'single\'',
    'equals': 'key=value',
    'slash': 'one/two',
    'newline': 'one\ntwo',
    'Chinese': '中文查询',
    'combined characters': '中文 & + # "quoted" \'single\' = /\nnext%25?',
  };
  for (final entry in searches.entries) {
    test('search preserves ${entry.key} literally', () async {
      await expectSuccess(api.getLogs(search: entry.value), {
        'search': entry.value,
      });
    });
  }

  test('one reason arrives as one parameter', () async {
    final response = await api.getLogs(reasons: ['FilteredBlackList']);
    expect(response.successful, isTrue);
    expectQueryAll({
      'reason': ['FilteredBlackList'],
    });
  });

  test('several reasons repeat the parameter instead of joining it', () async {
    final response = await api.getLogs(reasons: const [
      'FilteredBlackList',
      'NotFilteredWhiteList',
      'NotFilteredNotFound',
    ]);
    expect(response.successful, isTrue);
    expectQueryAll({
      'reason': [
        'FilteredBlackList',
        'NotFilteredWhiteList',
        'NotFilteredNotFound',
      ],
    });
  });

  test('no reasons send no reason parameter', () async {
    await expectSuccess(api.getLogs(reasons: const []), {});
  });

  test('several clients repeat the parameter', () async {
    final response = await api.getLogs(
      clients: const ['192.168.1.2', 'testclient'],
    );
    expect(response.successful, isTrue);
    expectQueryAll({
      'client': ['192.168.1.2', 'testclient'],
    });
  });

  test('a reason value cannot inject another parameter', () async {
    const reason = 'FilteredBlackList&search=evil';
    final response = await api.getLogs(reasons: const [reason]);
    expect(response.successful, isTrue);
    expectQueryAll({
      'reason': [reason],
    });
  });

  test('a client value cannot inject a reason', () async {
    const client = '10.0.0.1&reason=NotFilteredWhiteList';
    final response = await api.getLogs(clients: const [client]);
    expect(response.successful, isTrue);
    expectQueryAll({
      'client': [client],
    });
  });

  test('search cannot inject a reason', () async {
    const search = 'example.com&reason=FilteredBlackList';
    await expectSuccess(api.getLogs(search: search), {'search': search});
  });

  test('UTC since keeps its timezone and microseconds', () async {
    final since = DateTime.utc(2026, 2, 3, 4, 5, 6, 789, 123);
    await expectSuccess(api.getLogs(since: since), {
      'since': '2026-02-03T04:05:06.789123Z',
    });
  });

  test('local since becomes a UTC RFC3339 timestamp', () async {
    final since = DateTime(2026, 2, 3, 4, 5, 6, 789, 123);
    expect(since.isUtc, isFalse);
    final uri = await expectSuccess(api.getLogs(since: since), {
      'since': since.toUtc().toIso8601String(),
    });
    final timestamp = uri.queryParameters['since']!;
    expect(timestamp, endsWith('Z'));
    expect(DateTime.parse(timestamp).isAtSameMomentAs(since), isTrue);
  });

  test('UTC olderThan keeps its timezone and microseconds', () async {
    final olderThan = DateTime.utc(2026, 2, 3, 4, 5, 6, 789, 123);
    await expectSuccess(api.getLogs(olderThan: olderThan), {
      'older_than': '2026-02-03T04:05:06.789123Z',
    });
  });

  test('local olderThan becomes a UTC RFC3339 timestamp', () async {
    final olderThan = DateTime(2026, 2, 3, 4, 5, 6, 789, 123);
    expect(olderThan.isUtc, isFalse);
    final uri = await expectSuccess(api.getLogs(olderThan: olderThan), {
      'older_than': olderThan.toUtc().toIso8601String(),
    });
    final timestamp = uri.queryParameters['older_than']!;
    expect(timestamp, endsWith('Z'));
    final decoded = DateTime.parse(timestamp);
    expect(decoded.isUtc, isTrue);
    expect(decoded.isAtSameMomentAs(olderThan), isTrue);
  });

  test('all existing arguments arrive together with exact values', () async {
    const search = '中文 + & # "quoted" = /\n';
    final response = await api.getLogs(
      count: 50,
      offset: 0,
      olderThan: DateTime.utc(2026, 2, 3, 4, 5, 6),
      since: DateTime.utc(2026, 2, 2, 4, 5, 6),
      reasons: const ['FilteredBlackList', 'NotFilteredNotFound'],
      clients: const ['192.168.1.2'],
      search: search,
    );
    expect(response.successful, isTrue);
    expectQueryAll({
      'limit': ['50'],
      'offset': ['0'],
      'older_than': ['2026-02-03T04:05:06.000Z'],
      'since': ['2026-02-02T04:05:06.000Z'],
      'reason': ['FilteredBlackList', 'NotFilteredNotFound'],
      'client': ['192.168.1.2'],
      'search': [search],
    });
  });

  for (final statusCode in [
    HttpStatus.badRequest,
    HttpStatus.internalServerError
  ]) {
    test('HTTP $statusCode returns unsuccessful even with valid logs',
        () async {
      responseStatusCode = statusCode;
      final response = await api.getLogs();
      expectQuery({});
      expect(response.successful, isFalse);
      expect(response.content, isNull);
    });
  }

  const malformedBodies = {
    'invalid JSON': '{',
    'missing oldest': '{"data":[]}',
    'invalid data type': '{"data":{},"oldest":""}',
  };
  for (final entry in malformedBodies.entries) {
    test('${entry.key} returns unsuccessful', () async {
      responseBody = entry.value;
      final response = await api.getLogs();
      expectQuery({});
      expect(response.successful, isFalse);
      expect(response.content, isNull);
    });
  }
}
