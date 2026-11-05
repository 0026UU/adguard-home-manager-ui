// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/widgets/options_menu.dart';
import 'package:adguard_home_manager/screens/filters/add_button.dart';
import 'package:adguard_home_manager/screens/filters/list_options_menu.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/models/menu_option.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/functions/copy_clipboard.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';

class FiltersTripleColumn extends StatelessWidget {
  final void Function(String) onRemoveCustomRule;
  final void Function(Filter, String) onOpenDetailsModal;

  const FiltersTripleColumn({
    super.key,
    required this.onRemoveCustomRule,
    required this.onOpenDetailsModal,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final filteringProvider = Provider.of<FilteringProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final palette = ApplePalette.of(context);

    Widget? ruleSubtitle(String rule) {
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

    /// Hairline between two panes, like a split view divider.
    Widget divider() => SizedBox(
      width: 0.5,
      child: ColoredBox(color: palette.separator),
    );

    /// Column header: section name plus its trailing actions.
    Widget paneHeader({
      required String title,
      required List<Widget> trailing,
    }) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: palette.label,
              ),
            ),
          ),
          ...trailing,
        ],
      ),
    );

    Widget paneActionButton({
      required VoidCallback? onPressed,
      required IconData icon,
      required String tooltip,
    }) => IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      color: palette.tint,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        highlightColor: palette.fill3,
      ),
    );

    AppleListTile listTile({
      required String title,
      required String subtitle,
      required bool enabled,
      required VoidCallback onTap,
    }) {      final statusColor = enabled
        ? (appConfigProvider.useThemeColorForStatus == true ? palette.tint : palette.green)
        : (appConfigProvider.useThemeColorForStatus == true ? palette.label3 : palette.red);

      return AppleListTile(
        title: title,
        subtitle: subtitle,
        trailing: ApplePill(
          label: enabled ? l.enabled : l.disabled,
          color: statusColor,
        ),
        showChevron: true,
        onTap: onTap,
      );
    }

    Widget listPane({
      required String title,
      required List<Filter> data,
      required String type,
      required String addTooltip,
    }) => Expanded(
      flex: 1,
      child: ColoredBox(
        color: palette.card,
        child: Column(
          children: [
            paneHeader(
              title: title,
              trailing: [
                AddFiltersButton(
                  type: type,
                  widget: (fn) => paneActionButton(
                    onPressed: fn,
                    icon: CupertinoIcons.plus,
                    tooltip: addTooltip,
                  ),
                )
              ],
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final filter = data[index];
                  final tile = listTile(
                    title: filter.name,
                    subtitle: "${intFormat(filter.rulesCount, Platform.localeName)} ${l.enabledRules}",
                    enabled: filter.enabled == true,
                    onTap: () => onOpenDetailsModal(filter, type),
                  );

                  return ListOptionsMenu(
                    list: filter,
                    listType: type,
                    child: Column(
                      children: [
                        tile,
                        if (index != data.length - 1)
                          AppleSeparator(indent: tile.separatorIndent),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: palette.card,
      appBar: AppleTopBar(
        title: l.filters,
        actions: [
          IconButton(
            onPressed: () async {
              final result = await filteringProvider.fetchFilters();
              if (result == false && context.mounted) {
                showSnackbar(
                  appConfigProvider: appConfigProvider,
                  label: l.errorLoadFilters, 
                  color: palette.red
                );
              }
            }, 
            icon: const Icon(CupertinoIcons.arrow_clockwise),
            tooltip: l.refresh,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          switch (filteringProvider.loadStatus) {
            case LoadStatus.loading:
              return AppleLoading(label: l.loadingFilters);

            case LoadStatus.loaded:
              return Row(
                children: [
                  listPane(
                    title: l.whitelists,
                    data: filteringProvider.filtering!.whitelistFilters,
                    type: 'whitelist',
                    addTooltip: l.addWhitelist,
                  ),
                  divider(),
                  listPane(
                    title: l.blacklists,
                    data: filteringProvider.filtering!.filters,
                    type: 'blacklist',
                    addTooltip: l.addBlacklist,
                  ),
                  divider(),
                  Expanded(
                    flex: 1,
                    child: ColoredBox(
                      color: palette.card,
                      child: Column(
                        children: [
                          paneHeader(
                            title: l.customRules,
                            trailing: [
                              AddFiltersButton(
                                type: 'edit_custom_rule', 
                                widget: (fn) => paneActionButton(
                                  onPressed: fn,
                                  icon: CupertinoIcons.pencil,
                                  tooltip: l.editCustomRules,
                                )
                              ),
                              const SizedBox(width: 4),
                              AddFiltersButton(
                                type: 'add_custom_rule', 
                                widget: (fn) => paneActionButton(
                                  onPressed: fn,
                                  icon: CupertinoIcons.plus,
                                  tooltip: l.addCustomRule,
                                )
                              ),
                            ],
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: filteringProvider.filtering!.userRules.length,
                              itemBuilder: (context, index) {
                                final rule = filteringProvider.filtering!.userRules[index];
                                final tile = AppleListTile(
                                  title: rule,
                                  subtitleWidget: ruleSubtitle(rule),
                                  showChevron: false,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                  trailing: IconButton(
                                    onPressed: () => onRemoveCustomRule(rule),
                                    icon: const Icon(CupertinoIcons.trash, size: 18),
                                    color: palette.red,
                                    tooltip: l.delete,
                                  ),
                                );

                                return OptionsMenu(
                                  options: (_) => [
                                    MenuOption(
                                      title: l.copyClipboard,
                                      icon: CupertinoIcons.doc_on_clipboard,
                                      action: () => copyToClipboard(
                                        value: rule,
                                        successMessage: l.copiedClipboard,
                                      )
                                    )
                                  ],
                                  child: Column(
                                    children: [
                                      tile,
                                      if (index != filteringProvider.filtering!.userRules.length - 1)
                                        AppleSeparator(indent: tile.separatorIndent),
                                    ],
                                  ),
                                );
                              },
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              );
              
            case LoadStatus.error:
              return Center(
                child: AppleEmptyState(
                  icon: CupertinoIcons.exclamationmark_triangle,
                  title: l.filtersNotLoaded,
                  color: palette.orange,
                ),
              );

            default:
              return const SizedBox();
          }
        },
      )
    );
  }
}
