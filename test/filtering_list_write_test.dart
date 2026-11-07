import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/services/api_client.dart';

// A filter only leaves the server once `/filtering/remove_url` or
// `/filtering/set_url` has taken the request, and no test can reach a server.
// The fake below answers the write and the read that follows it separately,
// because that pair is where the page used to lie.

final Server _server = Server(
  id: 'server-1',
  name: 'Test',
  connectionMethod: 'http',
  domain: '10.0.2.2',
  port: 3000,
  defaultServer: true,
  runningOnHa: false,
);

Filter _list(int index, {bool enabled = true}) => Filter(
  url: 'https://example.org/list-$index.txt',
  name: 'List $index',
  lastUpdated: null,
  id: index,
  rulesCount: 10 * (index + 1),
  enabled: enabled,
);

class _ListsApi extends ApiClientV2 {
  _ListsApi({
    required this.acceptsWrite,
    required this.answersRefresh,
    required this.serverLists,
  }) : super(server: _server);

  /// Whether the server takes the write.
  final bool acceptsWrite;

  /// Whether the status call that follows the write answers.
  final bool answersRefresh;

  /// What a successful refresh reports the server holding.
  final List<Filter> serverLists;

  int refreshes = 0;

  @override
  Future<ApiResponse> deleteFilterList({required Map<String, dynamic> data}) async {
    return ApiResponse(successful: acceptsWrite);
  }

  @override
  Future<ApiResponse> updateFilterList({required Map<String, dynamic> data}) async {
    return ApiResponse(successful: acceptsWrite);
  }

  @override
  Future<ApiResponse> getFiltering() async {
    refreshes++;
    if (!answersRefresh) return const ApiResponse(successful: false);

    return ApiResponse(
      successful: true,
      content: Filtering(
        filters: serverLists,
        whitelistFilters: const [],
        userRules: const [],
        blockedServices: const [],
        interval: 24,
        enabled: true,
      ),
    );
  }
}

FilteringProvider _providerWith(List<Filter> lists, _ListsApi api) {
  final servers = ServersProvider()
    ..setSelectedServer(_server)
    ..setApiClient2(api);

  return FilteringProvider()
    ..update(servers, null)
    ..setFilteringData(Filtering(
      filters: lists,
      whitelistFilters: const [],
      userRules: const [],
      blockedServices: const [],
      interval: 24,
      enabled: true,
    ));
}

void main() {
  test('a delete the server took is reported even when the refresh is silent',
      () async {
    final api = _ListsApi(
      acceptsWrite: true,
      answersRefresh: false,
      serverLists: const [],
    );
    final provider = _providerWith([_list(0), _list(1)], api);

    final deleted = await provider.deleteList(listUrl: 'https://example.org/list-0.txt', type: 'blacklist');

    expect(deleted, isTrue, reason: 'the server did delete the list');
    // The page drew `filters` straight from this provider, so the row that is
    // gone from the server has to be gone here too: reporting success while
    // still showing the list would be its own lie.
    expect(provider.filtering!.filters.map((f) => f.name), ['List 1']);
    expect(api.refreshes, 1, reason: 'the refresh is still asked for');
  });

  test('a delete the server refused keeps the list on screen', () async {
    final api = _ListsApi(
      acceptsWrite: false,
      answersRefresh: true,
      serverLists: [_list(0), _list(1)],
    );
    final provider = _providerWith([_list(0), _list(1)], api);

    final deleted = await provider.deleteList(listUrl: 'https://example.org/list-0.txt', type: 'blacklist');

    expect(deleted, isFalse);
    expect(provider.filtering!.filters.map((f) => f.name), ['List 0', 'List 1']);
    expect(api.refreshes, 0, reason: 'a refused write is not followed by a refresh');
  });

  test('a switch the server took is the switch the page shows', () async {
    final api = _ListsApi(
      acceptsWrite: true,
      answersRefresh: false,
      serverLists: const [],
    );
    final provider = _providerWith([_list(0)], api);

    final updated = await provider.updateList(
      list: _list(0),
      type: 'blacklist',
      action: FilteringListActions.disable,
    );

    expect(updated, isTrue);
    expect(provider.filtering!.filters.single.enabled, isFalse);
  });

  test('an accepted write still takes the server answer when it arrives',
      () async {
    // The refresh is what knows the rules count and the last update time, so
    // when it does answer its data wins over the local fold.
    final api = _ListsApi(
      acceptsWrite: true,
      answersRefresh: true,
      serverLists: [_list(1, enabled: false)],
    );
    final provider = _providerWith([_list(0), _list(1)], api);

    final deleted = await provider.deleteList(listUrl: 'https://example.org/list-0.txt', type: 'blacklist');

    expect(deleted, isTrue);
    expect(provider.filtering!.filters.single.name, 'List 1');
    expect(provider.filtering!.filters.single.enabled, isFalse);
  });
}
