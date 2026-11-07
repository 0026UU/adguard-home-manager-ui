// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/filters/add_button.dart';
import 'package:adguard_home_manager/screens/filters/list_options_menu.dart';
import 'package:adguard_home_manager/screens/filters/toggle_list.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/format_time.dart';
import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/functions/update_blocking.dart';
import 'package:adguard_home_manager/models/blocked_services.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';

/// How many rule lines the preview card draws before pointing at the editor.
const int _previewLines = 12;

/// The filters page as one scrolling column: the protections, then the lists,
/// the custom rules with a preview of them, and the services.
///
/// The design layer draws these as sections of a single settings-like page;
/// the tabbed view it replaces split the same data over three screens.
class FiltersPage extends StatefulWidget {
  final List<Widget> actions;
  final void Function(Filter, String) onOpenDetailsModal;

  const FiltersPage({
    super.key,
    required this.actions,
    required this.onOpenDetailsModal,
  });

  @override
  State<FiltersPage> createState() => _FiltersPageState();
}

class _FiltersPageState extends State<FiltersPage> {
  @override
  void initState() {
    final filteringProvider = Provider.of<FilteringProvider>(context, listen: false);
    final serversProvider = Provider.of<ServersProvider>(context, listen: false);
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);

    // The service names live in their own endpoint, so the grid at the bottom
    // of the page needs a second request.
    if (serversProvider.apiClient2 != null &&
        filteringProvider.blockedServicesLoadStatus != LoadStatus.loaded) {
      filteringProvider.loadBlockedServices();
    }

    // The protection switches come from the status rather than the filtering
    // answer, so a tab opened before any other tab had read the status would
    // draw a Filters page with no protection group on it at all.
    if (serversProvider.apiClient2 != null &&
        statusProvider.serverStatus == null) {
      statusProvider.getServerStatus(withLoadingIndicator: false);
    }

