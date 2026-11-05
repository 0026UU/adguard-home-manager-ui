import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/clients/client/client_screen.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// The upstreams this device alone is resolved through. Left empty, the
/// server's own upstreams answer for it.
class UpstreamServersSection extends StatefulWidget {
  final List<ControllerListItem> upstreamServers;
  final void Function() onCheckValidValues;
  final void Function(List<ControllerListItem>) onUpdateUpstreamServers;

  const UpstreamServersSection({
    super.key,
    required this.upstreamServers,
    required this.onCheckValidValues,
    required this.onUpdateUpstreamServers,
  });

  @override
  State<UpstreamServersSection> createState() => _UpstreamServersSectionState();
}

class _UpstreamServersSectionState extends State<UpstreamServersSection> {
  final Uuid uuid = const Uuid();

  void _add() => widget.onUpdateUpstreamServers([
        ...widget.upstreamServers,
        ControllerListItem(
          id: uuid.v4(),
          controller: TextEditingController(),
        ),
      ]);

  void _remove(ControllerListItem item) => widget.onUpdateUpstreamServers(
        widget.upstreamServers
            .where((entry) => entry.id != item.id)
            .toList(),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final items = widget.upstreamServers;

    return AppleListSection(
      title: l.upstreamServers,
      headerTrailing: AppleHeaderAction(label: l.add, onPressed: _add),
      margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      children: [
        if (items.isEmpty)
          AppleEmptyState(
            icon: CupertinoIcons.link,
            title: l.noUpstreamServers,
            message: l.willBeUsedGeneralServers,
          )
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: AppleTextField(
                      label: l.serverAddress,
                      icon: CupertinoIcons.link,
                      controller: item.controller,
                      onChanged: (_) => widget.onCheckValidValues(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  IconButton(
                    tooltip: l.delete,
                    onPressed: () => _remove(item),
                    icon: Icon(CupertinoIcons.trash, size: 19, color: p.red),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
