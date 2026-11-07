import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/models/filtering.dart';

class EnableDisableSelectionModal extends StatefulWidget {
  final List<Filter> selectedWhitelists;
  final List<Filter> selectedBlacklists;
  final void Function() onDelete;

  const EnableDisableSelectionModal({
    super.key,
    required this.selectedBlacklists,
    required this.selectedWhitelists,
    required this.onDelete,
  });

  @override
  State<EnableDisableSelectionModal> createState() => _EnableDisableSelectionModalState();
}

class _EnableDisableSelectionModalState extends State<EnableDisableSelectionModal> {
  bool _whitelistExpanded = true;
  bool _blacklistExpanded = true;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    // One group per kind of list: the header toggles the names underneath,
    // as the expansion panels did, and each name carries what the confirm
    // will do to it.
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "• ${list.name}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: p.label),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      list.enabled == true ? l.disable : l.enable,
                      style: TextStyle(
                        fontSize: 14,
                        color: list.enabled == true ? p.red : p.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      );
    }

    return AppleFormModal(
      title: l.enableDisableSelected,
      dialog: true,
      maxWidth: 500,
      icon: CupertinoIcons.shield_slash,
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
          ),
        ],
      ),
    );
  }
}
