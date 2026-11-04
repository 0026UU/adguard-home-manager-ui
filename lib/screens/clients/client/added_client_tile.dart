import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/options_menu.dart';

import 'package:adguard_home_manager/models/menu_option.dart';
import 'package:adguard_home_manager/functions/copy_clipboard.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';

class AddedClientTile extends StatefulWidget {
  final Client client;
  final void Function(Client) onTap;
  final void Function(Client)? onEdit;
  final void Function(Client) onDelete;
  final Client? selectedClient;
  final bool? splitView;

  /// Trailing hairline; disabled for the last row of a list.
  final bool showSeparator;

  const AddedClientTile({
    super.key,
    required this.client,
    required this.onTap,
    this.onEdit,
    required this.onDelete,
    this.selectedClient,
    required this.splitView,
    this.showSeparator = true,
  });

  @override
  State<AddedClientTile> createState() => _AddedClientTileState();
}

class _AddedClientTileState extends State<AddedClientTile> {
  bool _isHover = false;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final palette = ApplePalette.of(context);

    final splitView = widget.splitView == true;
    final ids = widget.client.ids.toString().replaceAll(RegExp(r'^\[|\]$'), '');

    final tile = AppleListTile(
      title: widget.client.name,
      leading: AppleAvatar(
        text: widget.client.name,
        size: 40,
        color: palette.seeded(widget.client.name),
        gradientTo: palette.seededAlt(widget.client.name),
      ),
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ids,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          ClientStatusIcons(client: widget.client),
        ],
      ),
      onTap: () => widget.onTap(widget.client),
      showChevron: !splitView,
      selected: splitView && widget.client == widget.selectedClient,
      trailing: splitView && widget.onEdit != null && _isHover
        ? IconButton(
            onPressed: () => widget.onEdit!(widget.client), 
            icon: const Icon(CupertinoIcons.pencil, size: 20),
            tooltip: localizations.seeDetails,
          )
        : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leadingWidth: 40,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHover = true),
      onExit: (_) => setState(() => _isHover = false),
      child: OptionsMenu(
        options: (_) => [
          if (widget.onEdit != null) MenuOption(
            title: localizations.seeDetails,
            icon: CupertinoIcons.pencil,
            action: () => widget.onEdit!(widget.client)
          ),
          MenuOption(
            icon: CupertinoIcons.doc_on_clipboard,
            title: localizations.copyClipboard, 
            action: () => copyToClipboard(
              value: ids, 
              successMessage: localizations.copiedClipboard,
            )
          ),
        ],
        child: Column(
          children: [
            tile,
            if (widget.showSeparator) AppleSeparator(indent: tile.separatorIndent),
          ],
        ),
      ),
    );
  }
}

/// Filtering / safe browsing / parental / safe search state of a client.
class ClientStatusIcons extends StatelessWidget {
  final Client client;

  const ClientStatusIcons({
    super.key,
    required this.client,
  });

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final p = ApplePalette.of(context);

    Color colorFor(bool enabled) {
      if (appConfigProvider.useThemeColorForStatus == true) {
        return enabled ? p.tint : p.label3;
      }
      return enabled ? p.green : p.red;
    }

    Widget icon(IconData iconData, bool enabled) => Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Icon(
        iconData,
        size: 16,
        color: colorFor(enabled),
      ),
    );

    return Row(
      children: [
        icon(CupertinoIcons.line_horizontal_3_decrease, client.filteringEnabled),
        icon(CupertinoIcons.checkmark_shield, client.safebrowsingEnabled),
        icon(CupertinoIcons.lock, client.parentalEnabled),
        icon(
          CupertinoIcons.search,
          client.safeSearch != null && client.safeSearch!.enabled == true,
        ),
      ],
    );
  }
}
