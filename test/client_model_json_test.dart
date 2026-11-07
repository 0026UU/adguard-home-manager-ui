import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/models/safe_search.dart';

Client buildClient({SafeSearch? safeSearch}) => Client(
  name: 'phone',
  blockedServices: [],
  ids: ['192.168.1.50'],
  tags: [],
  upstreams: [],
  rules: [],
  filteringEnabled: true,
  parentalEnabled: false,
  safebrowsingEnabled: false,
  useGlobalBlockedServices: true,
  useGlobalSettings: true,
  safeSearch: safeSearch,
  ignoreQuerylog: false,
  ignoreStatistics: false,
  upstreamsCacheEnabled: false,
  upstreamsCacheSize: 0,
  blockedServicesSchedule: null,
);

void main() {
  group('Client.toJson', () {
    test('encodes a client that has safe search settings', () {
      // POST /control/clients/add used to die here: the map carried the
      // SafeSearch object itself, so json.encode threw and every save of an
      // existing client answered "Client was not saved".
      final encoded = json.encode(
        buildClient(
          safeSearch: SafeSearch(
            enabled: true,
            bing: false,
            duckduckgo: true,
            ecosia: false,
            google: true,
            pixabay: false,
            yandex: false,
            youtube: true,
          ),
        ).toJson(),
      );

      expect(json.decode(encoded), isA<Map<String, dynamic>>());

      final roundTrip = Client.fromJson(
        json.decode(encoded) as Map<String, dynamic>,
      );
      expect(roundTrip.safeSearch!.enabled, isTrue);
      expect(roundTrip.safeSearch!.google, isTrue);
      expect(roundTrip.safeSearch!.bing, isFalse);
    });

    test('encodes a client that inherits the global safe search', () {
      final encoded = json.encode(buildClient().toJson());

      expect(json.decode(encoded)['safe_search'], isNull);
    });

    test('sends the keys the server reads', () {
      final body = buildClient(
        safeSearch: SafeSearch(
          enabled: false, bing: false, duckduckgo: false, ecosia: false,
          google: false, pixabay: false, yandex: false, youtube: false,
        ),
      ).toJson();

      for (final key in [
        'name', 'ids', 'tags', 'upstreams', 'rules', 'blocked_services',
        'filtering_enabled', 'parental_enabled', 'safebrowsing_enabled',
        'safe_search', 'use_global_blocked_services', 'use_global_settings',
        'ignore_querylog', 'ignore_statistics', 'upstreams_cache_enabled',
        'upstreams_cache_size',
      ]) {
        expect(body.containsKey(key), isTrue, reason: key);
      }
    });
  });
}
