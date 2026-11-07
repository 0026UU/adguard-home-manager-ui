import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/models/filtering.dart';

class DeleteSelectionModal extends StatefulWidget {
  final List<Filter> selectedWhitelists;
  final List<Filter> selectedBlacklists;
  final void Function() onDelete;

  const DeleteSelectionModal({
    super.key,
    required this.selectedBlacklists,
    required this.selectedWhitelists,
    required this.onDelete,
  });

  @override
  State<DeleteSelectionModal> createState() => _DeleteSelectionModalState();
}

class _DeleteSelectionModalState extends State<DeleteSelectionModal> {
  bool _whitelistExpanded = true;
  bool _blacklistExpanded = true;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    // One group per kind of list: the header toggles the names underneath,
    // as the expansion panels did.
    Widget group({
      required String title,
      required List<Filter> lists,
      required bool expanded,
      required VoidCallback onToggle,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: p.label,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                    size: 16,
                    color: p.label3,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            for (final list in lists)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  "• ${list.name}",
                  style: TextStyle(fontSize: 14, color: p.label),
                ),
              ),
        ],
      );
    }

    return AppleFormModal(
      title: l.deleteSelectedLists,
      dialog: true,
      maxWidth: 500,
      icon: CupertinoIcons.trash,
      iconColor: p.red,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.selectedWhitelists.isNotEmpty)
                    group(
                      title: l.whitelists,
                      lists: widget.selectedWhitelists,
                      expanded: _whitelistExpanded,
                      onToggle: () => setState(() => _whitelistExpanded = !_whitelistExpanded),
                    ),
                  if (widget.selectedWhitelists.isNotEmpty && widget.selectedBlacklists.isNotEmpty)
                    const SizedBox(height: 8),
                  if (widget.selectedBlacklists.isNotEmpty)
                    group(
                      title: l.blacklists,
                      lists: widget.selectedBlacklists,
                      expanded: _blacklistExpanded,
                      onToggle: () => setState(() => _blacklistExpanded = !_blacklistExpanded),
                    ),
                ],
              ),
            ),
          ),
          AppleFormFooter(
            confirmLabel: l.confirm,
            onConfirm: widget.onDelete,
            destructive: true,
          ),
        ],
      ),
    );
  }
}
