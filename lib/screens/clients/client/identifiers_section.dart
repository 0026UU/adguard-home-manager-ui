import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/clients/client/client_screen.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// The addresses a device is known by. Each one is a field of its own so a
/// client can carry an IP, a CIDR, a MAC and a ClientID at once.
class IdentifiersSection extends StatefulWidget {
  final List<ControllerListItem> identifiersControllers;
  final void Function(List<ControllerListItem>) onUpdateIdentifiersControllers;
  final void Function() onCheckValidValues;

  const IdentifiersSection({
    super.key,
    required this.identifiersControllers,
    required this.onUpdateIdentifiersControllers,
    required this.onCheckValidValues,
  });

  @override
  State<IdentifiersSection> createState() => _IdentifiersSectionState();
}

class _IdentifiersSectionState extends State<IdentifiersSection> {
  final Uuid uuid = const Uuid();

  void _add() => widget.onUpdateIdentifiersControllers([
        ...widget.identifiersControllers,
        ControllerListItem(
          id: uuid.v4(),
          controller: TextEditingController(),
        ),
      ]);

  void _remove(ControllerListItem item) =>
      widget.onUpdateIdentifiersControllers(
        widget.identifiersControllers
            .where((entry) => entry.id != item.id)
            .toList(),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final items = widget.identifiersControllers;

    return AppleListSection(
      title: l.identifiers,
      headerTrailing: AppleHeaderAction(label: l.add, onPressed: _add),
      margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      children: [
        if (items.isEmpty)
          AppleEmptyState(icon: CupertinoIcons.tag, title: l.noIdentifiers)
        else
          for (var index = 0; index < items.length; index++)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: AppleTextField(
                      label: l.identifier,
                      // One explanation is enough for the whole group.
                      helper: index == 0 ? l.identifierHelper : null,
                      icon: CupertinoIcons.tag,
                      controller: items[index].controller,
                      onChanged: (_) => widget.onCheckValidValues(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  IconButton(
                    tooltip: l.delete,
                    onPressed: () => _remove(items[index]),
                    icon: Icon(CupertinoIcons.trash, size: 19, color: p.red),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
