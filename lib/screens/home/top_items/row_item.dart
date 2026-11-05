import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/options_menu.dart';

import 'package:adguard_home_manager/models/menu_option.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';

/// One entry of a "top items" ranking on the home screen.
class RowItem extends StatelessWidget {
  final HomeTopItems type;
  final Color chartColor;
  final String domain;
  final String number;
  final bool clients;
  final bool showColor;
  final String? unit;
  final List<MenuOption> Function(dynamic) options;
  final void Function(dynamic)? onTapEntry;

  const RowItem({
    super.key,
    required this.type,
    required this.chartColor,
    required this.domain,
    required this.number,
    required this.clients,
    required this.showColor,
    required this.options,
    this.onTapEntry,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<StatusProvider>(context);

    String? name;
    if (clients == true) {
      try {
        name = statusProvider.serverStatus!.clients.firstWhere((c) => c.ids.contains(domain)).name;
      } catch (e) {
        // ---- //
      }
    }

    return Material(
      color: Colors.transparent,
      child: OptionsMenu(
        value: domain,
        options: options,
        onTap: onTapEntry,
        child: AppleListTile(
          title: domain,
          subtitle: name,
          subtitleMaxLines: 1,
          value: number,
          showChevron: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          leading: showColor
            ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: chartColor, shape: BoxShape.circle),
              )
            : const SizedBox(width: 0),
        ),
      ),
    );
  }
}

/// Aggregated "others" row shown under the top five entries.
class OthersRowItem extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool showColor;

  const OthersRowItem({
    super.key,
    required this.items,
    required this.showColor,
  });

  @override
  Widget build(BuildContext context) {
    if (items.length <= 5) {
      return const SizedBox();
    }

    final int rest = List<int>.from(
      items.sublist(5, items.length).map((e) => e.values.first.toInt())
    ).reduce((a, b) => a + b);

    return Material(
      color: Colors.transparent,
      child: AppleListTile(
        title: AppLocalizations.of(context)!.others,
        value: rest.toString(),
        showChevron: false,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        leading: showColor
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: ApplePalette.of(context).gray,
                shape: BoxShape.circle,
              ),
            )
          : const SizedBox(width: 0),
      ),
    );
  }
}
