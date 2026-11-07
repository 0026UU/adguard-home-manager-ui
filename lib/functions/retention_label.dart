import 'package:adguard_home_manager/l10n/app_localizations.dart';

/// How long something is kept, in the unit a person would say out loud.
///
/// The server answers in milliseconds and the retention picker already speaks
/// in days, so a raw "2160 hours" on a settings row is the same period the
/// picker offered as "90 days".
String retentionLabel(AppLocalizations l, int ms) {
  if (ms <= 0) return '';

  final duration = Duration(milliseconds: ms);

  // The picker's own choices first, so a row and the control that set it
  // agree on the name of the period.
  if (ms == Duration(hours: 24).inMilliseconds) return l.hours24;
  if (ms == Duration(days: 3).inMilliseconds) return l.days3;
  if (ms == Duration(days: 7).inMilliseconds) return l.days7;
  if (ms == Duration(days: 30).inMilliseconds) return l.days30;
  if (ms == Duration(days: 90).inMilliseconds) return l.days90;

  if (duration.inDays >= 1) return l.days(duration.inDays);
  if (duration.inHours >= 1) return l.hours(duration.inHours);

  return l.minutes(duration.inMinutes < 1 ? 1 : duration.inMinutes);
}
