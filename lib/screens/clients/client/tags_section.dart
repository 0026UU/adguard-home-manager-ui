import 'package:flutter/cupertino.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/clients/client/client_screen_functions.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// The row that opens the tag sheet, carrying the current selection as its
/// value so the form shows what the device already wears.
class TagsSection extends StatelessWidget {
  final List<String> selectedTags;
  final void Function(List<String>) onTagsSelected;

  const TagsSection({
    super.key,
    required this.selectedTags,
    required this.onTagsSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    return AppleListTile(
      icon: CupertinoIcons.tag,
      iconColor: p.orange,
      title: l.selectTags,
      subtitle: selectedTags.isNotEmpty
          ? "${selectedTags.length} ${l.tagsSelected}"
          : l.noTagsSelected,
      // The tap opens a sheet over this page, not a page of its own, so no
      // disclosure: only a row that pushes a screen owns one.
      showChevron: false,
      onTap: () => openTagsModal(
        context: context,
        selectedTags: selectedTags,
        onSelectedTags: onTagsSelected,
      ),
    );
  }
}