    super.initState();
  }

  Future<void> _refresh() async {
    final filteringProvider = Provider.of<FilteringProvider>(context, listen: false);
    final serversProvider = Provider.of<ServersProvider>(context, listen: false);
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);

    await filteringProvider.fetchFilters();

    if (serversProvider.apiClient2 != null) {
      await filteringProvider.loadBlockedServices();
      // The protection switches at the top of this tab are drawn from the
      // status, not from the filtering answer, so a refresh that re-reads the
      // lists but not the status would leave four switches showing whatever
      // the last tab visit happened to record.
      await statusProvider.getServerStatus(withLoadingIndicator: false);
    }
  }

  /// Pauses or resumes the protection, in milliseconds like the API wants.
  Future<void> _pauseProtection(int? time) async {
    final busy = Provider.of<StatusProvider>(context, listen: false)
        .protectionsManagementProcess
        .contains('general');

    if (busy) return;

    await toggleProtection(
      context: context,
      filter: 'general',
      value: time == null,
      time: time,
    );
  }

  Future<void> _openPauseSheet(AppLocalizations l, bool protectionOn) async {
    final busy = Provider.of<StatusProvider>(context, listen: false)
        .protectionsManagementProcess
        .contains('general');

    final durations = <int, String>{
      29000: l.seconds(30),
      59000: l.minute(1),
      599000: l.minutes(10),
      3599000: l.hour(1),
      86399000: l.hours(24),
    };

    await showAppleActionSheet(
      context,
      title: l.pauseProtection,
      actions: [
        if (!protectionOn)
          AppleSheetAction(
            label: l.resumeProtection,
            icon: CupertinoIcons.play_fill,
            onTap: () => _pauseProtection(null),
          ),
        for (final entry in durations.entries)
          AppleSheetAction(
            label: entry.value,
            disabled: protectionOn ? busy : true,
            onTap: () => _pauseProtection(entry.key),
          ),
      ],
    );
  }

  /// True while a service write is on its way to the server.
  bool _servicesBusy = false;

  Future<void> _updateBlockedServices(List<String> values) async {
    if (_servicesBusy) return;

    final filteringProvider = Provider.of<FilteringProvider>(context, listen: false);
    final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);
    final l = AppLocalizations.of(context)!;
    final palette = ApplePalette.of(context);

    // Two taps in a row would post two different lists, and the slower answer
    // would win: one chip flips back under a toast that says it was saved.
    _servicesBusy = true;
    final result = await filteringProvider.updateBlockedServices(values);
    _servicesBusy = false;

    if (!mounted) return;

    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: result == true ? l.blockedServicesUpdated : l.blockedServicesNotUpdated,
      color: result == true ? palette.green : palette.red,
    );
  }

  /// The line under the title: what is actually working right now. Both kinds
  /// of list are on the page now, so both kinds count toward it.
  String _footnote(AppLocalizations l, Filtering filtering) {
    final enabled = [
      ...filtering.filters,
      ...filtering.whitelistFilters,
    ].where((list) => list.enabled == true).toList();

    final rules = enabled.fold<int>(0, (total, list) => total + list.rulesCount);

    return l.listsEnabledWithRules(enabled.length, rules);
  }

  List<Widget> _protectionChildren(
    AppLocalizations l,
    ApplePalette p,
    StatusProvider statusProvider,
  ) {
    final status = statusProvider.serverStatus!;
    final busy = statusProvider.protectionsManagementProcess;

    void switchProtection(String filter, bool value) {
      toggleProtection(context: context, filter: filter, value: value);
    }

    return [
      AppleSwitchListTile(
        title: l.ruleFiltering,
        subtitle: l.ruleFilteringHelper,
        value: status.filteringEnabled,
        icon: CupertinoIcons.slash_circle,
        iconColor: p.red,
        onChanged: busy.contains('filtering')
          ? null
          : (value) => switchProtection('filtering', value),
      ),
      AppleSwitchListTile(
        title: l.safeBrowsing,
        subtitle: l.safeBrowsingHelper,
        value: status.safeBrowsingEnabled,
        icon: CupertinoIcons.checkmark_shield,
        iconColor: p.green,
        onChanged: busy.contains('safeBrowsing')
          ? null
          : (value) => switchProtection('safeBrowsing', value),
      ),
      AppleSwitchListTile(
        title: l.safeSearch,
        subtitle: l.safeSearchHelper,
        value: status.safeSearchEnabled,
        icon: CupertinoIcons.eye_slash,
        iconColor: p.indigo,
        onChanged: busy.contains('safeSearch')
          ? null
          : (value) => switchProtection('safeSearch', value),
      ),
      AppleSwitchListTile(
        title: l.parentalFiltering,
        subtitle: l.parentalFilteringHelper,
        value: status.parentalControlEnabled,
        icon: CupertinoIcons.lock,
        iconColor: p.orange,
        onChanged: busy.contains('parentalControl')
          ? null
          : (value) => switchProtection('parentalControl', value),
      ),
      AppleListTile(
        title: l.pauseProtection,
        subtitle: status.generalEnabled
          ? l.pauseProtectionHelper
          : l.protectionPausedHelper,
        value: status.generalEnabled ? l.running : l.paused,
        valueColor: status.generalEnabled ? null : p.tint,
        icon: CupertinoIcons.pause_circle,
        iconColor: p.label3,
        // The row reports a state and opens the durations sheet, so the
        // disclosure stays away: only a row that pushes a screen owns one.
        showChevron: false,
        onTap: () => _openPauseSheet(l, status.generalEnabled),
      ),
    ];
  }

  List<Widget> _listGroup({
    required AppLocalizations l,
    required ApplePalette p,
    required String title,
    required String type,
    required List<Filter> lists,
  }) {
    Widget row(int index) {
      final filter = lists[index];

      final rules = l.rulesCount(
        filter.rulesCount,
        intFormat(filter.rulesCount, Platform.localeName),
      );
      final subtitle = filter.lastUpdated == null
        ? rules
        : '$rules · ${l.updatedOn(convertTimestampLocalTimezone(filter.lastUpdated!, 'yMMMd'))}';

      final tile = AppleListTile(
        title: filter.name,
        subtitle: subtitle,
        trailing: AppleSwitch(
          value: filter.enabled == true,
          onChanged: () => toggleFilterList(
            context: context,
            list: filter,
            listType: type,
          ),
        ),
        showChevron: false,
        onTap: () => widget.onOpenDetailsModal(filter, type),
      );

      return ListOptionsMenu(
        list: filter,
        listType: type,
        child: Column(
          children: [
            tile,
            if (index != lists.length - 1)
              AppleSeparator(indent: tile.separatorIndent),
          ],
        ),
      );
    }

    return [
      SliverToBoxAdapter(
        child: AppleGroupHeader(
          title: title,
          // The count is the quiet header meta the design layer uses; the add
          // action shares the trailing slot with it.
          trailingWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.filterListsCount(lists.length),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: p.label3,
                ),
              ),
              const SizedBox(width: 10),
              AddFiltersButton(
                type: type,
                widget: (onAdd) => AppleHeaderAction(
                  label: l.addList,
                  onPressed: onAdd,
                ),
              ),
            ],
          ),
        ),
      ),
      if (lists.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(
                color: p.card,
                child: AppleEmptyState(
                  icon: type == 'blacklist'
                    ? CupertinoIcons.slash_circle
                    : CupertinoIcons.checkmark_shield,
                  title: type == 'blacklist' ? l.noBlackLists : l.noWhiteLists,
                  color: p.label3,
                ),
              ),
            ),
          ),
        )
      else
        ...AppleListCard.slivers(
          context,
          itemsCount: lists.length,
          row: (index) => row(index),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 22)),
    ];
  }

  List<Widget> _rulesGroup(
    AppLocalizations l,
    ApplePalette p,
    Filtering filtering,
  ) {
    final rules = filtering.userRules;
    final preview = rules.take(_previewLines).toList();

    return [
      SliverToBoxAdapter(
        child: AppleListSection(
          title: l.customRules,
          margin: EdgeInsets.only(
            bottom: rules.isEmpty ? 0 : 14,
            left: 16,
            right: 16,
          ),
          children: [
            AddFiltersButton(
              type: 'edit_custom_rule',
              widget: (onEdit) => AppleListTile(
                title: l.editRules,
                subtitle: l.customRulesSyntaxHelper,
                value: l.rulesCount(
                  rules.length,
                  intFormat(rules.length, Platform.localeName),
                ),
                icon: CupertinoIcons.doc_text,
                iconColor: p.purple,
                onTap: onEdit,
              ),
            ),
          ],
        ),
      ),
      if (rules.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          sliver: SliverToBoxAdapter(
            child: AddFiltersButton(
              type: 'edit_custom_rule',
              widget: (onEdit) => _RulesPreviewCard(
                title: l.customRulesPreview,
                rules: preview,
                showAll: rules.length > _previewLines
                  ? l.showAllRules(
                      rules.length,
                      intFormat(rules.length, Platform.localeName),
                    )
                  : null,
                onShowAll: onEdit,
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _servicesGroup(
    AppLocalizations l,
    FilteringProvider filteringProvider,
    Filtering filtering,
  ) {
    final status = filteringProvider.blockedServicesLoadStatus;
    final services = filteringProvider.blockedServices?.services ?? const <BlockedService>[];
    final blocked = filtering.blockedServices;
    final p = ApplePalette.of(context);

    Widget content;

    if (status == LoadStatus.loaded && services.isNotEmpty) {
      content = LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 9) / 2;

          return Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final service in services)
                SizedBox(
                  width: width,
                  child: _ServiceChip(
                    name: service.name,
                    blocked: blocked.contains(service.id),
                    onTap: () {
                      final values = List<String>.from(blocked);

                      if (values.contains(service.id)) {
                        values.remove(service.id);
                      } else {
                        values.add(service.id);
                      }

                      _updateBlockedServices(values);
                    },
                  ),
                ),
            ],
          );
        },
      );
    } else if (status == LoadStatus.loading) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CupertinoActivityIndicator(radius: 12)),
      );
    } else {
      content = AppleEmptyState(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: l.blockedServicesListNotLoaded,
        // The service names live in an endpoint of their own, so nothing else
        // on the page can reach them: the card has to carry its own retry.
        action: AppleFormButton(
          label: l.refresh,
          background: p.tint,
          foreground: Colors.white,
          onPressed: () => Provider.of<FilteringProvider>(
            context,
            listen: false,
          ).loadBlockedServices(showLoading: true),
        ),
        color: p.orange,
      );
    }

    return [
      SliverToBoxAdapter(
        child: AppleGroupHeader(
          title: l.blockByService,
          trailingWidget: status == LoadStatus.loaded && blocked.isNotEmpty
            ? AppleHeaderAction(
                label: l.clearAll,
                destructive: true,
                // One tap here rewrites the whole list the server blocks, and
                // nothing else on the page puts it back, so the tap confirms
                // first like every other destructive control in the app.
                onPressed: () => showDialog(
                  context: context,
                  builder: (ctx) {
                    final dialogL = AppLocalizations.of(ctx)!;
                    return AppleAlertDialog(
                      title: dialogL.blockByService,
                      message: dialogL.clearBlockedServicesConfirm,
                      actions: [
                        AppleSheetAction(label: dialogL.cancel),
                        AppleSheetAction(
                          label: dialogL.clearAll,
                          color: ApplePalette.of(ctx).red,
                          destructive: true,
                          onTap: () => _updateBlockedServices(const []),
                        ),
                      ],
                    );
                  },
                ),
              )
            : null,
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        sliver: SliverToBoxAdapter(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ColoredBox(
              color: p.card,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: content,
              ),
            ),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final filteringProvider = Provider.of<FilteringProvider>(context);
    final statusProvider = Provider.of<StatusProvider>(context);
    final palette = ApplePalette.of(context);

    final filtering = filteringProvider.filtering;
    final loaded = filteringProvider.loadStatus == LoadStatus.loaded && filtering != null;

    final slivers = <Widget>[];

    if (loaded) {
      // A status the server has stopped confirming is not a status: these four
      // switches would go on offering to change what the app can no longer
      // read, in the state it last saw rather than the state it is in.
      if (statusProvider.serverStatus != null &&
          statusProvider.loadStatus != LoadStatus.error) {
        slivers.add(
          SliverToBoxAdapter(
            child: AppleListSection(
              title: l.protectionSwitches,
              children: _protectionChildren(l, palette, statusProvider),
            ),
          ),
        );
      }

      // Two sections, one per kind of list: the server keeps them apart under
      // `filters` and `whitelist_filters`, and every list of both has a row.
      slivers.addAll(
        _listGroup(
          l: l,
          p: palette,
          title: l.blacklists,
          type: 'blacklist',
          lists: filtering.filters,
        ),
      );

      slivers.addAll(
        _listGroup(
          l: l,
          p: palette,
          title: l.whitelists,
          type: 'whitelist',
          lists: filtering.whitelistFilters,
        ),
      );

      slivers.addAll(_rulesGroup(l, palette, filtering));
      slivers.addAll(_servicesGroup(l, filteringProvider, filtering));
    } else if (filteringProvider.loadStatus == LoadStatus.error) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppleEmptyState(
            icon: CupertinoIcons.exclamationmark_triangle,
            title: l.filtersNotLoaded,
            // The pull handle is gone with the lists it would have pulled, so
            // the retry has to live in the message itself or the tab is a
            // dead end until the user leaves it and comes back.
            action: AppleFormButton(
              label: l.refresh,
              background: palette.tint,
              foreground: Colors.white,
              onPressed: _refresh,
            ),
            color: palette.orange,
          ),
        ),
      );
    } else {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppleLoading(label: l.loadingFilters),
        ),
      );
    }

    return AppleScreen(
      title: l.filters,
      subtitle: loaded ? _footnote(l, filtering) : null,
      actions: widget.actions,
      onRefresh: _refresh,
      slivers: slivers,
    );
  }
}

