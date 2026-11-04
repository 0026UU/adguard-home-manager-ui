import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:expandable/expandable.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/functions/format_time.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

class MainSwitch extends StatelessWidget {
  final ExpandableController expandableController;
  final void Function({ required bool value, required String filter }) updateBlocking;
  final void Function(int) disableWithCountdown;
  final Animation<double> animation;

  const MainSwitch({
    super.key,
    required this.expandableController,
    required this.updateBlocking,
    required this.disableWithCountdown,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<StatusProvider>(context);

    final p = ApplePalette.of(context);
    final bool generalOn = statusProvider.serverStatus!.generalEnabled == true;

    return Padding(
      padding: EdgeInsets.zero,
      child: ExpandableNotifier(
        controller: expandableController,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: statusProvider.serverStatus!.generalEnabled == true && !statusProvider.protectionsManagementProcess.contains('general')
              ? () => expandableController.toggle()
              : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: generalOn
                  ? AppleColors.green(p.b).withValues(alpha: 0.14)
                  : AppleColors.red(p.b).withValues(alpha: 0.12),
              ),
              child: Expandable(
                theme: const ExpandableThemeData(
                  animationDuration: Duration(milliseconds: 200),
                  fadeCurve: Curves.ease
                ),
                collapsed: _TopRow(
                  legacyMode: false,
                  expandableController: expandableController,
                  updateBlocking: updateBlocking,
                  animation: animation,
                ), 
                expanded: Column(
                  children: [
                    _TopRow(
                      legacyMode: false,
                      expandableController: expandableController,
                      updateBlocking: updateBlocking,
                      animation: animation,
                    ),
                    _BottomRow(
                      disableWithCountdown: disableWithCountdown,
                    ),
                    const SizedBox(height: 8)
                  ],
                )
              ),
            ),
          ),
        )
      ) 
    );
  }
}

class _TopRow extends StatelessWidget {
  final bool legacyMode;
  final ExpandableController expandableController;
  final void Function({ required bool value, required String filter }) updateBlocking;
  final Animation<double> animation;

  const _TopRow({
    required this.legacyMode,
    required this.expandableController,
    required this.updateBlocking,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<StatusProvider>(context);
    final p = ApplePalette.of(context);

    return  Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              RotationTransition(
                turns: animation,
                child: Icon(
                  CupertinoIcons.chevron_down,
                  size: 15,
                  color: statusProvider.serverStatus!.generalEnabled == true
                    ? p.label2
                    : p.label3,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.allProtections,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: p.label,
                      ),
                    ),
                    if (statusProvider.serverStatus!.timeGeneralDisabled > 0) ...[
                      const SizedBox(height: 2),
                      if (statusProvider.currentDeadline != null) Text(
                        "${AppLocalizations.of(context)!.remainingTime}: ${formatRemainingSeconds(statusProvider.remainingTime)}",
                        style: TextStyle(fontSize: 13, color: p.label2),
                      )
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        CupertinoSwitch(
          value: statusProvider.serverStatus!.generalEnabled,
          activeTrackColor: AppleColors.green(ApplePalette.brightnessOf(context)),
          onChanged: statusProvider.protectionsManagementProcess.contains('general') == false
            ? (value) {
              if (value == false && expandableController.expanded == true && legacyMode == false) {
                expandableController.toggle();
              }
              updateBlocking(
                value: value, 
                filter: 'general'
              );
            } : null,
        )
      ]
    );
  }
}

class _BottomRow extends StatefulWidget {
  final void Function(int) disableWithCountdown;
  
  const _BottomRow({
    required this.disableWithCountdown,
  });

  @override
  State<_BottomRow> createState() => _BottomRowState();
}

class _BottomRowState extends State<_BottomRow> {
  final _chipsScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<StatusProvider>(context);

    final textScale = MediaQuery.of(context).textScaler.scale(1);

    return Container(
      height: Platform.isMacOS || Platform.isLinux || Platform.isWindows 
        ? 50 * textScale
        : 40 * textScale,
      margin: const EdgeInsets.only(top: 8),
      child: Scrollbar(
        controller: _chipsScrollController,
        thumbVisibility: Platform.isMacOS || Platform.isLinux || Platform.isWindows,
        interactive: Platform.isMacOS || Platform.isLinux || Platform.isWindows,
        thickness: Platform.isMacOS || Platform.isLinux || Platform.isWindows ? 8 : 0,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: Platform.isMacOS || Platform.isLinux || Platform.isWindows ? 16 : 0
          ),
          child: ListView(
            controller: _chipsScrollController,
            scrollDirection: Axis.horizontal,
            children: [
              ActionChip(
                label: Text(AppLocalizations.of(context)!.seconds(30)),
                onPressed: statusProvider.protectionsManagementProcess.contains('general') == false && statusProvider.serverStatus!.generalEnabled == true
                  ? () => widget.disableWithCountdown(29000)
                  : null,
              ),
              const SizedBox(width: 8),
              ActionChip(
                label: Text(AppLocalizations.of(context)!.minute(1)),
                onPressed: statusProvider.protectionsManagementProcess.contains('general') == false && statusProvider.serverStatus!.generalEnabled == true
                  ? () => widget.disableWithCountdown(59000)
                  : null,
              ),
              const SizedBox(width: 8),
              ActionChip(
                label: Text(AppLocalizations.of(context)!.minutes(10)),
                onPressed: statusProvider.protectionsManagementProcess.contains('general') == false && statusProvider.serverStatus!.generalEnabled == true
                  ? () => widget.disableWithCountdown(599000)
                  : null,
              ),
              const SizedBox(width: 8),
              ActionChip(
                label: Text(AppLocalizations.of(context)!.hour(1)),
                onPressed: statusProvider.protectionsManagementProcess.contains('general') == false && statusProvider.serverStatus!.generalEnabled == true
                  ? () => widget.disableWithCountdown(3599000)
                  : null,
              ),
              const SizedBox(width: 8),
              ActionChip(
                label: Text(AppLocalizations.of(context)!.hours(24)),
                onPressed: statusProvider.protectionsManagementProcess.contains('general') == false && statusProvider.serverStatus!.generalEnabled == true
                  ? () => widget.disableWithCountdown(86399000)
                  : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}