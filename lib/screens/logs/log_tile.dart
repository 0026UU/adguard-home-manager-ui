import 'package:flutter/cupertino.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/functions/get_filtered_status.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/functions/format_time.dart';
import 'package:provider/provider.dart';

/// One entry of the query log, as the design layer draws it: the result as a
/// pill, the domain and the moment it was seen, then the device, the reason
/// the server gave and how long it took.
class LogTile extends StatelessWidget {
  final Log log;
  final int length;
  final int index;
  final bool? isLogSelected;
  final void Function(Log) onLogTap;
  final bool? useAlwaysNormalTile;
  final bool twoColumns;

  const LogTile({
    super.key,
    required this.log,
    required this.length,
    required this.index,
    this.isLogSelected,
    required this.onLogTap,
    this.useAlwaysNormalTile,
    required this.twoColumns,
  });

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final localizations = AppLocalizations.of(context)!;
    final palette = ApplePalette.of(context);

    // The name the server knows the device by, or the address the query came
    // from when there is no name.
    String logClient() {
      if (log.clientInfo != null && log.clientInfo!.name != "") {
        return log.clientInfo!.name;
      }
      else {
        return log.client;
      }
    }

    Widget statusPill() {
      // The row pill is a single line, so it has to ask for the single-line
      // label: the other variant carries a newline and was cut to "Blocked…",
      // which hid whether a query died on a blacklist or on filtering.
      final filter = getFilteredStatus(context, appConfigProvider, log.reason, true);
      final filtered = filter['filtered'];

      final Color color;
      if (log.reason.startsWith('Rewrite')) {
        color = palette.tint;
      }
      else if (filtered == true) {
        color = palette.red;
      }
      else if (filtered == false) {
        color = appConfigProvider.useThemeColorForStatus == true
          ? palette.tint
          : palette.green;
      }
      else {
        color = palette.label3;
      }

      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 170),
        child: ApplePill(
          label: filter['label'] as String,
          color: color,
          fontSize: 11,
        ),
      );
    }

    final tile = AppleLogRow(
      leading: statusPill(),
      title: log.question.name ?? localizations.notAvailable,
      time: convertTimestampLocalTimezone(log.time, 'HH:mm:ss'),
      details: [
        logClient(),
        if (log.reason != '') log.reason,
        if (log.elapsedMs != '')
          "${double.parse(log.elapsedMs).toStringAsFixed(2)} ms",
      ],
      selected: isLogSelected == true,
      onTap: () => onLogTap(log),
    );

    return Column(
      children: [
        tile,
        if (index != length - 1)
          const AppleSeparator(
            indent: AppleLogRow.separatorInset,
            endIndent: AppleLogRow.separatorInset,
          ),
      ],
    );
  }
}
