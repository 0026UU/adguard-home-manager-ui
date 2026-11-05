import 'package:flutter/material.dart';

import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/models/applied_filters.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/models/logs.dart';

class LogsProvider with ChangeNotifier {
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

  void setIsLoadingMore(bool status) {
    _isLoadingMore = status;
  }

  Future<bool> fetchLogs({
    int? inOffset,
    bool? loadingMore,
    String? searchText,
  }) async {
    int offst = inOffset ?? offset;

    if (loadingMore != null && loadingMore == true) {
      _isLoadingMore = true;
      notifyListeners();
    }

    final applied = _appliedFilters;
    final result = await _serversProvider!.apiClient2!.getLogs(
      count: logsQuantity, 
      offset: offst,
      olderThan: logsOlderThan,
      since: applied.since(DateTime.now()),
      reasons: applied.reasons,
      clients: applied.clients,
      search: searchText ?? _searchText
    );

    if (loadingMore != null && loadingMore == true) {
      _isLoadingMore = false;
      notifyListeners();
    }

    if (result.successful == true) {
      final incoming = result.content as LogsData;
      _offset = offst + incoming.data.length;
      // Servers that predate the `client` parameter ignore it, so the rows are
      // narrowed here as well; on a server that honours it this changes
      // nothing.  The selection may hold an address or a device name.
      final matching = incoming.data.where((item) =>
        applied.clients.isEmpty ||
        applied.clients.contains(item.client) ||
        applied.clients.contains(item.clientInfo?.name));
      _logsData = LogsData(
        data: [
          if (loadingMore == true && logsData != null) ...logsData!.data,
          ...matching,
        ],
        oldest: incoming.oldest,
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
