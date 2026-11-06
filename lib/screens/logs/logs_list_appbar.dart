// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/logs/filters/logs_filters_modal.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';

class LogsListAppBar extends StatelessWidget {
  final bool innerBoxIsScrolled;

  /// Status line under the title, e.g. how long the server keeps its logs.
  final String? subtitle;

  /// Colour of the dot in front of [subtitle]. The live stream gets a green
  /// one, the stored query log gets the accent.
  final Color? subtitleDot;

  /// Asks the server for the rows again; this page brings its own scroll view,
  /// so the bar's refresh button cannot be added by [AppleScreen].
  final Future<void> Function()? onRefresh;

  const LogsListAppBar({
    super.key,
    required this.innerBoxIsScrolled,
    this.subtitle,
    this.subtitleDot,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final logsProvider = Provider.of<LogsProvider>(context);

    final width = MediaQuery.of(context).size.width;
    final localizations = AppLocalizations.of(context)!;
    final palette = ApplePalette.of(context);

    void openFilersModal() {
      if (width > 700 || !(Platform.isAndroid || Platform.isIOS)) {
        showDialog(
          context: context, 
          builder: (context) => const LogsFiltersModal(
            dialog: true,
          ),
          barrierDismissible: false
        );
      }
      else {
        showModalBottomSheet(
          context: context, 
          useRootNavigator: true,
          builder: (context) => const LogsFiltersModal(
            dialog: false,
          ),
          backgroundColor: Colors.transparent,
          isScrollControlled: true
        );
      }
    }

    final applied = logsProvider.appliedFilters;
    // The search lives in the field under the title now, so only the filters
    // that have no home of their own get a chip.
    final hasFilters = applied.statuses.isNotEmpty
      || applied.clients.isNotEmpty;

    return SliverAppBar.large(
      pinned: true,
      floating: true,
      centerTitle: true,
      titleSpacing: 20,
      forceElevated: innerBoxIsScrolled,
      title: Text(localizations.logs),
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      foregroundColor: palette.label,
      iconTheme: IconThemeData(color: palette.label),
      actionsIconTheme: IconThemeData(color: palette.tint),
      flexibleSpace: AppleLargeTitle(
        title: localizations.logs,
        subtitle: subtitle,
        subtitleDot: subtitle == null ? null : (subtitleDot ?? palette.tint),
        bottomHeight: hasFilters ? 46 : 0,
      ),
      actions: [
        if (onRefresh != null) AppleRefreshAction(onRefresh: onRefresh!),
        if (logsProvider.loadStatus == LoadStatus.loaded) IconButton(
          onPressed: openFilersModal,
          icon: const Icon(CupertinoIcons.slider_horizontal_3),
          tooltip: localizations.filters,
        ),
        const SizedBox(width: 8),
      ],
      bottom: hasFilters
        ? AppleHeaderBar(
            height: 46,
            padding: const EdgeInsets.fromLTRB(16, 2, 12, 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final status in applied.statuses)
                  AppleFilterChip(
                    color: logStatusColor(palette, status),
                    label: localizations.onlyStatus(
                      logStatusLabel(localizations, status),
                    ),
                    onDeleted: () => logsProvider.removeAppliedStatus(status),
                  ),
                if (applied.clients.isNotEmpty)
                  AppleFilterChip(
                    icon: CupertinoIcons.person_2,
                    label: applied.clients.length == 1
                      ? applied.clients[0]
                      : "${applied.clients.length} ${localizations.clients}",
                    onDeleted: () => logsProvider.removeAppliedClients(),
                  ),
              ],
            ),
          )
        : null,
    );
  }
}
