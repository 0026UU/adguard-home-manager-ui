import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/models/applied_filters.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/services/api_client.dart';

Log _log(
  String name, {
  String client = '192.0.2.1',
  String? clientName,
  DateTime? time,
}) => Log(
  cached: false,
  client: client,
  clientInfo: clientName == null
    ? null
    : ClientInfo(
        whois: Whois(),
        name: clientName,
        disallowedRule: '',
        disallowed: false,
      ),
  clientProto: 'dns',
  elapsedMs: '1',
  question: Question(questionClass: 'IN', name: name, type: 'A'),
  reason: 'NotFilteredNotFound',
  rules: [],
  // The server has no `since` parameter, so the window is cut here; a fixture
  // outside it would be dropped before the assertion under test could see it.
  time: time ?? DateTime.now(),
  upstream: '192.0.2.53',
  answer: [],
);

class _Api extends ApiClientV2 {
  final List<Map<String, Object?>> calls = [];
  final List<LogsData> pages = [];
  bool successful = true;
  Completer<ApiResponse>? pending;

  _Api() : super(server: Server(
    id: 'fixture', name: 'fixture', connectionMethod: 'http',
    domain: '127.0.0.1', defaultServer: false, runningOnHa: false,
  ));

  @override
  Future<ApiResponse> getLogs({
    int? count, int? offset, DateTime? olderThan, DateTime? since,
    List<String>? reasons, List<String>? clients, String? search,
  }) async {
    calls.add({
      'count': count, 'offset': offset, 'olderThan': olderThan, 'since': since,
      'reasons': reasons, 'clients': clients, 'search': search,
    });
    if (pending != null) return await pending!.future;
    if (!successful) return const ApiResponse(successful: false);
    return ApiResponse(successful: true, content: pages.removeAt(0));
  }
}

