import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/providers/live_logs_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/services/api_client.dart';

// The stream decides on its own which queries it has not shown yet, and the
// phone and AdGuard Home do not agree on the time. Every test here leans on
// that disagreement on purpose.

Log _log(String name, {required DateTime time}) => Log(
  cached: false,
  client: '192.0.2.1',
  clientProto: 'dns',
  elapsedMs: '1',
  question: Question(questionClass: 'IN', name: name, type: 'A'),
  reason: 'NotFilteredNotFound',
  rules: [],
  status: 'NOERROR',
  time: time,
  upstream: '192.0.2.53',
  answer: [],
);

class _Api extends ApiClientV2 {
  final List<LogsData> pages = [];

  _Api() : super(server: Server(
    id: 'fixture', name: 'fixture', connectionMethod: 'http',
    domain: '127.0.0.1', defaultServer: false, runningOnHa: false,
  ));

  @override
  Future<ApiResponse> getLogs({
    int? count, int? offset, DateTime? olderThan, DateTime? since,
    List<String>? reasons, List<String>? clients, String? search,
  }) async {
    if (pages.isEmpty) {
      return ApiResponse(successful: true, content: LogsData(data: const []));
    }

    return ApiResponse(successful: true, content: pages.removeAt(0));
  }
}

void main() {
  late _Api api;
  late ServersProvider servers;
  late LiveLogsProvider live;

  setUp(() {
    api = _Api();
    servers = ServersProvider()..setApiClient2(api);
    live = LiveLogsProvider()..update(servers);
  });

  tearDown(() {
    live.dispose();
    servers.dispose();
  });

  List<String> shown() => live.logs.map((log) => log.question.name!).toList();

  test('rows stamped behind the phone clock still arrive', () async {
    // An anchor of DateTime.now() hid everything a server running hours
    // behind the phone had recorded.
    final behind = DateTime.now().subtract(const Duration(hours: 5));
    api.pages.add(LogsData(data: [_log('one.example', time: behind)]));

    await live.fetchOnce();

    expect(shown(), ['one.example']);
    expect(live.newestTime, behind);
  });

  test('a page overlapping what is on screen is not shown twice', () async {
    final ahead = DateTime.now().add(const Duration(hours: 2));
    api.pages.add(LogsData(data: [_log('one.example', time: ahead)]));
    await live.fetchOnce();

    // The next read starts from the newest query and runs back over the row
    // the view already has.
    api.pages.add(LogsData(data: [
      _log('two.example', time: ahead.add(const Duration(minutes: 1))),
      _log('one.example', time: ahead),
    ]));
    await live.fetchOnce();

    expect(shown(), ['two.example', 'one.example']);
  });

  test('the first pass of a stream only says where it begins', () async {
    api.pages.add(LogsData(data: [_log('kept.example', time: DateTime.now())]));

    live.startFetchLogs();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    live.stopFetchLogs();

    // What the server already kept is the query log's page, not the live one,
    // and the stream takes it from here.
    expect(live.logs, isEmpty);
    expect(live.newestTime, isNotNull);

    api.pages.add(LogsData(data: [
      _log('fresh.example', time: DateTime.now().add(const Duration(minutes: 1))),
    ]));
    await live.fetchOnce();

    expect(shown(), ['fresh.example']);
  });

  test('a server correcting its own clock does not move the anchor back',
      () async {
    final newest = DateTime.now();
    api.pages.add(LogsData(data: [_log('one.example', time: newest)]));
    await live.fetchOnce();

    api.pages.add(LogsData(data: [
      _log('two.example', time: newest.subtract(const Duration(minutes: 30))),
    ]));
    await live.fetchOnce();

    expect(live.newestTime, newest);
    expect(shown(), ['one.example']);
  });

  test('clearing the stream forgets where it stood', () async {
    api.pages.add(LogsData(data: [_log('one.example', time: DateTime.now())]));
    await live.fetchOnce();

    live.clearLogs();

    expect(live.logs, isEmpty);
    expect(live.newestTime, isNull);

    // The pull after a clear reads the whole page again, which is what the
    // live view showing the queries up to now means.
    api.pages.add(LogsData(data: [_log('two.example', time: DateTime.now())]));
    await live.fetchOnce();

    expect(shown(), ['two.example']);
  });
}
