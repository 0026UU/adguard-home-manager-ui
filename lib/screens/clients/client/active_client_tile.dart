import 'package:flutter/cupertino.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/options_menu.dart';

import 'package:adguard_home_manager/models/menu_option.dart';
import 'package:adguard_home_manager/functions/copy_clipboard.dart';
import 'package:adguard_home_manager/models/clients.dart';

class ActiveClientTile extends StatelessWidget {
  final AutoClient client;
  final void Function(AutoClient) onTap;
  final bool splitView;
  final AutoClient? selectedClient;

  /// Trailing hairline; disabled for the last row of a list.
  final bool showSeparator;

  const ActiveClientTile({
    super.key,
    required this.client,
    required this.onTap,
    required this.splitView,
    this.selectedClient,
    this.showSeparator = true,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final palette = ApplePalette.of(context);

    final named = client.name != null && client.name!.isNotEmpty;
    final name = named ? client.name! : client.ip;

    final tile = AppleListTile(
      title: name,
      subtitle: named ? client.ip : null,
      value: client.source,
      leading: AppleAvatar(text: name, color: palette.seeded(name)),
      onTap: () => onTap(client),
      showChevron: !splitView,
      selected: splitView && client == selectedClient,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );

    return OptionsMenu(
      options: (_) => [
        MenuOption(
          icon: CupertinoIcons.doc_on_clipboard,
          title: localizations.copyClipboard, 
          action: () => copyToClipboard(
            value: name,
            successMessage: localizations.copiedClipboard,
          )
        )
      ],
      child: Column(
        children: [
          tile,
          if (showSeparator) AppleSeparator(indent: tile.separatorIndent),
        ],
      ),
    );
  }
}
