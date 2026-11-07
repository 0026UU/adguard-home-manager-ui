import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/constants/languages.dart';

/// The language the app reads itself in, chosen from the settings hub.
///
/// iOS does not draw a radio list: the chosen row carries the checkmark and
/// every other row is a plain tap, which is also what the system picker does.
/// The write is the one the radio group performed — the same
/// [AppConfigProvider.setSelectedLanguage] with the same tag, including the
/// null that hands the choice back to the system.
class LanguageSettings extends StatelessWidget {
  const LanguageSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final width = MediaQuery.sizeOf(context).width;
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    final selected = appConfigProvider.selectedLanguage;

    // Nothing is drawn when a row is not the current one, so the column of
    // labels stays aligned instead of shifting by a glyph.
    Widget checkmark(bool isCurrent) => isCurrent
      ? Icon(CupertinoIcons.checkmark, size: 20, color: p.tint)
      : const SizedBox.shrink();

    return AppleScreen(
      title: l.language,
      leading: isDesktop(width)
        ? null
        : AppleBackButton(
            label: l.back,
            onPressed: () => Navigator.pop(context),
          ),
      slivers: [
        SliverToBoxAdapter(
          child: AppleListSection(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            footer: l.languageDescription,
            children: [
              AppleListTile(
                title: l.systemDefined,
                showChevron: false,
                trailing: checkmark(selected == null),
                onTap: () => appConfigProvider.setSelectedLanguage(null),
              ),
              for (final language in sortedAppLanguages)
                AppleListTile(
                  title: language.name,
                  showChevron: false,
                  trailing: checkmark(selected == language.tag),
                  onTap: () => appConfigProvider.setSelectedLanguage(
                    language.tag,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
