import 'package:flutter/material.dart';

import 'package:adguard_home_manager/providers/error_reason.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/models/applied_filters.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/models/logs.dart';

class LogsProvider with ChangeNotifier, ErrorReason {
  ServersProvider? _serversProvider;

  void update(ServersProvider? provider) {
    _serversProvider = provider;
  }

  LoadStatus _loadStatus = LoadStatus.loading;
  LogsData? _logsData;
  List<AutoClient>? _clients;

  DateTime? _logsOlderThan;
  String? _searchText;

  // The filter sheet edits these; only [filterLogs] promotes them to
  // [_appliedFilters], so closing the sheet without applying changes nothing.
  List<LogStatus> _selectedStatuses = [];
  List<String> _selectedClients = [];
  LogTimeRange _timeRange = LogTimeRange.twentyFourHours;

  int _logsQuantity = 100;
  int _offset = 0;

  bool _isLoadingMore = false;

  AppliedFiters _appliedFilters = AppliedFiters(
    statuses: [],
    searchText: null,
    clients: [],
    timeRange: LogTimeRange.twentyFourHours,
  );

  LoadStatus get loadStatus {
    return _loadStatus;
  }

  LogsData? get logsData {
    return _logsData;
  }

  List<AutoClient>? get clients {
    return _clients;
  }

  DateTime? get logsOlderThan {
    return _logsOlderThan;
  }

  List<LogStatus> get selectedStatuses {
    return _selectedStatuses;
  }

  String? get searchText {
    return _searchText;
  }
  
  int get logsQuantity {
    return _logsQuantity;
  }

  int get offset {
    return _offset;
  }

  List<String> get selectedClients {
    return _selectedClients;
  }

  LogTimeRange get timeRange {
    return _timeRange;
  }

  AppliedFiters get appliedFilters {
    return _appliedFilters;
  }

  bool get isLoadingMore {
    return _isLoadingMore;
  }

  void setLoadStatus(LoadStatus value) {
    _loadStatus = value;
    notifyListeners();
  }

  void setLogsData(LogsData data) {
    _logsData = data;
    notifyListeners();
  }

  void setClients(List<AutoClient> clients) {
    _clients = clients;
    notifyListeners();
  }
 
  void setLogsOlderThan(DateTime? value) {
    _logsOlderThan = value;
    notifyListeners();
  }

  /// Drops every filter but the search, which has a field of its own under the
  /// title.
  void resetFilters() {
    _logsOlderThan = null;
    _offset = 0;
    _selectedStatuses = [];
    _selectedClients = [];
    _timeRange = LogTimeRange.twentyFourHours;
    _appliedFilters = AppliedFiters(
      statuses: [],
      searchText: _searchText,
      clients: [],
      timeRange: LogTimeRange.twentyFourHours,
    );
    notifyListeners();
  }

  void setLogsQuantity(int value) {
    _logsQuantity = value;
    notifyListeners();
  }

  void setOffset(int value) {
    _offset = value;
  }

  void setSearchText(String? value) {
    _searchText = value;
    notifyListeners();
  }

  void setSelectedStatuses(List<LogStatus> statuses) {
    _selectedStatuses = List.of(statuses);
    notifyListeners();
  }

  void setSelectedClients(List<String>? clients) {
    _selectedClients = List.of(clients ?? []);
    notifyListeners();
  }

  void setTimeRange(LogTimeRange value) {
    _timeRange = value;
    notifyListeners();
  }

  void setAppliedFilters(AppliedFiters value) {
    _appliedFilters = value;
    _selectedStatuses = List.of(value.statuses);
    _searchText = value.searchText;
    _selectedClients = List.of(value.clients);
    _timeRange = value.timeRange;
    notifyListeners();
  }

  /// Seeds the client filter before a screen's first fetch, without
  /// notifying: the screen that calls this is still being built, and a
  /// notification then would mark the provider's scope dirty mid-build.
  /// The first fetch and the first paint both read the primed filters, so
  /// the list and its chip agree from the frame the screen appears on.
  void primeClientFilter(List<String> clients) {
    _selectedClients = List.of(clients);
    _appliedFilters = AppliedFiters(
      statuses: _selectedStatuses,
      searchText: _searchText,
      clients: _selectedClients,
      timeRange: _timeRange,
    );
  }

