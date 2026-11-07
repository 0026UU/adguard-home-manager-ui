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
import 'package:adguard_home_manager/providers/error_reason.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/functions/time_server_disabled.dart';

class StatusProvider with ChangeNotifier, ErrorReason {
  /// How long the background reconnect poll waits between attempts once the
  /// connection was declared dropped. Injectable for tests; the UI never
  /// drives this — recovery has to work without the user touching anything.
  StatusProvider({
    Duration autoReconnectInterval = const Duration(seconds: 5),
  }) : _autoReconnectInterval = autoReconnectInterval;

  /// How many consecutive failed status polls are absorbed before the
  /// connection is declared dropped. One blip — even one that exhausted the
  /// HTTP-level retry budget — must not disconnect a working session.
  static const int maxConsecutivePollFailures = 3;

  final Duration _autoReconnectInterval;

  ServersProvider? _serversProvider;

  void update(ServersProvider? provider) {
    _serversProvider = provider;
  }

  LoadStatus _loadStatus = LoadStatus.loading;
  ServerStatus? _serverStatus; // serverStatus != null means server is connected
  List<String> _protectionsManagementProcess = []; // protections that are currenty being enabled or disabled
  FilteringStatus? _filteringStatus;

  // Connection stability: the poll counter, the degraded flag the UI can
  // ignore, and the background timer that brings a dropped connection back.
  int _consecutivePollFailures = 0;
  bool _reconnecting = false;
  bool _needsCredentials = false;
  bool _statusPollInFlight = false;
  Timer? _autoReconnect;
  bool _disposed = false;

  // Statistics of one lookback window, asked for by the overview trend chart.
  DnsStatistics? _trend;
  int? _trendRecentMs;
  bool _trendLoading = false;
  bool _trendFailed = false;
  StatisticsConfig? _statisticsConfig;

  // Countdown
  DateTime? _currentDeadline;
  Timer? _countdown;
  int _remaining = 0;

  LoadStatus get loadStatus {
    return _loadStatus;
  }

  /// True while the last status poll failed but the connection is being kept
  /// (or is being brought back in the background). Lightweight on purpose:
  /// the UI can ignore it and keep showing the last good answer.
  bool get reconnecting {
    return _reconnecting;
  }

  /// True when the server refused the session and the one silent re-login
  /// with the stored credentials did not fix it. Only then is the user asked
  /// for credentials again.
  bool get needsCredentials {
    return _needsCredentials;
  }

  /// How many status polls in a row have failed; [loadStatus] only flips to
  /// error once this reaches [maxConsecutivePollFailures].
  int get consecutivePollFailures {
    return _consecutivePollFailures;
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
    return _statisticsConfig?.interval;
  }

