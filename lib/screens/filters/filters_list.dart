// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/filters/add_button.dart';
import 'package:adguard_home_manager/screens/filters/list_options_menu.dart';
import 'package:adguard_home_manager/screens/filters/toggle_list.dart';
import 'package:adguard_home_manager/widgets/tab_content_list.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/models/filtering.dart';

class FiltersList extends StatefulWidget {
  final LoadStatus loadStatus;
  final ScrollController scrollController;
  final List<Filter> data;
  final String type;
  final void Function(Filter, String) onOpenDetailsScreen;

  const FiltersList({
    super.key,
    required this.loadStatus,
    required this.scrollController,
    required this.data,
    required this.type,
    required this.onOpenDetailsScreen
  });

  @override
  State<FiltersList> createState() => _FiltersListState();
}

class _FiltersListState extends State<FiltersList> {
  late bool isVisible;

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
      final filter = widget.data[index];

      final tile = AppleListTile(
        title: filter.name,
        subtitle: "${intFormat(filter.rulesCount, Platform.localeName)} ${l.enabledRules}",
        trailing: AppleSwitch(
          value: filter.enabled == true,
          onChanged: () => toggleFilterList(
            context: context,
            list: filter,
            listType: widget.type,
          ),
        ),
        showChevron: false,
        onTap: () => widget.onOpenDetailsScreen(filter, widget.type),
      );

      return ListOptionsMenu(
        list: filter,
        listType: widget.type,
        child: Column(
          children: [
            tile,
            if (index != widget.data.length - 1)
              AppleSeparator(indent: tile.separatorIndent),
          ],
        ),
      );
    }

    return CustomTabContentList(
      insetCard: true,
      loadingGenerator: () => AppleLoading(label: l.loadingFilters), 
      itemsCount: widget.data.length, 
      contentWidget: row, 
      noData: Center(
        child: AppleEmptyState(
          icon: widget.type == 'blacklist'
            ? CupertinoIcons.nosign
            : CupertinoIcons.checkmark_shield,
          title: widget.type == 'blacklist' ? l.noBlackLists : l.noWhiteLists,
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
      fab: AddFiltersButton(
        type: widget.type,
        widget: (fn) => FloatingActionButton(
          onPressed: fn,
          backgroundColor: palette.tint,
          foregroundColor: Colors.white,
          child: const Icon(CupertinoIcons.plus),
        ),
      ),
      fabVisible: isVisible,
    );
  }
}
