import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';

class LiveLogsProvider with ChangeNotifier {
  ServersProvider? _serversProvider;

  void update(ServersProvider? provider) {
    _serversProvider = provider;
  }

  bool _isDisposed = false;
  
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// The stream only runs while the live view is the one on screen.
  bool _isFetching = false;

  bool get isFetching {
    return _isFetching;
  }

  List<Log> _logs = [];

  List<Log> get logs {
    return _logs;
  }

  /// The live view is a stream, not an archive; anything older than this is
  /// the server's query log.
  static const int _maxLogs = 500;

  /// The newest query the stream has read, in the server's own clock, and the
  /// only thing "new" is measured against.  The phone and the server never
  /// agree on the time, so a wall-clock anchor replays rows it already showed
  /// or hides them for good.
  DateTime? _newestTime;

  DateTime? get newestTime {
    return _newestTime;
  }

  void startFetchLogs() {
    if (_isFetching) return;

    _isFetching = true;
    _keepFetching();
  }

  void stopFetchLogs() {
    _isFetching = false;
  }

  /// One pass of the stream, for the live view when it is not refreshing on
  /// its own: the queries up to now, and then it waits for a pull.
  Future<void> fetchOnce() async {
    await _fetchLogs(takesThePageWhenUnanchored: true);
  }

  void clearLogs() {
    _logs = [];
    _newestTime = null;
    notifyListeners();
  }

  void _keepFetching() async {
    await _fetchLogs();

    await Future.delayed(const Duration(seconds: 2));
    if (_isDisposed || !_isFetching) return;
    _keepFetching();
  }

  Future<void> _fetchLogs({
    bool takesThePageWhenUnanchored = false,
  }) async {
    if (_isDisposed) return;

    final api = _serversProvider?.apiClient2;
    final result = api == null ? null : await api.getLogs(
      count: 100
    );

    // A failed poll only delays the next try, it does not end the stream.
    if (result?.successful != true || result?.content == null) return;

    final incoming = (result!.content as LogsData).data;
    final anchor = _newestTime;

    // The first pass of a stream only says where it begins; the queries the
    // server already kept belong to the query log, unless the user pulled.
    final fresh = anchor == null
      ? (takesThePageWhenUnanchored ? incoming : const <Log>[])
      : incoming.where((log) => log.time.isAfter(anchor));

    // Only ever forward: a server that corrects its own clock must not make
    // the stream replay what the view already shows.
    var newest = anchor;
    for (final log in incoming) {
      if (newest == null || log.time.isAfter(newest)) newest = log.time;
    }
    _newestTime = newest;

    if (fresh.isEmpty) return;

    _logs = [...fresh, ..._logs];
    if (_logs.length > _maxLogs) _logs.removeRange(_maxLogs, _logs.length);
    notifyListeners();
  }
}
