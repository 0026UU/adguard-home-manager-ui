import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Lets the user pick which identifier of an added client to filter the logs by.
class AddedClientIdSelectionModal extends StatefulWidget {
  final List<String> clientIds;
  final void Function(String) onConfirm;

  const AddedClientIdSelectionModal({
    super.key,
    required this.clientIds,
    required this.onConfirm,
  });

  @override
  State<AddedClientIdSelectionModal> createState() =>
      _AddedClientIdSelectionModalState();
}

class _AddedClientIdSelectionModalState
    extends State<AddedClientIdSelectionModal> {
  String _selectedId = "";

  @override
  void initState() {
    _selectedId = widget.clientIds.first;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    return AppleFormModal(
      title: l.selectIdToFilter,
      icon: CupertinoIcons.person,
      // Reached from a `showDialog`, like the alert it replaces.
      dialog: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: DropdownButtonFormField<String>(
                  items: widget.clientIds
                      .map((item) =>
                          DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  initialValue: widget.clientIds.first,
                  style: AppleInput.style(context),
                  onChanged: (value) => setState(() => _selectedId = value!),
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  dropdownColor: p.card,
                  decoration:
                      AppleInput.decoration(context, label: l.clientIds),
                ),
              ),
            ),
          ),
          AppleFormFooter(
            confirmLabel: l.confirm,
            onConfirm: () {
              Navigator.pop(context);
              widget.onConfirm(_selectedId);
            },
            cancelLabel: l.cancel,
          ),
        ],
      ),
    );
  }
}
