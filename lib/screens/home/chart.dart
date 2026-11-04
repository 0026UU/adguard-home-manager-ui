import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/providers/app_config_provider.dart';

/// One statistic card of the home screen: a value, its share and an iOS-style
/// area chart. The card is a shortcut into the filtered query log.
class HomeChart extends StatelessWidget {
  final List<int> data;
  final String label;
  final String primaryValue;
  final String secondaryValue;
  final Color color;
  final int hoursInterval;
  final void Function() onTapTitle;
  final bool isDesktop;

  const HomeChart({
    super.key,
    required this.data,
    required this.label,
    required this.primaryValue,
    required this.secondaryValue,
    required this.color,
    required this.hoursInterval,
    required this.onTapTitle,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final p = ApplePalette.of(context);

    final bool isEmpty = data.every((i) => i == 0);

    if (appConfigProvider.hideZeroValues == true && isEmpty) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTapTitle,
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: p.label2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: 11,
                          color: p.label3,
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  secondaryValue,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              primaryValue,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                height: 1.1,
                color: p.label,
              ),
            ),
            const SizedBox(height: 8),
            isEmpty
              ? SizedBox(
                  height: 74,
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.noDataChart,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: p.label3),
                    ),
                  ),
                )
              : AppleAreaChart(
                  values: data.map((e) => e.toDouble()).toList(),
                  color: color,
                  height: 74,
                  gridLines: 2,
                ),
          ],
        ),
      ),
    );
  }
}
