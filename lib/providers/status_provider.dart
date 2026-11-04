import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:adguard_home_manager/widgets/add_server/unsupported_version_modal.dart';

import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/config/minimum_server_version.dart';
import 'package:adguard_home_manager/functions/compare_versions.dart';
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';
import 'package:adguard_home_manager/models/dns_statistics.dart';
import 'package:adguard_home_manager/models/statistics_config.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/functions/time_server_disabled.dart';

class StatusProvider with ChangeNotifier {
  ServersProvider? _serversProvider;

  void update(ServersProvider? provider) {
    _serversProvider = provider;
  }

  LoadStatus _loadStatus = LoadStatus.loading;
  ServerStatus? _serverStatus; // serverStatus != null means server is connected
  List<String> _protectionsManagementProcess = []; // protections that are currenty being enabled or disabled
  FilteringStatus? _filteringStatus;

  // Statistics of one lookback window, asked for by the overview trend chart.
  DnsStatistics? _trend;
  int? _trendRecentMs;
  bool _trendLoading = false;
  bool _trendFailed = false;
  int? _statisticsIntervalMs;

  // Countdown
  DateTime? _currentDeadline;
  Timer? _countdown;
  int _remaining = 0;

  LoadStatus get loadStatus {
    return _loadStatus;
  }

  ServerStatus? get serverStatus {
    return _serverStatus;
  }

  List<String> get protectionsManagementProcess {
    return _protectionsManagementProcess;
  }

  FilteringStatus? get filteringStatus {
    return _filteringStatus;
  }

  DnsStatistics? get trend {
    return _trend;
  }

  /// How long the window [_trend] covers, in milliseconds.
  int? get trendRecentMs {
    return _trendRecentMs;
  }

  bool get trendLoading {
    return _trendLoading;
  }

  bool get trendFailed {
    return _trendFailed;
  }

  /// The statistics interval the server keeps, in milliseconds, or null while
  /// it is unknown. `recent` may not be asked for longer than this.
  int? get statisticsIntervalMs {
    return _statisticsIntervalMs;
  }

  /// Clamps [recentMs] to a whole number of hours the server can answer.
  ///
  /// AdGuard Home keeps a rolling window (`statistics.interval`) and answers
  /// 400 for anything outside it, so a 30-day request against a server that
  /// only keeps a day asks for the day it does have.
  int recentWithinInterval(int recentMs) {
    final int hours = Duration(milliseconds: recentMs).inHours;
    final int? interval = _statisticsIntervalMs;
    final int kept = interval == null
      ? hours
      : math.min(hours, Duration(milliseconds: interval).inHours);
    final int clamped = kept < 1 ? 1 : kept;
    return clamped * Duration.millisecondsPerHour;
  }

  /// Loads the window the server keeps, so trend requests can be clamped to it.
  Future<void> getStatisticsConfig() async {
    final api = _serversProvider?.apiClient2;
    if (api == null) return;

    final result = await api.getStatisticsConfig();
    if (result.successful == true) {
      _statisticsIntervalMs = (result.content as StatisticsConfig).interval;
      notifyListeners();
    }
  }

  /// Fetches the statistics of the last [recentMs] milliseconds.
  Future<void> getTrend({
    required int recentMs,
  }) async {
    final api = _serversProvider?.apiClient2;
    if (api == null) return;

    final int recent = recentWithinInterval(recentMs);

    _trendLoading = true;
    _trendFailed = false;
    _trendRecentMs = recent;
    notifyListeners();

    final result = await api.getStatistics(recentMs: recent);
    _trendLoading = false;
    if (result.successful == true) {
      _trend = result.content as DnsStatistics;
    }
    else {
      _trend = null;
      _trendFailed = true;
    }
    notifyListeners();
  }

  int get remainingTime {
    return _remaining;
  }

  DateTime? get currentDeadline {
    return _currentDeadline;
  }

  void setServerStatusData({
    required ServerStatus data,
  }) {
    _serverStatus = data;
    if (
      (_countdown == null ||( _countdown != null && _countdown!.isActive == false)) && 
      data.disabledUntil != null
    ) {
      startCountdown(data.disabledUntil!);
    }
    notifyListeners();
  }

  void setServerStatusLoad(LoadStatus status) {
    _loadStatus = status;
    notifyListeners();
  }

  void setFilteringStatus(FilteringStatus status) {
    _filteringStatus = status;
    notifyListeners();
  }

  void startCountdown(DateTime deadline) {
    stopCountdown();

    _currentDeadline = deadline;
    _remaining = deadline.difference(DateTime.now()).inSeconds+1;

    _countdown = Timer.periodic(
      const Duration(seconds: 1),
      (Timer timer) async {
        if (_remaining == 0) {
          timer.cancel();
          notifyListeners();
          getServerStatus();
        }
        else {
          _remaining = _remaining - 1;
          notifyListeners();
        }
      },
    );
  }

  void stopCountdown() {
    if (_countdown != null && _countdown!.isActive) {
      _countdown!.cancel();
      _countdown = null;
      _remaining = 0;
      _currentDeadline = null;
    }
  }

