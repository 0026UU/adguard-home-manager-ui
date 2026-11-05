import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/functions/format_time.dart';
import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/models/app_log.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';

/// The failures the app wrote down while talking to the server. They live in
/// memory only, so the page is empty until something goes wrong.
class DiagnosticsLogScreen extends StatelessWidget {
  const DiagnosticsLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final width = MediaQuery.of(context).size.width;

    final logs = List<AppLog>.from(
      Provider.of<AppConfigProvider>(context).logs.reversed,
    );

    return AppleScreen(
      title: l.diagnosticsLog,
      subtitle: logs.isEmpty
        ? null
        : l.loadedRecords(intFormat(logs.length, Platform.localeName)),
      leading: isDesktop(width)
        ? null
        : AppleBackButton(
            label: l.back,
            onPressed: () => Navigator.pop(context),
          ),
      slivers: [
        if (logs.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppleEmptyState(
              icon: CupertinoIcons.checkmark_seal,
              title: l.noDiagnosticsLog,
              color: p.label3,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(top: 10),
            sliver: SliverList.list(
              children: [
                AppleListSection(
                  children: [
                    for (final log in logs)
                      AppleListTile(
                        title: log.message,
                        subtitleMaxLines: 3,
                        subtitle:
                            '${log.type} · ${convertTimestampLocalTimezone(log.dateTime, 'HH:mm:ss')}',
                        value: log.statusCode,
                        showChevron: false,
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