  void setIsLoadingMore(bool status) {
    _isLoadingMore = status;
  }

  /// Stock AdGuard Home answers `since` and `client` with the whole retained
  /// log, so the narrowing happens here.  Reading only one page would then
  /// show nothing whenever the rows that survive the filter sit past the first
  /// hundred, so the pages are walked until the window is full.
  static const int _maxFilterPages = 12;

  bool _keep(Log item, AppliedFiters applied, DateTime since) {
    if (!item.time.isAfter(since)) return false;
    if (applied.clients.isEmpty) return true;

    return applied.clients.contains(item.client) ||
        applied.clients.contains(item.clientInfo?.name);
  }

  Future<bool> fetchLogs({
    int? inOffset,
    bool? loadingMore,
    String? searchText,
  }) async {
    final applied = _appliedFilters;
    final since = applied.since(DateTime.now());
    final api = _serversProvider!.apiClient2!;
    setErrorMessage(null);

    if (loadingMore != null && loadingMore == true) {
      _isLoadingMore = true;
      notifyListeners();
    }

    final collected = <Log>[];
    var cursor = inOffset ?? offset;
    DateTime? oldest;
    var successful = false;

    for (var page = 0; page < _maxFilterPages; page++) {
      final result = await api.getLogs(
        count: logsQuantity,
        offset: cursor,
        olderThan: logsOlderThan,
        since: since,
        reasons: applied.reasons,
        clients: applied.clients,
        search: searchText ?? _searchText
      );

      if (result.successful != true) {
        // The walk stops at the first page the server refused, and the reason
        // it gave for that page is the reason the table says on screen.
        captureErrorReason(
          result,
          fallback: 'the server gave nothing back for the query log',
        );
        break;
      }
      successful = true;

      final incoming = result.content as LogsData;
      oldest = incoming.oldest;
      if (incoming.data.isEmpty) break;

      cursor += incoming.data.length;

      // Newest first, so the first row outside the window ends the search:
      // nothing further down can be inside it.
      final outsideWindow = incoming.data.any((item) => !item.time.isAfter(since));

      collected.addAll(
        incoming.data.where((item) => _keep(item, applied, since)),
      );

      if (collected.length >= logsQuantity || outsideWindow) break;
      if (incoming.data.length < logsQuantity) break;
    }

    if (loadingMore != null && loadingMore == true) {
      _isLoadingMore = false;
      notifyListeners();
    }

    if (successful) {
      _offset = cursor;
      _logsData = LogsData(
        data: [
          if (loadingMore == true && logsData != null) ...logsData!.data,
          ...collected,
        ],
        oldest: oldest,
      );
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

  Future<bool> requestResetFilters() async {
    _loadStatus = LoadStatus.loading;
    resetFilters();
    return fetchLogs(inOffset: 0);
  }

  Future<bool> filterLogs() async {
    _loadStatus = LoadStatus.loading;
    _appliedFilters = AppliedFiters(
      statuses: selectedStatuses,
      searchText: searchText,
      clients: selectedClients,
      timeRange: timeRange,
    );
    notifyListeners();
    return fetchLogs(inOffset: 0);
  }

  /// Drops one applied status and searches again, for the chip under the title.
  Future<bool> removeAppliedStatus(LogStatus status) {
    _appliedFilters = AppliedFiters(
      statuses: appliedFilters.statuses.where((s) => s != status).toList(),
      searchText: appliedFilters.searchText,
      clients: appliedFilters.clients,
      timeRange: appliedFilters.timeRange,
    );
    _selectedStatuses = List.of(_appliedFilters.statuses);
    _loadStatus = LoadStatus.loading;
    notifyListeners();
    return fetchLogs(inOffset: 0);
  }

  /// Drops the applied clients and searches again.
  Future<bool> removeAppliedClients() {
    _appliedFilters = AppliedFiters(
      statuses: appliedFilters.statuses,
      searchText: appliedFilters.searchText,
      clients: [],
      timeRange: appliedFilters.timeRange,
    );
    _selectedClients = [];
    _loadStatus = LoadStatus.loading;
    notifyListeners();
    return fetchLogs(inOffset: 0);
  }
}
