import 'package:adguard_home_manager/models/applied_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppliedFiters filters({
    List<LogStatus> statuses = const [],
    LogTimeRange timeRange = LogTimeRange.twentyFourHours,
  }) =>
      AppliedFiters(
        statuses: statuses,
        searchText: null,
        clients: const [],
        timeRange: timeRange,
      );

  test('no status restricts nothing', () {
    expect(filters().reasons, isEmpty);
  });

  test('every status on restricts nothing either', () {
    // Rewrites and safe search have no chip of their own, so a full selection
    // has to mean "no restriction" instead of hiding them.
    expect(filters(statuses: LogStatus.values).reasons, isEmpty);
  });

  test('one status sends the reasons the server knows', () {
    expect(filters(statuses: const [LogStatus.blocked]).reasons, [
      'FilteredBlackList',
      'FilteredBlockedService',
    ]);
    expect(
      filters(statuses: const [LogStatus.allowed]).reasons,
      ['NotFilteredWhiteList'],
    );
    expect(filters(statuses: const [LogStatus.upstream]).reasons, [
      'NotFilteredNotFound',
      'NotFilteredError',
    ]);
  });

  test('several statuses send the union', () {
    expect(
      filters(statuses: const [LogStatus.blocked, LogStatus.allowed]).reasons,
      [
        'FilteredBlackList',
        'FilteredBlockedService',
        'NotFilteredWhiteList',
      ],
    );
  });

  test('since is the start of the chosen window', () {
    final now = DateTime(2026, 3, 4, 12);

    expect(
      filters(timeRange: LogTimeRange.oneHour).since(now),
      DateTime(2026, 3, 4, 11),
    );
    expect(
      filters(timeRange: LogTimeRange.sixHours).since(now),
      DateTime(2026, 3, 4, 6),
    );
    expect(
      filters(timeRange: LogTimeRange.twentyFourHours).since(now),
      DateTime(2026, 3, 3, 12),
    );
    expect(
      filters(timeRange: LogTimeRange.sevenDays).since(now),
      DateTime(2026, 2, 25, 12),
    );
  });

  test('the applied lists cannot be changed afterwards', () {
    final applied = filters(statuses: const [LogStatus.blocked]);

    expect(() => applied.statuses.add(LogStatus.allowed),
        throwsUnsupportedError);
    expect(() => applied.clients.add('10.0.0.1'), throwsUnsupportedError);
  });
}
