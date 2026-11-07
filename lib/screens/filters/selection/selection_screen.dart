import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/filters/selection/enable_disable_selection_modal.dart';
import 'package:adguard_home_manager/screens/filters/selection/delete_selection_modal.dart';
import 'package:adguard_home_manager/screens/filters/selection/selection_result_modal.dart';
import 'package:adguard_home_manager/screens/filters/selection/selection_lists.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';

enum ListType { blacklist, whitelist }

class SelectionScreen extends StatefulWidget {
  final bool isModal;

  const SelectionScreen({
    super.key,
    required this.isModal
  });

  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  List<Filter> _selectedWhitelists = [];
  List<Filter> _selectedBlacklists = [];

  /// The tab the segmented control shows: allowlists first, as the tabs did.
  int _tab = 0;

  void handleSelect(Filter list, ListType type) {
    if (type == ListType.blacklist) {
      final isContained = _selectedBlacklists.contains(list);
      if (isContained) {
        setState(() => _selectedBlacklists = _selectedBlacklists.where((l) => l != list).toList());
      }
      else {
        setState(() => _selectedBlacklists.add(list));
      }
    }
    else if (type == ListType.whitelist) {
      final isContained = _selectedWhitelists.contains(list);
      if (isContained) {
        setState(() => _selectedWhitelists = _selectedWhitelists.where((l) => l != list).toList());
      }
      else {
        setState(() => _selectedWhitelists.add(list));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final filteringProvider = Provider.of<FilteringProvider>(context);

    final somethingSelected = _selectedBlacklists.isNotEmpty || _selectedWhitelists.isNotEmpty;

    void enableDisableSelected() {
      showDialog(
        context: context, 
        builder: (ctx) => EnableDisableSelectionModal(
          selectedWhitelists: _selectedWhitelists,
          selectedBlacklists: _selectedBlacklists,
          onDelete: () async {
            Navigator.pop(context);
            final processModal = ProcessModal();
            processModal.open(l.processingLists);
            final result = await filteringProvider.enableDisableMultipleLists(
              blacklists: _selectedBlacklists, 
              whitelists: _selectedWhitelists
            );
            processModal.close();
            if (!context.mounted) return;
            showDialog(
              context: context, 
              builder: (ctx) => SelectionResultModal(
                mode: SelectionResultMode.enableDisable,
                results: result,
                onClose: () => Navigator.pop(context),
              ),
              barrierDismissible: false
            );
          },
        ),
        barrierDismissible: false
      );
    }

    void deleteSelected() {
      showDialog(
        context: context, 
        builder: (ctx) => DeleteSelectionModal(
          selectedWhitelists: _selectedWhitelists,
          selectedBlacklists: _selectedBlacklists,
          onDelete: () async {
            Navigator.pop(context);
            final processModal = ProcessModal();
            processModal.open(l.deletingLists);
            final result = await filteringProvider.deleteMultipleLists(
              blacklists: _selectedBlacklists, 
              whitelists: _selectedWhitelists
            );
            processModal.close();
            if (!context.mounted) return;
            showDialog(
              context: context, 
              builder: (ctx) => SelectionResultModal(
                mode: SelectionResultMode.delete,
                results: result,
                onClose: () => Navigator.pop(context),
              ),
              barrierDismissible: false
            );
          },
        ),
        barrierDismissible: false
      );
    }

    Widget closeButton() => IconButton(
      onPressed: () => Navigator.pop(context),
      icon: Icon(CupertinoIcons.xmark, size: 20, color: p.label2),
      tooltip: l.close,
    );

    List<Widget> batchActions() => [
      IconButton(
        onPressed: somethingSelected == true
          ? () => enableDisableSelected()
          : null, 
        icon: const Icon(CupertinoIcons.shield_slash),
        tooltip: l.enableDisableSelected,
      ),
      IconButton(
        onPressed: somethingSelected == true
          ? () => deleteSelected()
          : null, 
        icon: const Icon(CupertinoIcons.trash),
        tooltip: l.deleteSelectedLists,
      ),
    ];

    // The count each tab badge carried now rides in the segment label, so the
    // selection stays readable without a second glyph grammar.
    Widget segmented() => AppleSegmented(
      labels: [
        '${l.whitelists} (${_selectedWhitelists.length})',
        '${l.blacklists} (${_selectedBlacklists.length})',
      ],
      selectedIndex: _tab,
      onChanged: (index) => setState(() => _tab = index),
    );

    SelectionList list() => _tab == 0
      ? SelectionList(
          lists: filteringProvider.filtering!.whitelistFilters, 
          selectedLists: _selectedWhitelists, 
          onSelect: (list) => handleSelect(list, ListType.whitelist), 
          selectAll: () => setState(() => _selectedWhitelists = filteringProvider.filtering!.whitelistFilters), 
          unselectAll: () => setState(() => _selectedWhitelists = [])
        )
      : SelectionList(
          lists: filteringProvider.filtering!.filters, 
          selectedLists: _selectedBlacklists, 
          onSelect: (list) => handleSelect(list, ListType.blacklist), 
          selectAll: () => setState(() => _selectedBlacklists = filteringProvider.filtering!.filters), 
          unselectAll: () => setState(() => _selectedBlacklists = [])
        );

    SelectionSliverList sliverList() => _tab == 0
      ? SelectionSliverList(
          lists: filteringProvider.filtering!.whitelistFilters,
          selectedLists: _selectedWhitelists,
          onSelect: (list) => handleSelect(list, ListType.whitelist),
          selectAll: () => setState(() => _selectedWhitelists = filteringProvider.filtering!.whitelistFilters),
          unselectAll: () => setState(() => _selectedWhitelists = []),
        )
      : SelectionSliverList(
          lists: filteringProvider.filtering!.filters,
          selectedLists: _selectedBlacklists,
          onSelect: (list) => handleSelect(list, ListType.blacklist),
          selectAll: () => setState(() => _selectedBlacklists = filteringProvider.filtering!.filters),
          unselectAll: () => setState(() => _selectedBlacklists = []),
        );
    
    if (widget.isModal == true) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 500
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ColoredBox(
              color: p.chromeSolid,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: [
                        closeButton(),
                        Expanded(
                          child: Text(
                            l.selectionMode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: p.label,
                            ),
                          ),
                        ),
                        ...batchActions(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: segmented(),
                  ),
                  Expanded(child: list()),
                ],
              ),
            ),
          ),
        ),
      );
    }
    else {
      return AppleScreen(
        title: l.selectionMode,
        leading: closeButton(),
        actions: batchActions(),
        header: segmented(),
        slivers: sliverList().slivers(context),
      );
    }
  }
}