void main() {
  late _Api api;
  late ServersProvider servers;
  late LogsProvider logs;

  setUp(() {
    api = _Api();
    servers = ServersProvider()..setApiClient2(api);
    logs = LogsProvider()..update(servers);
  });

  tearDown(() {
    logs.dispose();
    servers.dispose();
  });

  test('the draft does not fetch until it is applied', () async {
    logs.setSelectedStatuses([LogStatus.blocked]);
    logs.setSelectedClients(['192.0.2.1']);
    logs.setTimeRange(LogTimeRange.sevenDays);
    await Future<void>.delayed(Duration.zero);
    expect(api.calls, isEmpty);
    expect(logs.selectedStatuses, [LogStatus.blocked]);
    expect(logs.selectedClients, ['192.0.2.1']);
    expect(logs.timeRange, LogTimeRange.sevenDays);
    expect(logs.appliedFilters.statuses, isEmpty);
    expect(logs.appliedFilters.clients, isEmpty);
    expect(logs.appliedFilters.timeRange, LogTimeRange.twentyFourHours);
  });

  test('applying the draft sends the wire reasons and the window once', () async {
    api.pages.add(LogsData(data: [_log('one.example')]));
    logs.setSelectedStatuses([LogStatus.blocked]);
    logs.setTimeRange(LogTimeRange.oneHour);

    final before = DateTime.now();
    expect(await logs.filterLogs(), isTrue);

    expect(api.calls, hasLength(1));
    expect(api.calls.single['reasons'], [
      'FilteredBlackList', 'FilteredBlockedService',
    ]);
    final since = api.calls.single['since'] as DateTime;
    expect(
      since.difference(before.subtract(const Duration(hours: 1))).abs(),
      lessThan(const Duration(seconds: 5)),
    );
    expect(logs.appliedFilters.statuses, [LogStatus.blocked]);
    expect(logs.appliedFilters.timeRange, LogTimeRange.oneHour);
    expect(logs.offset, 1);
  });

  for (final reset in [false, true]) {
    test('${reset ? 'reset' : 'apply'} advances past the first page', () async {
      logs.setLogsQuantity(2);
      api.pages.addAll([
        LogsData(data: [_log('one.example'), _log('two.example')]),
        LogsData(data: [_log('three.example'), _log('four.example')]),
      ]);
      expect(await (reset ? logs.requestResetFilters() : logs.filterLogs()), isTrue);
      expect(logs.offset, 2);
      expect(await logs.fetchLogs(loadingMore: true), isTrue);
      expect(api.calls.map((call) => call['offset']), [0, 2]);
      expect(logs.logsData!.data.map((log) => log.question.name), [
        'one.example', 'two.example', 'three.example', 'four.example',
      ]);
      expect(logs.offset, 4);
    });
  }

  test('reset clears the drafts and the applied filters but keeps the search',
      () async {
    logs.setSearchText('kept');
    logs.setAppliedFilters(AppliedFiters(
      statuses: [LogStatus.blocked], searchText: 'kept',
      clients: ['192.0.2.1'], timeRange: LogTimeRange.sevenDays,
    ));
    logs.setLogsOlderThan(DateTime.utc(2026));
    logs.setOffset(80);
    logs.resetFilters();
    expect(logs.selectedClients, isEmpty);
    expect(logs.selectedStatuses, isEmpty);
    expect(logs.timeRange, LogTimeRange.twentyFourHours);
    expect(logs.searchText, 'kept');
    expect(logs.logsOlderThan, isNull);
    expect(logs.offset, 0);
    expect(logs.appliedFilters.clients, isEmpty);
    expect(logs.appliedFilters.statuses, isEmpty);
    expect(logs.appliedFilters.timeRange, LogTimeRange.twentyFourHours);
    expect(api.calls, isEmpty);

    api.pages.add(LogsData(data: [_log('other.example', client: '192.0.2.2')]));
    expect(await logs.filterLogs(), isTrue);
    expect(logs.logsData!.data, hasLength(1));
    expect(api.calls.single['search'], 'kept');
    expect(api.calls.single['reasons'], isEmpty);
    expect(api.calls.single['clients'], isEmpty);
    expect(api.calls.single['olderThan'], isNull);
  });

  test('applying an external filter synchronizes the next request', () async {
    logs.setSelectedStatuses([LogStatus.blocked]);
    logs.setAppliedFilters(AppliedFiters(
      statuses: [LogStatus.upstream], searchText: 'new',
      clients: ['192.0.2.2'], timeRange: LogTimeRange.sixHours,
    ));
    api.pages.add(LogsData(data: [_log('new.example', client: '192.0.2.2')]));
    expect(await logs.fetchLogs(inOffset: 0), isTrue);
    expect(api.calls.single['reasons'], [
      'NotFilteredNotFound', 'NotFilteredError',
    ]);
    expect(api.calls.single['clients'], ['192.0.2.2']);
    expect(api.calls.single['search'], 'new');
    expect(logs.selectedStatuses, [LogStatus.upstream]);
    expect(logs.selectedClients, ['192.0.2.2']);
    expect(logs.timeRange, LogTimeRange.sixHours);
    expect(logs.logsData!.data, hasLength(1));
  });

  test('applied clients are a snapshot, not the editable draft', () async {
    final input = ['192.0.2.1'];
    logs.setSelectedClients(input);
    input.add('192.0.2.2');
    expect(logs.selectedClients, ['192.0.2.1']);
    api.pages.add(LogsData(data: []));
    await logs.filterLogs();
    logs.selectedClients.add('192.0.2.3');
    expect(logs.appliedFilters.clients, ['192.0.2.1']);
    expect(() => logs.appliedFilters.clients.add('192.0.2.4'), throwsUnsupportedError);
  });

  test('external applied filter copies the caller list', () {
    final input = ['192.0.2.1'];
    final applied = AppliedFiters(
      statuses: [], searchText: null, clients: input,
      timeRange: LogTimeRange.twentyFourHours,
    );
    logs.setAppliedFilters(applied);
    input.clear();
    logs.selectedClients.clear();
    expect(applied.clients, ['192.0.2.1']);
    expect(logs.appliedFilters.clients, ['192.0.2.1']);
  });

  test('every status selected asks for no reason at all', () async {
    logs.setSelectedStatuses(List.of(LogStatus.values));
    api.pages.add(LogsData(data: []));
    await logs.filterLogs();
    // Rewrites and safe search have no chip of their own, so a filter that
    // names all three would hide them.
    expect(api.calls.single['reasons'], isEmpty);
  });

  test('explicit fetch search is honored without altering the draft', () async {
    logs.setSearchText('saved');
    api.pages.addAll([LogsData(data: []), LogsData(data: [])]);
    await logs.fetchLogs(inOffset: 0, searchText: 'override');
    await logs.fetchLogs(inOffset: 0, searchText: '');
    expect(api.calls.map((call) => call['search']), ['override', '']);
    expect(logs.searchText, 'saved');
  });

  test('client filtering advances by raw rows without mutating API pages', () async {
    final first = LogsData(data: [_log('one'), _log('hidden', client: '192.0.2.2')]);
    final second = LogsData(data: [_log('three')], oldest: DateTime.utc(2026));
    logs.setSelectedClients(['192.0.2.1']);
    api.pages.addAll([first, second]);
    await logs.filterLogs();
    expect(logs.offset, 2);
    expect(first.data, hasLength(2));
    await logs.fetchLogs(loadingMore: true);
    expect(api.calls.map((call) => call['offset']), [0, 2]);
    expect(logs.logsData!.data.map((log) => log.question.name), ['one', 'three']);
    expect(logs.logsData!.oldest, second.oldest);
    expect(first.data, hasLength(2));
    expect(second.data, hasLength(1));
    expect(logs.offset, 3);
  });

  test('a server that ignores the client parameter is narrowed by name too',
      () async {
    logs.setSelectedClients(['livingroom-mac']);
    api.pages.add(LogsData(data: [
      _log('one.example', client: '192.0.2.9', clientName: 'livingroom-mac'),
      _log('two.example', client: '192.0.2.2'),
    ]));
    expect(await logs.filterLogs(), isTrue);
    expect(api.calls.single['clients'], ['livingroom-mac']);
    expect(logs.logsData!.data.map((log) => log.question.name), ['one.example']);
  });

  test('rows outside the window are dropped because the server has no since',
      () async {
    logs.setTimeRange(LogTimeRange.sixHours);
    api.pages.add(LogsData(data: [
      _log('fresh.example'),
      _log('stale.example', time: DateTime.now().subtract(const Duration(days: 2))),
    ]));
    expect(await logs.filterLogs(), isTrue);
    expect(logs.logsData!.data.map((log) => log.question.name), ['fresh.example']);
  });

  test('a narrow filter walks the log until the window is full', () async {
    logs.setLogsQuantity(2);
    logs.setSelectedClients(['192.0.2.1']);
    // Each page is the full request size, so nothing tells the provider the
    // log has ended; only the rows of the last page match the selection.
    LogsData page(int n) => LogsData(data: [
          _log('q$n.a.example', client: n == 3 ? '192.0.2.1' : '192.0.2.9'),
          _log('q$n.b.example', client: n == 3 ? '192.0.2.1' : '192.0.2.9'),
        ]);
    api.pages.addAll([page(0), page(1), page(2), page(3)]);

    expect(await logs.filterLogs(), isTrue);
    expect(api.calls.map((call) => call['offset']), [0, 2, 4, 6]);
    expect(logs.logsData!.data.map((log) => log.question.name),
        ['q3.a.example', 'q3.b.example']);
    expect(logs.offset, 8);
  });

  test('dropping a chip keeps the rest of the applied filter', () async {
    logs.setAppliedFilters(AppliedFiters(
      statuses: [LogStatus.blocked, LogStatus.allowed], searchText: null,
      clients: ['192.0.2.1'], timeRange: LogTimeRange.sevenDays,
    ));
    api.pages.addAll([LogsData(data: []), LogsData(data: [])]);

    expect(await logs.removeAppliedStatus(LogStatus.blocked), isTrue);
    expect(logs.appliedFilters.statuses, [LogStatus.allowed]);
    expect(logs.appliedFilters.clients, ['192.0.2.1']);
    expect(logs.appliedFilters.timeRange, LogTimeRange.sevenDays);
    expect(logs.selectedStatuses, [LogStatus.allowed]);
    expect(api.calls.last['reasons'], ['NotFilteredWhiteList']);

    expect(await logs.removeAppliedClients(), isTrue);
    expect(logs.appliedFilters.clients, isEmpty);
    expect(logs.appliedFilters.statuses, [LogStatus.allowed]);
    expect(logs.selectedClients, isEmpty);
    expect(api.calls.last['clients'], isEmpty);
    expect(api.calls.map((call) => call['offset']), [0, 0]);
  });

  test('short page advances by received count and empty page keeps position', () async {
    api.pages.addAll([LogsData(data: [_log('one')]), LogsData(data: [])]);
    await logs.fetchLogs(inOffset: 7);
    expect(logs.offset, 8);
    await logs.fetchLogs(loadingMore: true);
    expect(logs.offset, 8);
    expect(logs.logsData!.data, hasLength(1));
  });

  test('failed next page retains position and data for retry', () async {
    api.pages.add(LogsData(data: [_log('one')]));
    await logs.filterLogs();
    final previous = logs.logsData;
    api.successful = false;
    expect(await logs.fetchLogs(loadingMore: true), isFalse);
    expect(logs.logsData, same(previous));
    expect(logs.offset, 1);
    expect(logs.isLoadingMore, isFalse);
    expect(logs.loadStatus, LoadStatus.error);
    api.successful = true;
    api.pages.add(LogsData(data: [_log('two')]));
    expect(await logs.fetchLogs(loadingMore: true), isTrue);
    expect(api.calls.map((call) => call['offset']), [0, 1, 1]);
    expect(logs.logsData!.data.map((log) => log.question.name), ['one', 'two']);
  });

  test('loading-more indicator follows an in-flight request', () async {
    api.pending = Completer<ApiResponse>();
    final pending = logs.fetchLogs(loadingMore: true);
    expect(logs.isLoadingMore, isTrue);
    api.pending!.complete(ApiResponse(successful: true, content: LogsData(data: [])));
    expect(await pending, isTrue);
    expect(logs.isLoadingMore, isFalse);
    expect(logs.loadStatus, LoadStatus.loaded);
  });
}
