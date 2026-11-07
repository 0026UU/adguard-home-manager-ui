import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/settings/general_settings/top_items_list/show_hide_top_items_list.dart';

import 'package:adguard_home_manager/constants/enums.dart';

/// The sequence the dashboard shows its top lists in, dragged with the
/// three-line handle the design layer puts at the end of every row.
///
/// Only the lists the user switched on are here, because the setting the app
/// writes is one ordered list of what to show: an item that is not visible has
/// no position to change.
class ReorderableTopItemsHome extends StatefulWidget {
  final List<HomeTopItems> persistHomeTopItems;
  final void Function(List<HomeTopItems> value) setPersistHomeTopItems;

  const ReorderableTopItemsHome({
    super.key,
    required this.persistHomeTopItems,
    required this.setPersistHomeTopItems,
  });

  @override
  State<ReorderableTopItemsHome> createState() => _ReorderableTopItemsHomeState();
}

class _ReorderableTopItemsHomeState extends State<ReorderableTopItemsHome> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final items = widget.persistHomeTopItems;

    if (items.isEmpty) {
      return AppleEmptyState(
        icon: CupertinoIcons.line_horizontal_3,
        title: l.noElementsReorderMessage,
        color: p.label3,
      );
    }

    void move(int oldIndex, int newIndex) {
      final next = [...items];
      final moved = next.removeAt(oldIndex);
      next.insert(newIndex, moved);
      widget.setPersistHomeTopItems(next);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ColoredBox(
              color: p.card,
              child: ReorderableListView.builder(
                itemBuilder: (context, index) {
                  final tile = AppleListTile(
                    title: topItemTitle(l, items[index]),
                    icon: topItemIcon(items[index]),
                    iconColor: p.tint,
                    showChevron: false,
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Icon(
                          CupertinoIcons.line_horizontal_3,
                          color: p.label3,
                        ),
                      ),
                    ),
                  );

                  return Column(
                    key: ValueKey(items[index]),
                    children: [
                      tile,
                      if (index != items.length - 1)
                        AppleSeparator(indent: tile.separatorIndent),
                    ],
                  );
                },
                itemCount: items.length,
                scrollController: _scrollController,
                primary: false,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                buildDefaultDragHandles: false,
                onReorderItem: move,
              ),
            ),
          ),
        ),
        AppleCaption(
          l.topItemsReorderInfo,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        ),
      ],
    );
  }
}
