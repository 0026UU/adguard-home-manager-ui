/// The three quick statuses of the log filter sheet, in prototype order.
enum LogStatus { blocked, allowed, upstream }

/// The lookback window a query-log search is restricted to.
enum LogTimeRange { oneHour, sixHours, twentyFourHours, sevenDays }

/// Query-log reasons behind every [LogStatus], using the names the server
/// expects in its `reason` parameter.  Selecting several statuses sends the
/// union, which the server ORs together.
const Map<LogStatus, List<String>> logStatusReasons = {
  LogStatus.blocked: ['FilteredBlackList', 'FilteredBlockedService'],
  LogStatus.allowed: ['NotFilteredWhiteList'],
  LogStatus.upstream: ['NotFilteredNotFound', 'NotFilteredError'],
};

const Map<LogTimeRange, Duration> logTimeRangeDurations = {
  LogTimeRange.oneHour: Duration(hours: 1),
  LogTimeRange.sixHours: Duration(hours: 6),
  LogTimeRange.twentyFourHours: Duration(hours: 24),
  LogTimeRange.sevenDays: Duration(days: 7),
};

/// Every [LogStatus], used to tell "no restriction" from a real selection.
const List<LogStatus> allLogStatuses = LogStatus.values;

/// The filters a query-log search was actually run with, as opposed to the
/// ones the filter sheet is still editing.
class AppliedFiters {
  final List<LogStatus> statuses;
  final String? searchText;
  final List<String> clients;
  final LogTimeRange timeRange;

  AppliedFiters({
    required List<LogStatus> statuses,
    required this.searchText,
    required List<String> clients,
    required this.timeRange,
  })  : statuses = List.unmodifiable(statuses),
        clients = List.unmodifiable(clients);

  /// The `reason` values to send, empty when the search is unrestricted.
  ///
  /// Turning on every status would leave out the rewritten and safe-search
  /// entries, so a full selection is sent as no restriction at all.
  List<String> get reasons {
    if (statuses.isEmpty || statuses.length == allLogStatuses.length) return [];

    return [
      for (final status in statuses) ...logStatusReasons[status]!,
    ];
  }

  /// The lower time bound of the search.
  DateTime since(DateTime now) => now.subtract(logTimeRangeDurations[timeRange]!);
}
