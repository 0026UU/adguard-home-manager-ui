import 'package:flutter/material.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/error_reason.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/models/blocked_services.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';

enum FilteringListActions { edit, enable, disable }

class FilteringProvider with ChangeNotifier, ErrorReason {
  StatusProvider? _statusProvider;
  ServersProvider? _serversProvider;

  void update(ServersProvider? servers, StatusProvider? status) {
    _serversProvider = servers;
    _statusProvider = status;
  }

  LoadStatus _loadStatus = LoadStatus.loading;
  Filtering? _filtering;
  LoadStatus _blockedServicesLoadStatus = LoadStatus.loading;
  BlockedServices? _blockedServicesList;

  LoadStatus get loadStatus {
    return _loadStatus;
  }

  Filtering? get filtering {
    return _filtering;
  }

  LoadStatus get blockedServicesLoadStatus {
    return _blockedServicesLoadStatus;
  }

  BlockedServices? get blockedServices {
    return _blockedServicesList;
  }

  void setFilteringData(Filtering data) {
    _filtering = data;
    notifyListeners();
  }

  void setFilteringLoadStatus(LoadStatus loadStatus, bool notify) {
    _loadStatus = loadStatus;
    if (notify == true) {
      notifyListeners();
    }
  }

  void setFilteringProtectionStatus(bool status, bool notify) {
    _statusProvider!.setFilteringEnabledStatus(status);
    _filtering!.enabled = status;
    if (notify == true) notifyListeners();
  }

  void setFiltersUpdateFrequency(int frequency) {
    if (_filtering != null) {
      _filtering!.interval = frequency;
      notifyListeners();
    }
  }

  void setBlockedServices(List<String> blockedServices) {
    if (_filtering != null) {
      _filtering!.blockedServices = blockedServices;
      notifyListeners();
    }
  }

  void setBlockedServiceListData(List<BlockedService> data) {
    _blockedServicesList = BlockedServices(services: data);
    notifyListeners();
  }

  void setBlockedServicesListLoadStatus(LoadStatus status, bool notify) {
    _blockedServicesLoadStatus = status;
    if (notify == true) {
      notifyListeners();
    }
  }