  /// Clamps [recentMs] to a whole number of hours the server can answer.
  ///
  /// AdGuard Home keeps a rolling window (`statistics.interval`) and answers
  /// 400 for anything outside it, so a 30-day request against a server that
  /// only keeps a day asks for the day it does have.
  int recentWithinInterval(int recentMs) {
    final int hours = Duration(milliseconds: recentMs).inHours;
    final int? interval = statisticsIntervalMs;
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
      _statisticsConfig = result.content as StatisticsConfig;
      notifyListeners();
    }
  }

  /// True when the server cannot answer a trend of [recentMs] as it stands.
  bool needsLongerWindow(int recentMs) {
    final int? interval = statisticsIntervalMs;
    return interval != null && interval < recentMs;
  }

  /// Lengthens the window the server keeps so a longer trend becomes real.
  ///
  /// Retention is a server-wide setting, so this is only ever called after the
  /// user agreed to it. Everything else in the configuration is written back
  /// unchanged, because `PUT /stats/config/update` replaces the whole object.
  Future<bool> extendStatisticsInterval(int recentMs) async {
    final api = _serversProvider?.apiClient2;
    final StatisticsConfig? current = _statisticsConfig;
    if (api == null || current == null) return false;

    final result = await api.updateStatisticsSettings(
      body: <String, dynamic>{
        'enabled': current.enabled ?? true,
        'interval': recentMs,
        'ignored': current.ignored ?? <String>[],
      },
    );
    captureErrorReason(result);
    if (result.successful != true) return false;

    _statisticsConfig = StatisticsConfig(
      enabled: current.enabled ?? true,
      interval: recentMs,
      ignored: current.ignored ?? <String>[],
    );
    notifyListeners();
    return true;
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
    // A new attempt starts clean: the reason of a refusal that has since been
    // followed by an accepted switch must not be blamed for the next one.
    setErrorMessage(null);

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
          captureErrorReason(result);
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
          captureErrorReason(result);
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
          captureErrorReason(result);
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
          captureErrorReason(result);
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
          captureErrorReason(result);
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
    captureErrorReason(result);
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
    // The flag only gates the background timer: a poll the user triggered is
    // always run, but the reconnect timer must not stack polls on top of each
    // other and inflate the consecutive-failure count.
    _statusPollInFlight = true;
    try {
      return await _fetchServerStatus(
        withLoadingIndicator: withLoadingIndicator,
        overrideCheckServerVersion: overrideCheckServerVersion,
      );
    } finally {
      _statusPollInFlight = false;
    }
  }

  Future<bool> _fetchServerStatus({
    bool? withLoadingIndicator = true,
    bool? overrideCheckServerVersion
  }) async {
    if (withLoadingIndicator == true) {
      _loadStatus = LoadStatus.loading;
    }

    final result = await _serversProvider!.apiClient2!.getServerStatus();
    captureErrorReason(result);
    if (result.successful == true) {
      // The server answers again: whatever degraded state the polls before
      // this one left behind is over, without the user having done anything.
      _consecutivePollFailures = 0;
      _reconnecting = false;
      _needsCredentials = false;
      _stopAutoReconnect();

      final status = result.content as ServerStatus;
      setServerStatusData(
        data: status
      );
      _loadStatus = LoadStatus.loaded; 
      notifyListeners();

      // Check server version and launch modal if not valid
      final tooOld = serverVersionIsTooOld(
        currentVersion: status.serverVersion, 
        referenceVersion: MinimumServerVersion.stable,
        referenceVersionBeta: MinimumServerVersion.beta
      );
      if (tooOld && overrideCheckServerVersion != true) {
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
      _consecutivePollFailures += 1;
      _needsCredentials = result.needsCredentials == true;

      if (_needsCredentials || _serverStatus == null) {
        // A session the silent re-login could not save is no blip — only the
        // user can fix it — and a poll that never had an answer to keep has
        // nothing to stay connected on top of.
        _reconnecting = false;
        _stopAutoReconnect();
        _loadStatus = LoadStatus.error;
        notifyListeners();
        return false;
      }

      if (_consecutivePollFailures >= maxConsecutivePollFailures) {
        // The budget across consecutive polls is exhausted: only now does the
        // connection count as dropped, and the background timer takes over so
        // a server that comes back is found without user action.
        _reconnecting = true;
        _loadStatus = LoadStatus.error;
        notifyListeners();
        _startAutoReconnect();
        return false;
      }

      // A failed poll inside the budget: the connection is kept, the last
      // good answer stays on screen, and the next poll decides. Marking the
      // error here — as this provider used to — is what dropped the user back
      // to the disconnected state over a single blip.
      _reconnecting = true;
      _loadStatus = LoadStatus.loaded;
      notifyListeners();
      return false;
    }
  }

  void _startAutoReconnect() {
    if (_autoReconnect?.isActive == true) return;
    _autoReconnect = Timer.periodic(_autoReconnectInterval, (timer) async {
      if (_disposed || _statusPollInFlight) return;
      if (_serversProvider?.apiClient2 == null) {
        // The connection was removed while the timer ran: nothing to recover.
        timer.cancel();
        return;
      }
      try {
        // The success path of the poll cancels this timer and clears the
        // degraded state; a failure just counts towards the next attempt.
        await getServerStatus(withLoadingIndicator: false);
      } catch (_) {
        // The provider can be disposed while the poll is in flight; the
        // timer has nothing left to recover and must not keep firing.
        timer.cancel();
      }
    });
  }

  void _stopAutoReconnect() {
    _autoReconnect?.cancel();
    _autoReconnect = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _stopAutoReconnect();
    super.dispose();
  }

  Future<bool> blockUnblockDomain({
    required String domain,
    required String newStatus
  }) async {
    final api = _serversProvider?.apiClient2;
    final current = _serverStatus;
    setErrorMessage(null);
    if (api == null || current == null) {
      return setFailureReason('no server is connected to write the rule to');
    }
    if (newStatus != 'block' && newStatus != 'unblock') {
      return setFailureReason('the app asked to neither block nor unblock it');
    }
    if (RegExp(r'[^A-Za-z0-9_.-]').hasMatch(domain)) {
      return setFailureReason('"$domain" is not a domain name the server accepts');
    }

    final normalizedDomain = (domain.endsWith('.')
      ? domain.substring(0, domain.length - 1)
      : domain).toLowerCase();
    final label = RegExp(r'^[a-z0-9_](?:[a-z0-9_-]{0,61}[a-z0-9_])?$');
    if (normalizedDomain.isEmpty || normalizedDomain.length > 253 ||
        normalizedDomain.split('.').any((part) => !label.hasMatch(part))) {
      return setFailureReason('"$domain" is not a domain name the server accepts');
    }

    try {
      final rules = await api.getFilteringRules();
      if (!rules.successful || rules.content is! FilteringStatus) {
        captureErrorReason(
          rules,
          fallback: 'the server did not hand back the rules to change',
        );
        return false;
      }
      final latest = rules.content as FilteringStatus;
      final simpleRule = RegExp(
        r'^(?:@@)?\|\|' + RegExp.escape(normalizedDomain) + r'\.?\^$',
        caseSensitive: false,
      );
      final newRules = latest.userRules.where((rule) {
        final match = simpleRule.firstMatch(rule);
        return match == null || match.end != rule.length;
      }).toList();
      newRules.add(newStatus == 'block'
        ? '||$normalizedDomain^'
        : '@@||$normalizedDomain^');

      final result = await api.postFilteringRules(data: {'rules': newRules});
      captureErrorReason(
        result,
        fallback: 'the server refused the rewritten rule list',
      );
      if (!result.successful) return false;

      final updated = FilteringStatus(
        filters: latest.filters,
        whitelistFilters: latest.whitelistFilters,
        userRules: newRules,
        interval: latest.interval,
        enabled: latest.enabled,
      );
      _serverStatus = ServerStatus(
        stats: current.stats,
        clients: current.clients,
        filteringStatus: updated,
        timeGeneralDisabled: current.timeGeneralDisabled,
        disabledUntil: current.disabledUntil,
        generalEnabled: current.generalEnabled,
        filteringEnabled: current.filteringEnabled,
        safeSearchEnabled: current.safeSearchEnabled,
        safeBrowsingEnabled: current.safeBrowsingEnabled,
        parentalControlEnabled: current.parentalControlEnabled,
        serverVersion: current.serverVersion,
        safeSeachBing: current.safeSeachBing,
        safeSearchGoogle: current.safeSearchGoogle,
        safeSearchDuckduckgo: current.safeSearchDuckduckgo,
        safeSearchEcosia: current.safeSearchEcosia,
        safeSearchPixabay: current.safeSearchPixabay,
        safeSearchYandex: current.safeSearchYandex,
        safeSearchYoutube: current.safeSearchYoutube,
        dhcpAvailable: current.dhcpAvailable,
      );
      _filteringStatus = updated;
      notifyListeners();
      return true;
    }
    // The rewrite is a read-then-write, and either half can answer with
    // something that is not what this method expects. Swallowing that into a
    // bare `false` left the page saying only "could not be updated" over a
    // server that had in fact replied.
    catch (e) {
      return setFailureReason(
        'the rule list this app was given could not be rewritten ($e)',
      );
    }
  }

  Future<bool> updateSafeSearchConfig(Map<String, bool> status) async {
    final result = await _serversProvider!.apiClient2!.updateSafeSearchSettings(
      body: status
    );
    captureErrorReason(result);

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