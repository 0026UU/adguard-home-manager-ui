import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';

/// The list of one selection tab: a select-all row on its own card, then the
/// lists themselves, each with a trailing checkmark while it is selected.
class SelectionList extends StatelessWidget {
  final List<Filter> lists;
  final List<Filter> selectedLists;
  final void Function(Filter) onSelect;
  final void Function() selectAll;
  final void Function() unselectAll;

  const SelectionList({
    super.key,
    required this.lists,
    required this.selectedLists,
    required this.onSelect,
    required this.selectAll,
    required this.unselectAll,
  });

  bool get _allSelected =>
    lists.isNotEmpty && lists.length == selectedLists.length;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AppleListSection(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          children: [
            SelectionRow(
              title: l.selectAll,
              isSelected: _allSelected,
              onTap: () {
                if (_allSelected) {
                  unselectAll();
                } else {
                  selectAll();
                }
              },
            ),
          ],
        ),
        if (lists.isNotEmpty)
          AppleListSection(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final list in lists)
                SelectionFilterRow(
                  list: list,
                  isSelected: selectedLists.contains(list),
                  onSelect: onSelect,
                ),
            ],
          ),
      ],
    );
  }
}

/// The same list as slivers, for the screen that scrolls under a collapsing
/// large title.
class SelectionSliverList extends StatelessWidget {
  final List<Filter> lists;
  final List<Filter> selectedLists;
  final void Function(Filter) onSelect;
  final void Function() selectAll;
  final void Function() unselectAll;

  const SelectionSliverList({
    super.key,
    required this.lists,
    required this.selectedLists,
    required this.onSelect,
    required this.selectAll,
    required this.unselectAll,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: slivers(context));
  }

  List<Widget> slivers(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final allSelected =
      lists.isNotEmpty && lists.length == selectedLists.length;

    return [
      SliverToBoxAdapter(
        child: AppleListSection(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          children: [
            SelectionRow(
              title: l.selectAll,
              isSelected: allSelected,
              onTap: () {
                if (allSelected) {
                  unselectAll();
                } else {
                  selectAll();
                }
              },
            ),
          ],
        ),
      ),
      if (lists.isNotEmpty)
        ...AppleListCard.slivers(
          context,
          itemsCount: lists.length,
          row: (index) => SelectionFilterRow(
            list: lists[index],
            isSelected: selectedLists.contains(lists[index]),
            onSelect: onSelect,
          ),
        ),
      if (lists.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: AppleEmptyState(
              icon: CupertinoIcons.list_bullet,
              title: l.noItems,
            ),
          ),
        ),
    ];
  }
}

/// The trailing mark both kinds of row carry: a filled checkmark while the row
/// is selected, an empty circle otherwise, so the column stays aligned.
Widget selectionCheckmark(BuildContext context, bool isSelected) {
  final p = ApplePalette.of(context);

  return Icon(
    isSelected
      ? CupertinoIcons.checkmark_circle_fill
      : CupertinoIcons.circle,
    size: 22,
    color: isSelected ? p.tint : p.label4,
  );
}

/// One tappable row of the selection list.
class SelectionRow extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const SelectionRow({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppleListTile(
      title: title,
      showChevron: false,
      trailing: selectionCheckmark(context, isSelected),
      onTap: onTap,
    );
  }
}

/// One filter list of the selection: the URL and the state under the name.
class SelectionFilterRow extends StatelessWidget {
  final Filter list;
  final void Function(Filter) onSelect;
  final bool isSelected;

  const SelectionFilterRow({
    super.key,
    required this.list,
    required this.onSelect,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    // The colour of a list that does nothing is a statement of state, so it
    // comes from the palette unless the user asked the theme to carry it.
    final statusColor = list.enabled == true
      ? (appConfigProvider.useThemeColorForStatus == true
        ? p.tint
        : p.green)
      : (appConfigProvider.useThemeColorForStatus == true
        ? p.gray
        : p.red);

    return AppleListTile(
      title: list.name,
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            list.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          ApplePill(
            label: list.enabled == true ? l.enabled : l.disabled,
            color: statusColor,
          ),
        ],
      ),
      showChevron: false,
      selected: isSelected,
      trailing: selectionCheckmark(context, isSelected),
      onTap: () => onSelect(list),
    );
  }
}
