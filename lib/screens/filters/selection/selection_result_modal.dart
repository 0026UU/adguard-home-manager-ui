import 'package:flutter/cupertino.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/models/filtering.dart';

enum SelectionResultMode { delete, enableDisable }

class SelectionResultModal extends StatelessWidget {
  final List<ProcessedList> results;
  final void Function() onClose;
  final SelectionResultMode mode;

  const SelectionResultModal({
    super.key, 
    required this.results,
    required this.onClose,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final failedItems = results.where((r) => r.successful == false).toList();

    return AppleFormModal(
      title: mode == SelectionResultMode.delete
        ? l.deletionResult
        : l.enableDisableResult,
      dialog: true,
      maxWidth: 500,
      icon: mode == SelectionResultMode.delete
        ? CupertinoIcons.trash
        : CupertinoIcons.shield_slash,
      iconColor: mode == SelectionResultMode.delete ? p.red : p.tint,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: failedItems.isEmpty
                ? Text(
                    mode == SelectionResultMode.delete
                      ? l.allSelectedListsDeletedSuccessfully
                      : l.selectedListsEnabledDisabledSuccessfully,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: p.label2),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, top: 4),
                        child: SizedBox(
                          width: double.infinity,
                          child: Text(
                            l.failedElements,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: p.label,
                            ),
                          ),
                        ),
                      ),
                      for (final item in failedItems)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            "• ${item.list.name}",
                            style: TextStyle(fontSize: 14, color: p.label),
                          ),
                        ),
                    ],
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: AppleButton(
              label: l.close,
              onPressed: () {
                Navigator.pop(context);
                onClose();
              },
            ),
          ),
        ],
      ),
    );
  }
}