/// The rule lines the server is keeping, coloured the way the design layer
/// reads them: comments in grey, exceptions in green, blocks in red.
class _RulesPreviewCard extends StatelessWidget {
  final String title;
  final List<String> rules;
  final String? showAll;
  final VoidCallback onShowAll;

  const _RulesPreviewCard({
    required this.title,
    required this.rules,
    required this.onShowAll,
    this.showAll,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    final lines = <InlineSpan>[];
    for (var i = 0; i < rules.length; i++) {
      if (i > 0) lines.add(const TextSpan(text: '\n'));

      final rule = rules[i];
      final color = rule.startsWith('!')
        ? p.label3
        : rule.startsWith('@@')
          ? p.green
          : p.red;

      lines.add(TextSpan(text: rule, style: TextStyle(color: color)));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: p.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.label2,
                  height: 1.25,
                ),
              ),
            ),
            const AppleSeparator(indent: 0, thickness: 0.5),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              child: Text.rich(
                TextSpan(
                  children: lines,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.7,
                  ),
                ),
                maxLines: _previewLines,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showAll != null) ...[
              const AppleSeparator(indent: 0, thickness: 0.5),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onShowAll,
                  child: SizedBox(
                    height: 42,
                    child: Center(
                      child: Text(
                        showAll!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: p.tint,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One service of the block-by-service grid: a capsule that turns red when the
/// service is blocked.
class _ServiceChip extends StatelessWidget {
  final String name;
  final bool blocked;
  final VoidCallback onTap;

  const _ServiceChip({
    required this.name,
    required this.blocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final color = blocked ? p.red : p.label2;

    return Material(
      color: blocked ? p.red.withValues(alpha: 0.13) : p.fill3,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.transparent,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Icon(CupertinoIcons.slash_circle, size: 21, color: color),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
