import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/screens/clients/client/blocking_schedule.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Editor for one "pause service blocking" window: a timezone, the weekdays it
/// repeats on and the hours it covers.
class BlockingScheduleModal extends StatefulWidget {
  final EditBlockingSchedule? schedule;
  final void Function(EditBlockingSchedule) onConfirm;

  const BlockingScheduleModal({
    super.key,
    this.schedule,
    required this.onConfirm,
  });

  @override
  State<BlockingScheduleModal> createState() => _BlockingScheduleModalState();
}

class _BlockingScheduleModalState extends State<BlockingScheduleModal> {
  String? _timezone;
  List<String> _weekdays = [];
  TimeOfDay? _from;
  TimeOfDay? _to;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();

    final schedule = widget.schedule;
    if (schedule != null) {
      _timezone = schedule.timezone;
      // A copy: the schedule the caller handed over describes the saved window,
      // and ticking another day must not rewrite it until "confirm".
      _weekdays = List.of(schedule.weekday);
      _from = _intToTimeOfDay(schedule.start);
      _to = _intToTimeOfDay(schedule.end);
    }
  }

  bool _compareTimes(TimeOfDay startTime, TimeOfDay endTime) {
    final startTimeInt = (startTime.hour * 60 + startTime.minute) * 60;
    final endTimeInt = (endTime.hour * 60 + endTime.minute) * 60;
    return endTimeInt > startTimeInt;
  }

  bool get _valid =>
      _timezone != null &&
      _weekdays.isNotEmpty &&
      _from != null &&
      _to != null &&
      _compareTimes(_from!, _to!);

  int _timeOfDayToInt(TimeOfDay timeOfDay) {
    return Duration(
      days: 0,
      hours: timeOfDay.hour,
      minutes: timeOfDay.minute,
      seconds: 0
    ).inMilliseconds;
  }

  TimeOfDay _intToTimeOfDay(int value) {
    final duration = Duration(milliseconds: value);
    final minutes = duration.inMinutes - duration.inHours*60;
    return TimeOfDay(hour: duration.inHours, minute: minutes);
  }

  void _toggleWeekday(String day) {
    if (_finished) return;
    setState(() {
      if (_weekdays.contains(day)) {
        _weekdays = _weekdays.where((e) => e != day).toList();
      } else {
        _weekdays.add(day);
      }
    });
  }

  void _cancel() {
    if (_finished) return;
    _finished = true;
    Navigator.pop(context);
  }

  void _confirm() {
    if (_finished || !_valid) return;
    _finished = true;
    widget.onConfirm(
      EditBlockingSchedule(
        timezone: _timezone!,
        weekday: List.of(_weekdays),
        start: _timeOfDayToInt(_from!),
        end: _timeOfDayToInt(_to!)
      )
    );
    Navigator.pop(context);
  }

  Future<void> _pickTime({required bool start}) async {
    final l = AppLocalizations.of(context)!;
    // A window that ends at midnight would never validate, so an unset end
    // opens on the last minute of the day.
    final fallback = start
        ? const TimeOfDay(hour: 0, minute: 0)
        : const TimeOfDay(hour: 23, minute: 59);
    final picked = await showAppleTimeSheet(
      context,
      title: start ? l.selectStartTime : l.selectEndTime,
      initial: (start ? _from : _to) ?? fallback,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    // Insertion ordered, so the chips always read Monday to Sunday.
    final weekdays = <String, String>{
      "mon": l.monday,
      "tue": l.tuesday,
      "wed": l.wednesday,
      "thu": l.thursday,
      "fri": l.friday,
      "sat": l.saturday,
      "sun": l.sunday,
    };

    final validTimes = _from != null && _to != null
      ? _compareTimes(_from!, _to!)
      : null;

    // AdGuard Home stores whatever zone the server was set to, and a name this
    // database does not carry ("UTC" against "Etc/UTC") would leave the field
    // with no matching item, which the dropdown refuses to build.
    final zones = tz.timeZoneDatabase.locations.keys.toList();
    if (_timezone != null && !zones.contains(_timezone)) {
      zones.insert(0, _timezone!);
    }

    return AppleFormModal(
      title: widget.schedule != null ? l.editSchedule : l.newSchedule,
      icon: CupertinoIcons.clock,
      // Reached from a `showDialog`, on every width.
      dialog: true,
      maxWidth: 460,
      trailing: IconButton(
        onPressed: _finished ? null : _cancel,
        tooltip: l.close,
        icon: Icon(CupertinoIcons.xmark, size: 20, color: p.label2),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: DropdownButtonFormField<String>(
                      items: zones
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      initialValue: _timezone,
                      isExpanded: true,
                      style: AppleInput.style(context),
                      onChanged: _finished
                          ? null
                          : (value) => setState(() => _timezone = value),
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                      decoration: AppleInput.decoration(
                        context,
                        label: l.timezone,
                        icon: CupertinoIcons.globe,
                      ),
                    ),
                  ),
                  AppleGroupHeader(
                    title: l.pauseServiceBlocking,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 9),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final day in weekdays.entries)
                          AppleToggleChip(
                            label: day.value,
                            selected: _weekdays.contains(day.key),
                            onTap: () => _toggleWeekday(day.key),
                          ),
                      ],
                    ),
                  ),
                  AppleGroupHeader(
                    title: l.timeRange,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 9),
                  ),
                  AppleListSection(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      AppleListTile(
                        title: l.from,
                        value: _formatTime(_from),
                        // Each line raises a time picker over this sheet, so
                        // neither owns a disclosure.
                        showChevron: false,
                        onTap: _finished ? null : () => _pickTime(start: true),
                      ),
                      AppleListTile(
                        title: l.to,
                        value: _formatTime(_to),
                        showChevron: false,
                        onTap: _finished ? null : () => _pickTime(start: false),
                      ),
                    ],
                  ),
                  if (validTimes == false)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.exclamationmark_circle_fill,
                            size: 15,
                            color: p.red,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l.startTimeBeforeEndTime,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                color: p.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          AppleFormFooter(
            confirmLabel: l.confirm,
            cancelLabel: l.close,
            confirmEnabled: _valid && !_finished,
            cancelEnabled: !_finished,
            onConfirm: _confirm,
            onCancel: _cancel,
          ),
        ],
      ),
    );
  }
}

String _formatTime(TimeOfDay? time) {
  if (time == null) return "--:--";
  return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
}

/// iOS wheel for a time of day, in a sheet of its own so the schedule form keeps
/// its rows. Returns null when dismissed without confirming.
Future<TimeOfDay?> showAppleTimeSheet(
  BuildContext context, {
  required String title,
  required TimeOfDay initial,
}) {
  var draft = initial;

  return showModalBottomSheet<TimeOfDay>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (sheetContext) {
      final l = AppLocalizations.of(sheetContext)!;
      final p = ApplePalette.of(sheetContext);

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ColoredBox(
              color: p.chromeSolid,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: p.label,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          tooltip: l.close,
                          icon: Icon(
                            CupertinoIcons.xmark,
                            size: 20,
                            color: p.label2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 216,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      use24hFormat: true,
                      initialDateTime:
                          DateTime(2000, 1, 1, initial.hour, initial.minute),
                      onDateTimeChanged: (value) =>
                          draft = TimeOfDay(hour: value.hour, minute: value.minute),
                    ),
                  ),
                  AppleFormFooter(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    confirmLabel: l.confirm,
                    cancelLabel: l.cancel,
                    onCancel: () => Navigator.pop(sheetContext),
                    onConfirm: () => Navigator.pop(sheetContext, draft),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
