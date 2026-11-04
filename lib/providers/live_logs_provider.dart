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

  DateTime? _lastTime;

  void startFetchLogs() {
    if (_isFetching) return;

    _isFetching = true;
    _lastTime = DateTime.now();
    _fetchLogs();
  }

  void stopFetchLogs() {
    _isFetching = false;
  }

  void clearLogs() {
    _logs = [];
    notifyListeners();
  }

  void _fetchLogs() async {
    if (_isDisposed || !_isFetching || _lastTime == null) return;

    final api = _serversProvider?.apiClient2;
    final result = api == null ? null : await api.getLogs(
      count: 100
    );

    // A failed poll only delays the next try, it does not end the stream.
    if (result?.successful == true && result?.content != null) {
      final valid = (result!.content as LogsData).data.where((e) => e.time.isAfter(_lastTime!));
      _logs = [...valid, ..._logs];
      if (_logs.length > _maxLogs) _logs.removeRange(_maxLogs, _logs.length);
      _lastTime = DateTime.now();
      notifyListeners();
    }

    await Future.delayed(const Duration(seconds: 2));
    if (_isDisposed || !_isFetching) return;
    _fetchLogs();
  }
}
