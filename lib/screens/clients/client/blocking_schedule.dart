import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/screens/clients/client/blocking_schedule_modal.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/models/clients.dart';

class EditBlockingSchedule {
  final String timezone;
  final List<String> weekday;
  final int start;
  final int end;

  const EditBlockingSchedule({
    required this.timezone,
    required this.weekday,
    required this.start,
    required this.end,
  });
}

/// The "pause service blocking" windows of a device: one row per weekday, each
/// reading the hours it covers.
class BlockingSchedule extends StatelessWidget {
  final BlockedServicesSchedule blockedServicesSchedule;
  final void Function(BlockedServicesSchedule) setBlockedServicesSchedule;

  const BlockingSchedule({
    super.key,
    required this.blockedServicesSchedule,
    required this.setBlockedServicesSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    void updateSchedule(EditBlockingSchedule v) {
      final scheduleJson = blockedServicesSchedule.toJson();
      for (var weekday in v.weekday) {
        scheduleJson[weekday] = {
          "start": v.start,
          "end": v.end
        };
      }
      scheduleJson["time_zone"] = v.timezone;
      setBlockedServicesSchedule(BlockedServicesSchedule.fromJson(scheduleJson));
    }

    void openAddScheduleModal() {
      showDialog<void>(
        context: context,
        builder: (context) => BlockingScheduleModal(
          onConfirm: updateSchedule,
        ),
      );
    }

    void openEditScheduleModal(String weekday) {
      final scheduleJson = blockedServicesSchedule.toJson();
      showDialog<void>(
        context: context,
        builder: (context) => BlockingScheduleModal(
          schedule: EditBlockingSchedule(
            timezone: blockedServicesSchedule.timeZone!,
            weekday: [weekday],
            start: scheduleJson[weekday]['start'],
            end: scheduleJson[weekday]['end'],
          ),
          onConfirm: updateSchedule,
        ),
      );
    }

    void onDeleteSchedule(String weekday) {
      final scheduleJson = blockedServicesSchedule.toJson();
      scheduleJson[weekday] = null;
      setBlockedServicesSchedule(BlockedServicesSchedule.fromJson(scheduleJson));
    }

    // Insertion ordered, so the rows always read Monday to Sunday whatever the
    // order the schedule came back in.
    final days = <String, String>{
      "mon": l.monday,
      "tue": l.tuesday,
      "wed": l.wednesday,
      "thu": l.thursday,
      "fri": l.friday,
      "sat": l.saturday,
      "sun": l.sunday,
    };

    final windows = <MapEntry<String, BlockedServicesScheduleDay>>[
      if (blockedServicesSchedule.mon != null) MapEntry("mon", blockedServicesSchedule.mon!),
      if (blockedServicesSchedule.tue != null) MapEntry("tue", blockedServicesSchedule.tue!),
      if (blockedServicesSchedule.wed != null) MapEntry("wed", blockedServicesSchedule.wed!),
      if (blockedServicesSchedule.thu != null) MapEntry("thu", blockedServicesSchedule.thu!),
      if (blockedServicesSchedule.fri != null) MapEntry("fri", blockedServicesSchedule.fri!),
      if (blockedServicesSchedule.sat != null) MapEntry("sat", blockedServicesSchedule.sat!),
      if (blockedServicesSchedule.sun != null) MapEntry("sun", blockedServicesSchedule.sun!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppleGroupHeader(
          title: l.pauseServiceBlocking,
          trailingWidget: AppleHeaderAction(
            label: l.add,
            onPressed: openAddScheduleModal,
          ),
        ),
        if (windows.isEmpty)
          AppleEmptyState(
            icon: CupertinoIcons.clock,
            title: l.noBlockingScheduleThisDevice,
          )
        else
          AppleListSection(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [
              for (final window in windows)
                AppleListTile(
                  title: days[window.key]!,
                  subtitle:
                      "${formatScheduleTime(window.value.start!)} - ${formatScheduleTime(window.value.end!)}",
                  showChevron: false,
                  onTap: () => openEditScheduleModal(window.key),
                  trailing: IconButton(
                    onPressed: () => onDeleteSchedule(window.key),
                    tooltip: l.delete,
                    icon: Icon(CupertinoIcons.trash, size: 19, color: p.red),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Reads a schedule hour, which AdGuard Home stores as milliseconds since
/// midnight, as the `hh:mm` the rows show.
String formatScheduleTime(int time) {
  final formatted = Duration(milliseconds: time);
  final hours = formatted.inHours;
  final minutes = formatted.inMinutes - hours*60;
  return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";
}
