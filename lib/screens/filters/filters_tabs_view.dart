import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/filters/custom_rules_list.dart';
import 'package:adguard_home_manager/screens/filters/filters_list.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';

class FiltersTabsView extends StatefulWidget {
  final AppConfigProvider appConfigProvider;
  final List<Widget> actions;
  final void Function(String) onRemoveCustomRule;
  final void Function(Filter, String) onOpenDetailsModal;

  const FiltersTabsView({
    super.key,
    required this.appConfigProvider,
    required this.actions,
    required this.onOpenDetailsModal,
    required this.onRemoveCustomRule
  });

  @override
  State<FiltersTabsView> createState() => _FiltersTabsViewState();
}

class _FiltersTabsViewState extends State<FiltersTabsView> with TickerProviderStateMixin {
  late TabController tabController;
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    tabController = TabController(
      initialIndex: widget.appConfigProvider.selectedFiltersTab,
      length: 3,
      vsync: this,
    );
    tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    widget.appConfigProvider.setSelectedFiltersTab(tabController.index);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    tabController.removeListener(_onTabChanged);
    tabController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  /// The line under the title, which describes whichever list the tabs show.
  String _subtitle(AppLocalizations l, Filtering filtering) {
    if (tabController.index == 2) {
      return "${filtering.userRules.length} ${l.customRules}";
    }

    final lists = tabController.index == 0
      ? filtering.whitelistFilters
      : filtering.filters;
    final rules = lists.fold<int>(
      0,
      (total, list) => total + list.rulesCount,
    );

    return "${lists.where((list) => list.enabled == true).length}"
        " / ${lists.length} ${l.filters} · "
        "${intFormat(rules, Platform.localeName)} ${l.enabledRules}";
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final filteringProvider = Provider.of<FilteringProvider>(context);
    final palette = ApplePalette.of(context);

    final loaded = filteringProvider.loadStatus == LoadStatus.loaded;

    return AppleScreen(
      title: l.filters,
      subtitle: loaded && filteringProvider.filtering != null
        ? _subtitle(l, filteringProvider.filtering!)
        : null,
      actions: widget.actions,
      scrollController: scrollController,
      header: AppleSegmented(
        labels: [l.whitelists, l.blacklists, l.customRules],
        selectedIndex: tabController.index,
        scrollable: true,
        onChanged: (index) => tabController.index = index,
      ),
      body: ColoredBox(
        color: palette.card,
        child: TabBarView(
          controller: tabController,
          children: [
            FiltersList(
              loadStatus: filteringProvider.loadStatus,
              scrollController: scrollController,
              type: 'whitelist',
              data: loaded
                ? filteringProvider.filtering!.whitelistFilters : [],
              onOpenDetailsScreen: widget.onOpenDetailsModal,
            ),
            FiltersList(
              loadStatus: filteringProvider.loadStatus,
              scrollController: scrollController,
              type: 'blacklist',
              data: loaded
                ? filteringProvider.filtering!.filters : [],
              onOpenDetailsScreen: widget.onOpenDetailsModal,
            ),
            CustomRulesList(
              loadStatus: filteringProvider.loadStatus,
              scrollController: scrollController,
              data: loaded
                ? filteringProvider.filtering!.userRules : [],
              onRemoveCustomRule: widget.onRemoveCustomRule,
            ),
          ]
        ),
      ),
    );
  }
}
