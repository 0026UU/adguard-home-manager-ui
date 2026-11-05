// ignore_for_file: use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/filters/add_button.dart';
import 'package:adguard_home_manager/screens/filters/modals/custom_rules/sort_rules.dart';
import 'package:adguard_home_manager/widgets/tab_content_list.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';

class CustomRulesList extends StatefulWidget {
  final LoadStatus loadStatus;
  final ScrollController scrollController;
  final List<String> data;
  final void Function(String) onRemoveCustomRule;

  const CustomRulesList({
    super.key,
    required this.loadStatus,
    required this.scrollController,
    required this.data,
    required this.onRemoveCustomRule
  });

  @override
  State<CustomRulesList> createState() => _CustomRulesListState();
}

class _CustomRulesListState extends State<CustomRulesList> {
  late bool isVisible;

  CustomRulesSorting _sortingMethod = CustomRulesSorting.topBottom;

  @override
  void initState(){
    super.initState();
    
    isVisible = true;
    widget.scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (widget.scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (mounted && isVisible == true) {
        setState(() => isVisible = false);
      }
    } 
    else {
      if (widget.scrollController.position.userScrollDirection == ScrollDirection.forward) {
        if (mounted && isVisible == false) {
          setState(() => isVisible = true);
        }
      }
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final filteringProvider = Provider.of<FilteringProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final palette = ApplePalette.of(context);

    final renderData = _sortingMethod == CustomRulesSorting.bottomTop ? widget.data.reversed.toList() : widget.data.toList();

    bool checkIfComment(String value) {
      final regex = RegExp(r'^(!|#).*$');
      if (regex.hasMatch(value)) {
        return true;
      }
      else {
        return false;
      }
    }

    Widget? generateSubtitle(String rule) {
      final allowRegex = RegExp(r'^@@.*$');
      final blockRegex = RegExp(r'^\|\|.*$');
      final commentRegex = RegExp(r'^(#|!).*$');

      if (allowRegex.hasMatch(rule)) {
        return ApplePill(label: l.allowed, color: palette.green);
      }
      else if (blockRegex.hasMatch(rule)) {
        return ApplePill(label: l.blocked, color: palette.red);
      }
      else if (commentRegex.hasMatch(rule)) {
        return ApplePill(label: l.comment, color: palette.label3);
      }
      else {
        return null;
      }
    }

    void showSortingMethodModal() {
      showDialog(
        context: context, 
        builder: (ctx) => SortCustomRulesModal(
          sortingMethod: _sortingMethod, 
          onSelect: (value) => setState(() => _sortingMethod = value),
        ),
      );
    }

    void refresh() async {
      final result = await filteringProvider.fetchFilters();
      if (result == false && mounted) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.errorLoadFilters, 
          color: palette.red
        );
      }
    }

    Widget row(int index) {
      final rule = renderData[index];
      final tile = AppleListTile(
        title: rule,
        subtitleWidget: generateSubtitle(rule),
        showChevron: false,
        // Commented rules are read-only, so they render as a secondary row.
        enabled: !checkIfComment(rule),
        mono: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        trailing: IconButton(
          onPressed: () => widget.onRemoveCustomRule(rule),
          icon: Icon(CupertinoIcons.trash, color: palette.red),
          splashRadius: 18,
          tooltip: l.delete,
        ),
      );

      return Column(
        children: [
          tile,
          if (index != renderData.length - 1)
            AppleSeparator(indent: tile.separatorIndent),
        ],
      );
    }

    return CustomTabContentList(
      insetCard: true,
      loadingGenerator: () => AppleLoading(label: l.loadingFilters), 
      itemsCount: renderData.length, 
      contentWidget: row, 
      noData: Center(
        child: AppleEmptyState(
          icon: CupertinoIcons.textformat,
          title: l.noCustomFilters,
          color: palette.label3,
          action: SizedBox(
            width: 180,
            child: AppleButton.secondary(
              label: l.refresh,
              icon: CupertinoIcons.arrow_2_circlepath,
              onPressed: refresh,
            ),
          ),
        ),
      ), 
      errorGenerator: () => Center(
        child: AppleEmptyState(
          icon: CupertinoIcons.exclamationmark_triangle,
          title: l.filtersNotLoaded,
          color: palette.orange,
        ),
      ), 
      loadStatus: widget.loadStatus, 
      onRefresh: () async => refresh(), 
      fab: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AppleFab(
            icon: CupertinoIcons.arrow_up_arrow_down,
            tooltip: l.sortingOptions,
            small: true,
            onPressed: showSortingMethodModal,
            palette: palette,
          ),
          const SizedBox(height: 12),
          AddFiltersButton(
            type: 'edit_custom_rule', 
            widget: (fn) => _AppleFab(
              icon: CupertinoIcons.pencil,
              tooltip: l.editCustomRules,
              small: true,
              onPressed: fn,
              palette: palette,
            ),
          ),
          const SizedBox(height: 12),
          AddFiltersButton(
            type: 'add_custom_rule',
            widget: (fn) => _AppleFab(
              icon: CupertinoIcons.plus,
              onPressed: fn,
              palette: palette,
            ),
          ),
        ],
      ),
      heightFabHidden: -180,
      fabVisible: isVisible,
    );
  }
}

/// Circular tinted button, matching the floating actions elsewhere in the app.
class _AppleFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool small;
  final String? tooltip;
  final ApplePalette palette;

  const _AppleFab({
    required this.icon,
    required this.palette,
    this.onPressed,
    this.small = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return small
      ? FloatingActionButton.small(
          heroTag: tooltip ?? icon.codePoint.toString(),
          onPressed: onPressed,
          tooltip: tooltip,
          backgroundColor: palette.tint,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          child: Icon(icon, size: 18),
        )
      : FloatingActionButton(
          heroTag: tooltip ?? icon.codePoint.toString(),
          onPressed: onPressed,
          tooltip: tooltip,
          backgroundColor: palette.tint,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          child: Icon(icon, size: 24),
        );
  }
}
