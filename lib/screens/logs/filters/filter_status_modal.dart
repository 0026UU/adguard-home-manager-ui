import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/providers/logs_provider.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/custom_radio.dart';

/// Single-choice picker for the query-log response status.
///
/// The selection lives in [LogsProvider], so the rows read and write it there.
class FilterStatusModal extends StatefulWidget {
  final bool dialog;

  const FilterStatusModal({super.key, required this.dialog});

  @override
  State<FilterStatusModal> createState() => _FilterStatusModalState();
}

class _FilterStatusModalState extends State<FilterStatusModal> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final logsProvider = Provider.of<LogsProvider>(context);

    return AppleFormModal(
      title: l.responseStatus,
      icon: CupertinoIcons.shield,
      dialog: widget.dialog,
      trailing: widget.dialog
          ? AppleFormButton(
              label: l.close,
              background: Colors.transparent,
              foreground: p.tint,
              width: 74,
              onPressed: () => Navigator.pop(context),
            )
          : null,
      body: _ItemsList(
        selectedResultStatus: logsProvider.selectedResultStatus,
        updateSelectedResultStatus: (v) =>
            logsProvider.setSelectedResultStatus(value: v),
      ),
    );
  }
}

class _ItemsList extends StatelessWidget {
  final String selectedResultStatus;
  final void Function(String) updateSelectedResultStatus;

  const _ItemsList(
      {required this.selectedResultStatus,
      required this.updateSelectedResultStatus});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    final statuses = <_StatusOption>[
      _StatusOption("all", l.all, CupertinoIcons.list_bullet, p.label2),
      _StatusOption("filtered", l.filtered, CupertinoIcons.shield, p.tint),
      _StatusOption("processed", l.processedRow,
          CupertinoIcons.checkmark_shield, p.green),
      _StatusOption("whitelisted", l.processedWhitelistRow,
          CupertinoIcons.checkmark_circle_fill, p.green),
      _StatusOption("blocked", l.blocked, CupertinoIcons.nosign, p.red),
      _StatusOption("blocked_safebrowsing", l.blockedSafeBrowsingRow,
          CupertinoIcons.exclamationmark_triangle, p.red),
      _StatusOption("blocked_parental", l.blockedParentalRow,
          CupertinoIcons.lock_shield, p.red),
      _StatusOption("safe_search", l.blockedSafeSearchRow, CupertinoIcons.globe,
          p.orange),
    ];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: AppleListSection(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final status in statuses)
              AppleListTile(
                title: status.label,
                icon: status.icon,
                iconColor: status.color,
                showChevron: false,
                onTap: () => updateSelectedResultStatus(status.id),
                trailing: CustomRadio(
                  value: status.id,
                  groupValue: selectedResultStatus,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusOption {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const _StatusOption(this.id, this.label, this.icon, this.color);
}