  Future<bool> getBlockedServices({
    bool? showLoader
  }) async {
    _blockedServicesLoadStatus = LoadStatus.loading;
    if (showLoader == true) notifyListeners(); 

    final result = await _serversProvider!.apiClient2!.getBlockedServices();
    captureErrorReason(
      result,
      fallback: 'the server gave nothing back for the service names',
    );
    if (result.successful == true) {
      _blockedServicesLoadStatus = LoadStatus.loaded;
      _blockedServicesList = BlockedServices(services: result.content as List<BlockedService>);
      
      notifyListeners();
      return true;
    }
    else {
      // A failed fetch is an error whether or not a spinner was promised:
      // leaving the catalogue marked as loaded is what lets the picker render
      // an empty list under a server that never answered.
      _blockedServicesLoadStatus = LoadStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> fetchFilters({
    bool? showLoading
  }) async {
    if (showLoading == true) {
      _loadStatus = LoadStatus.loading;
    }

    final result = await _serversProvider!.apiClient2!.getFiltering();
    captureErrorReason(
      result,
      fallback: 'the server gave nothing back for the filter lists',
    );
    if (result.successful == true) {
      _filtering = result.content as Filtering;
      _loadStatus = LoadStatus.loaded;
      notifyListeners();
      return true;
    }
    else {
      _loadStatus = LoadStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> updateLists() async {
    final result = await _serversProvider!.apiClient2!.updateLists();
    if (result.successful == true) {
      final result2 = await _serversProvider!.apiClient2!.getFiltering();
      if (result2.successful == true) {
        _filtering = result2.content as Filtering;
        notifyListeners();
        return {
          "success": true,
          "data": result.content
        };
      }
      else {
        notifyListeners();
        return { "success": false };
      }
    }
    else {
      notifyListeners();
      return { "success": false };
    }
  }

  Future<bool> enableDisableFiltering() async {
    final newValue = !_statusProvider!.serverStatus!.filteringEnabled;
    final result = await _serversProvider!.apiClient2!.updateFiltering(
      enable: newValue
    );
    captureErrorReason(result);
    if (result.successful == true) {
      setFilteringProtectionStatus(newValue, false);
      notifyListeners();
      return true;
    }
    else {
      notifyListeners();
      return false;
    }
  }

  Future<bool> changeUpdateFrequency(int value) async {
    final result = await _serversProvider!.apiClient2!.requestChangeUpdateFrequency(
      data: {
        "enabled": filtering!.enabled,
        "interval": value
      }
    );
    captureErrorReason(result);
    if (result.successful == true) {
      setFiltersUpdateFrequency(value);
      return true;
    }
    else {
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeCustomRule(String rule) async {
    final List<String> newRules = filtering!.userRules.where((r) => r != rule).toList();

    final result = await _serversProvider!.apiClient2!.setCustomRules(rules: newRules);
    captureErrorReason(result);

    if (result.successful == true) {
      Filtering filteringData = filtering!;
      filteringData.userRules = newRules;
      _filtering = filteringData;
      
      notifyListeners();
      return true;
    }
    else {
      notifyListeners();
      return false;
    }
  }

  /// What the page shows after a write the server accepted, in the case the
  /// re-read below it does not answer.
  ///
  /// [Filter] is immutable apart from its switch, so an edit is a new object
  /// carrying the new name over the same url.
  Filter _foldWrite(Filter old, Filter incoming, FilteringListActions action) {
    if (old.url != incoming.url) return old;

    final toggled = action == FilteringListActions.enable ||
      action == FilteringListActions.disable;

    return Filter(
      url: incoming.url,
      name: incoming.name,
      lastUpdated: old.lastUpdated,
      id: old.id,
      rulesCount: old.rulesCount,
      // The request body flips the switch it was handed, so the server now
      // holds the opposite of what the row showed.
      enabled: toggled ? !incoming.enabled : incoming.enabled,
    );
  }

  /// Ask the server what it holds now, and keep the local answer if it does
  /// not reply: a write that worked is not undone by a slow refresh.
  Future<void> _reloadAfterWrite() async {
    final result = await _serversProvider!.apiClient2!.getFiltering();
    if (result.successful == true) {
      _filtering = result.content as Filtering;
    }
  }

  Future<bool> deleteList({
  required String listUrl,
  required String type
  }) async {        
    final result1 = await _serversProvider!.apiClient2!.deleteFilterList(
      data: {
        "url": listUrl,
        "whitelist": type == 'whitelist' ? true : false
      }
    );
    captureErrorReason(result1);
        
    if (result1.successful == true) {
      // The list is gone whether or not the refresh below answers. Returning
      // false on a failed refresh told the user the deleted list was still
      // there and left the same delete on screen to press again.
      final filteringData = filtering!;
      if (type == 'whitelist') {
        filteringData.whitelistFilters =
          filteringData.whitelistFilters.where((f) => f.url != listUrl).toList();
      }
      else {
        filteringData.filters =
          filteringData.filters.where((f) => f.url != listUrl).toList();
      }

      await _reloadAfterWrite();
      notifyListeners();
      return true;
    }
    else {
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateList({
    required Filter list,
    required String type,
    required FilteringListActions action
  }) async {        
    final result1 = await _serversProvider!.apiClient2!.updateFilterList(
      data: {
        "data": {
          "enabled": action == FilteringListActions.disable || action == FilteringListActions.enable
            ? !list.enabled
            : list.enabled,
          "name": list.name,
          "url": list.url
        },
        "url": list.url,
        "whitelist": type == 'whitelist' ? true : false
      }
    );
    captureErrorReason(result1);
        
    if (result1.successful == true) {
      // Same reason as the delete above: the switch the server now holds is
      // the one this page just asked for, so a refresh that does not answer
      // must not turn the toast red.
      final filteringData = filtering!;
      if (type == 'whitelist') {
        filteringData.whitelistFilters = filteringData.whitelistFilters
          .map((f) => _foldWrite(f, list, action))
          .toList();
      }
      else {
        filteringData.filters = filteringData.filters
          .map((f) => _foldWrite(f, list, action))
          .toList();
      }

      await _reloadAfterWrite();
      notifyListeners();
      return true;
    }
    else {
      notifyListeners();
      return false;
    }
  }

  Future<bool> addCustomRule(String rule) async {
    // A copy, not the live list: `userRules` is the very object the preview
    // card renders, so adding to it in place would show the rule before the
    // server agreed to it — and keep showing it after the server said no.
    final List<String> newRules = [...filtering!.userRules, rule];

    final result = await _serversProvider!.apiClient2!.setCustomRules(rules: newRules);
    captureErrorReason(result);
    
    if (result.successful == true) {
      Filtering filteringData = filtering!;
      filteringData.userRules = newRules;
      _filtering = filteringData;
      notifyListeners();
      return true;
    }
    else {
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> setCustomRules(List<String> rules) async {
    final newRules = rules.where((r) => r != " " && r != "").toList();
    final result = await _serversProvider!.apiClient2!.setCustomRules(rules: newRules);
    captureErrorReason(result);
    
    if (result.successful == true) {
      Filtering filteringData = filtering!;
      filteringData.userRules = newRules;
      _filtering = filteringData;
      notifyListeners();
      return true;
    }
    else {
      notifyListeners();
      return false;
    }
  }
  
  /// Adds one filter list, and says why it could not be added.
  ///
  /// The map keeps its historical `success`/`data`/`error` keys — the add
  /// button still branches on the two named errors — and gains `reason`, the
  /// server's own sentence where it has one. Every branch used to answer
  /// `error: null`, which is how a refused URL, a dead server and a
  /// half-finished refresh all came out of the app as the same "couldn't be
  /// added".
  Future<Map<String, dynamic>> addList({required String name, required String url, required String type}) async {
    final result1 = await _serversProvider!.apiClient2!.addFilteringList(
      data: {
        'name': name,
        'url': url,
        'whitelist': type == 'whitelist' ? true : false
      }
    );
    captureErrorReason(
      result1,
      fallback: 'the server did not say why it took the list',
    );

    if (result1.successful == true) {
      if (result1.content.toString().contains("OK")) {
        final result2 = await _serversProvider!.apiClient2!.getFiltering();
        final items = result1.content.toString().split(' ')[1];

        if (result2.successful == true) {
          _filtering = result2.content as Filtering;
          notifyListeners();
          return { 
            'success': true,
            'data': items
          };
        }
        else {
          // The list is on the server; only the refreshed table is missing.
          setErrorMessage(
            'the list was added but the server did not answer the refresh '
            'that would show it',
          );
          notifyListeners();
          return {
            'success': false,
            'error': null,
            'reason': errorMessage,
          };
        }
      }
      else {
        setErrorMessage(
          'the server answered "${result1.content}" instead of accepting the '
          'list',
        );
        notifyListeners();
        return {
          'success': false,
          'error': null,
          'reason': errorMessage,
        };
      }
    }
    else if (result1.successful == false && result1.statusCode == 400 && result1.content.toString().contains("data is HTML, not plain text")) {
      notifyListeners();
      return {
        'success': false,
        'error': 'invalid_url'
      };
    }
    else if (result1.successful == false && result1.statusCode == 400 && result1.content.toString().contains('url already exists')) {
      notifyListeners();
      return {
        'success': false,
        'error': 'url_exists'
      };
    }
    else {
      notifyListeners();
      return {
        'success': false,
        'error': null,
        'reason': errorMessage,
      };
    }
  }

  Future<bool> loadBlockedServices({
    bool? showLoading
  }) async {
    // Only worth announcing when it is a change, so a retry fired while the
    // page is still building does not notify during build.
    if (showLoading == true && _blockedServicesLoadStatus != LoadStatus.loading) {
      _blockedServicesLoadStatus = LoadStatus.loading;
      notifyListeners();
    } 

    final result = await _serversProvider!.apiClient2!.getBlockedServices();
    captureErrorReason(
      result,
      fallback: 'the server gave nothing back for the service names',
    );
    if (result.successful == true) {
      _blockedServicesList = BlockedServices(services: result.content as List<BlockedService>);
      _blockedServicesLoadStatus = LoadStatus.loaded;

      notifyListeners();
      return true;
    }
    else {
      // The error is recorded whether or not a spinner was promised: a
      // refresh that could not reach the service names must not leave the
      // previous grid standing there looking like the server's answer.
      _blockedServicesLoadStatus = LoadStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBlockedServices(List<String> values) async {
    final result = await _serversProvider!.apiClient2!.setBlockedServices(
      data: values
    );
    captureErrorReason(result);

    if (result.successful == true) {
      setBlockedServices(values); 
      return true;
    }
    else {
      notifyListeners();
      return false;
    }
  }

  Future<List<ProcessedList>> deleteMultipleLists({
    required List<Filter> blacklists,
    required List<Filter> whitelists
  }) async {
    Future<ProcessedList> deleteList({
      required Filter list,
      required bool isWhitelist,
    }) async {
      final result = await _serversProvider!.apiClient2!.deleteFilterList(
        data: {
          "url": list.url,
          "whitelist": isWhitelist
        }
      );
      if (result.successful == true) {
        return ProcessedList(list: list, successful: true);
      }
      else {
        // The picker reports a count, so this keeps only the last refusal —
        // but it keeps the server's sentence rather than nothing at all.
        captureErrorReason(result);
        return ProcessedList(list: list, successful: false);
      }
    }

    final resultWhitelists = await Future.wait(whitelists.map((e) => deleteList(list: e, isWhitelist: true)));
    final resultBlacklists = await Future.wait(blacklists.map((e) => deleteList(list: e, isWhitelist: false)));

    await fetchFilters();

    return [
      ...resultWhitelists,
      ...resultBlacklists,
    ];
  }

  Future<List<ProcessedList>> enableDisableMultipleLists({
    required List<Filter> blacklists,
    required List<Filter> whitelists
  }) async {
    Future<ProcessedList> enableDisableList({
      required Filter list,
      required bool isWhitelist,
    }) async {
        final result = await _serversProvider!.apiClient2!.updateFilterList(
        data: {
          "data": {
            "enabled": !list.enabled,
            "name": list.name,
            "url": list.url
          },
          "url": list.url,
          "whitelist": isWhitelist
        }
      );
      if (result.successful == true) {
        return ProcessedList(list: list, successful: true);
      }
      else {
        // The picker reports a count, so this keeps only the last refusal —
        // but it keeps the server's sentence rather than nothing at all.
        captureErrorReason(result);
        return ProcessedList(list: list, successful: false);
      }
    }

    final resultWhitelists = await Future.wait(whitelists.map((e) => enableDisableList(list: e, isWhitelist: true)));
    final resultBlacklists = await Future.wait(blacklists.map((e) => enableDisableList(list: e, isWhitelist: false)));

    await fetchFilters();

    return [
      ...resultWhitelists,
      ...resultBlacklists,
    ];
  }
}