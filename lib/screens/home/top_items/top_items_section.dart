// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/home/top_items/row_item.dart';
import 'package:adguard_home_manager/screens/home/top_items/top_items_screen.dart';
import 'package:adguard_home_manager/widgets/custom_pie_chart.dart';

import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/models/menu_option.dart';
import 'package:adguard_home_manager/constants/enums.dart';

/// Ranking block of the home screen: a grouped list with a share bar on top.
class TopItemsSection extends StatelessWidget {
  final HomeTopItems type;
  final String label;
  final List<Map<String, dynamic>> data;
  final bool withChart;
  final bool withProgressBar;
  final String Function(dynamic) buildValue;
  final List<MenuOption> Function(dynamic) menuOptions;
  final void Function(dynamic)? onTapEntry;

  const TopItemsSection({
    super.key,
    required this.type,
    required this.label,
    required this.data,
    required this.withChart,
    required this.withProgressBar,
    required this.buildValue,
    required this.menuOptions,
    this.onTapEntry,
  });

  static const List<String> _palette = [
    'red', 'blue', 'green', 'orange', 'purple', 'indigo', 'teal', 'pink',
  ];

  Color _color(BuildContext context, int index) {
    final p = ApplePalette.of(context);
    switch (_palette[index % _palette.length]) {
      case 'red': return p.red;
      case 'blue': return p.tint;
      case 'green': return p.green;
      case 'orange': return p.orange;
      case 'purple': return p.purple;
      case 'indigo': return p.indigo;
      case 'teal': return p.teal;
      default: return p.pink;
    }
  }

  Map<String, double> _ringData(BuildContext context) {
    Map<String, double> values = {};
    data.sublist(0, data.length > 5 ? 5 : data.length).forEach((element) {
      values = {
        ...values,
        element.keys.first: element.values.first.toDouble()
      };
    });
    if (data.length > 5) {
      final int rest = List<int>.from(
        data.sublist(5, data.length).map((e) => e.values.first.toInt())
      ).reduce((a, b) => a + b);
      values = {
        ...values,
        AppLocalizations.of(context)!.others: rest.toDouble()
      };
    }
    return values;
  }

  List<Map<String, dynamic>> _lineData(BuildContext context) {
    List<Map<String, dynamic>> values = [];
    data.sublist(0, data.length > 5 ? 5 : data.length).forEach((element) {
      values.add({
        "label": element.keys.first,
        "value": element.values.first.toDouble()
      });
    });
    if (data.length > 5) {
      final int rest = List<int>.from(
        data.sublist(5, data.length).map((e) => e.values.first.toInt())
      ).reduce((a, b) => a + b);
      values.add({
        "label": AppLocalizations.of(context)!.others,
        "value": rest.toDouble()
      });
    }
    return values;
  }

  void _openAll(BuildContext context, double width) {
    final screen = TopItemsScreen(
      type: type,
      title: label,
      isClient: type == HomeTopItems.recurrentClients,
      data: data,
      withProgressBar: withProgressBar,
      buildValue: buildValue,
      options: menuOptions,
      onTapEntry: onTapEntry,
      isFullscreen: !(width > 700 || !(Platform.isAndroid || Platform.isIOS)),
    );

    if (width > 700) {
      showDialog(
        context: context,
        builder: (context) => screen,
      );
    }
    else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => screen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final p = ApplePalette.of(context);

    final bool showChart = type != HomeTopItems.avgUpstreamResponseTime;

    final lineChartData = _lineData(context);
    final mapData = lineChartData.map((e) => e["value"]);
    final double total = mapData.isNotEmpty
      ? mapData.reduce((a, b) => a + b)
      : 0;

    final rows = <Widget>[
      for (var i = 0; i < (data.length > 5 ? 5 : data.length); i++)
        RowItem(
          clients: type == HomeTopItems.recurrentClients,
          domain: data[i].keys.toList()[0],
          number: buildValue(data[i].values.toList()[0]),
          type: type,
          chartColor: _color(context, i),
          showColor: showChart,
          options: menuOptions,
          onTapEntry: onTapEntry,
        ),
      OthersRowItem(items: data, showColor: showChart),
    ];

    final list = AppleListSection(
      title: label,
      headerTrailing: data.length > 5
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openAll(context, width),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context)!.viewMore,
                    style: TextStyle(fontSize: 13, color: p.tint),
                  ),
                  const SizedBox(width: 3),
                  Icon(CupertinoIcons.chevron_right, size: 11, color: p.tint),
                ],
              ),
            ),
          )
        : null,
      children: data.isEmpty
        ? [
            AppleListTile(
              title: AppLocalizations.of(context)!.noDataThisSection,
              showChevron: false,
            ),
          ]
        : rows,
    );

    final shareBar = showChart && data.isNotEmpty && total > 0
      ? Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: lineChartData.asMap().entries.map((e) => Tooltip(
                    message: '${e.value["label"]} (${doubleFormat((e.value["value"]/total)*100, Platform.localeName)}%)',
                    child: Container(
                      width: constraints.maxWidth * (e.value["value"] / total),
                      color: _color(context, e.key),
                    ),
                  )).toList(),
                ),
              ),
            ),
          ),
        )
      : const SizedBox();

    if (width > 700 && showChart && data.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: AppleCard(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: CustomPieChart(
                      data: _ringData(context),
                      colors: [
                        for (var i = 0; i < lineChartData.length; i++) _color(context, i),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(flex: 2, child: Column(children: [shareBar, list])),
          ],
        ),
      );
    }

    return Column(children: [shareBar, list]);
  }
}