  Future<bool> updateBlocking({
    required String block, 
    required bool newStatus,
    int? time
  }) async {
    switch (block) {
      case 'general':
        _protectionsManagementProcess.add('general');
        notifyListeners();

        final result = await _serversProvider!.apiClient2!.updateGeneralProtection(
          enable: newStatus,
          time: time
        );

        _protectionsManagementProcess = _protectionsManagementProcess.where((e) => e != 'general').toList();

        if (result.successful == true) {
          _serverStatus!.generalEnabled = newStatus;
          if (time != null) {
            final deadline = generateTimeDeadline(time);
            _serverStatus!.timeGeneralDisabled = time;
            _serverStatus!.disabledUntil = deadline;
            startCountdown(deadline);
          }
          else {
            _serverStatus!.timeGeneralDisabled = 0;
            _serverStatus!.disabledUntil = null;
            stopCountdown();
          }
          notifyListeners();
          return true;
        }
        else {
          return false;
        }

      case 'filtering':
        _protectionsManagementProcess.add('filtering');
        notifyListeners();

        final result = await _serversProvider!.apiClient2!.updateFiltering(
          enable: newStatus,
        );

        _protectionsManagementProcess = _protectionsManagementProcess.where((e) => e != 'filtering').toList();

        if (result.successful == true) {
          _serverStatus!.filteringEnabled = newStatus;
          notifyListeners();
          return true;
        }
        else {
          return false;
        }

      case 'safeSearch':
        _protectionsManagementProcess.add('safeSearch');
        notifyListeners();

        final result = await _serversProvider!.apiClient2!.updateSafeSearchSettings(body: { 'enabled': newStatus });

        _protectionsManagementProcess = _protectionsManagementProcess.where((e) => e != 'safeSearch').toList();

        if (result.successful == true) {
          _serverStatus!.safeSearchEnabled = newStatus;
          notifyListeners();
          return true;
        }
        else {
          return false;
        }

      case 'safeBrowsing':
        _protectionsManagementProcess.add('safeBrowsing');
        notifyListeners();

        final result = await _serversProvider!.apiClient2!.updateSafeBrowsing(enable: newStatus);

        _protectionsManagementProcess = _protectionsManagementProcess.where((e) => e != 'safeBrowsing').toList();

        if (result.successful == true) {
          _serverStatus!.safeBrowsingEnabled = newStatus;
          notifyListeners();
          return true;
        }
        else {
          return false;
        }

      case 'parentalControl':
        _protectionsManagementProcess.add('parentalControl');
        notifyListeners();

        final result = await _serversProvider!.apiClient2!.updateParentalControl(enable: newStatus);

        _protectionsManagementProcess = _protectionsManagementProcess.where((e) => e != 'parentalControl').toList();

        if (result.successful == true) {
          _serverStatus!.parentalControlEnabled = newStatus;
          notifyListeners();
          return true;
        }
        else {
          return false;
        }

      default:
        return false;
    }
  }

  void setFilteringEnabledStatus(bool status) {
    _serverStatus!.filteringEnabled = status;
  }

  Future<bool> getFilteringRules() async {
    final result = await _serversProvider!.apiClient2!.getFilteringRules();
    if (result.successful == true) {
      _filteringStatus = result.content as FilteringStatus;
      notifyListeners();
      return true;
    }
    else {
      return false;
    }
  }

  Future<bool> getServerStatus({
    bool? withLoadingIndicator = true,
    bool? overrideCheckServerVersion
  }) async {
    if (withLoadingIndicator == true) {
      _loadStatus = LoadStatus.loading;
    }

    final result = await _serversProvider!.apiClient2!.getServerStatus();
    if (result.successful == true) {
      final status = result.content as ServerStatus;
      setServerStatusData(
        data: status
      );
      _loadStatus = LoadStatus.loaded; 
      notifyListeners();

      // Check server version and launch modal if not valid
      final validVersion = serverVersionIsAhead(
        currentVersion: status.serverVersion, 
        referenceVersion: MinimumServerVersion.stable,
        referenceVersionBeta: MinimumServerVersion.beta
      );
      if (validVersion == false && overrideCheckServerVersion != true) {
        showDialog(
          context: globalNavigatorKey.currentContext!, 
          builder: (ctx) => UnsupportedVersionModal(
            serverVersion: status.serverVersion, 
            onClose: () {
              _serversProvider!.setSelectedServer(null);
            }
          )
        );
      }
      return true;
    }
    else {
      if (withLoadingIndicator == true) _loadStatus = LoadStatus.error; 
      notifyListeners();
      return false;
    }
  }

  Future<bool> blockUnblockDomain({
    required String domain,
    required String newStatus
  }) async {
    if (_serverStatus == null) return false;

    final rules = await _serversProvider!.apiClient2!.getFilteringRules();

    if (rules.successful == true) {
      FilteringStatus oldStatus = _serverStatus!.filteringStatus;

      List<String> newRules = (rules.content as FilteringStatus).userRules.where((d) => !d.contains(domain)).toList();
      if (newStatus == 'block') {
        newRules.add("||$domain^");
      }
      else if (newStatus == 'unblock') {
        newRules.add("@@||$domain^");
      }
      FilteringStatus newObj = _serverStatus!.filteringStatus;
      newObj.userRules = newRules;
      _filteringStatus = newObj;

      final result = await _serversProvider!.apiClient2!.postFilteringRules(data: {'rules': newRules});
        
      if (result.successful == true) {
        return true;
      }
      else {
        _filteringStatus = oldStatus;
        return false;
      }
    }
    else {
      return false;
    }
  }

  Future<bool> updateSafeSearchConfig(Map<String, bool> status) async {
    final result = await _serversProvider!.apiClient2!.updateSafeSearchSettings(
      body: status
    );

    if (result.successful == true) {
      ServerStatus data = serverStatus!;
      data.safeSearchEnabled = status['enabled'] ?? false;
      data.safeSeachBing = status['bing'] ?? false;
      data.safeSearchDuckduckgo = status['duckduckgo'] ?? false;
      data.safeSearchGoogle = status['google'] ?? false;
      data.safeSearchPixabay = status['pixabay'] ?? false;
      data.safeSearchYandex = status['yandex'] ?? false;
      data.safeSearchYoutube = status['youtube'] ?? false;

      setServerStatusData(data: data);
      return true;
    }
    else {
      notifyListeners();
      return false;
    }
  }
}