import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/services/api_client.dart';

// A custom rule only exists once `/filtering/set_rules` has taken it, and no
// test can reach a server, so the writes below are answered by a fake that
// says either yes or no.

final Server _server = Server(
  id: 'server-1',
  name: 'Test',
  connectionMethod: 'http',
  domain: '10.0.2.2',
  port: 3000,
  defaultServer: true,
  runningOnHa: false,
);

class _RulesApi extends ApiClientV2 {
  _RulesApi({required this.accepts}) : super(server: _server);

  /// Whether the server takes the rules it is sent.
  final bool accepts;

  /// The rules of the last write, so a test can see what was asked for.
  List<String>? lastRules;

  @override
  Future<ApiResponse> setCustomRules({required List<String> rules}) async {
    lastRules = rules;
    return ApiResponse(successful: accepts);
  }
}

FilteringProvider _providerWith(List<String> rules, _RulesApi api) {
  final servers = ServersProvider()
    ..setSelectedServer(_server)
    ..setApiClient2(api);

  return FilteringProvider()
    ..update(servers, null)
    ..setFilteringData(Filtering(
      filters: const [],
      whitelistFilters: const [],
      userRules: rules,
      blockedServices: const [],
      interval: 24,
      enabled: true,
    ));
}

void main() {
  test('a rule the server refuses never reaches the list on screen', () async {
    final provider = _providerWith(
      ['||ads.example.org^'],
      _RulesApi(accepts: false),
    );

    final added = await provider.addCustomRule('@@allowed.example.org');

    expect(added, isFalse);
    // The preview card draws `userRules` straight from this provider, so an
    // entry appended before the write answered would keep being shown as if
    // it filtered — and stay after the server said no.
    expect(provider.filtering!.userRules, ['||ads.example.org^']);
  });

  test('a rule the server takes lands once, after the answer', () async {
    final api = _RulesApi(accepts: true);
    final provider = _providerWith(['||ads.example.org^'], api);

    final added = await provider.addCustomRule('@@allowed.example.org');

    expect(added, isTrue);
    expect(api.lastRules, ['||ads.example.org^', '@@allowed.example.org']);
    expect(provider.filtering!.userRules, [
      '||ads.example.org^',
      '@@allowed.example.org',
    ]);
  });
}
