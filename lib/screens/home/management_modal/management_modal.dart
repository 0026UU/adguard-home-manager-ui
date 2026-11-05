// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expandable/expandable.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/home/management_modal/main_switch.dart';
import 'package:adguard_home_manager/screens/home/management_modal/small_switch.dart';

import 'package:adguard_home_manager/functions/update_blocking.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

class ManagementModal extends StatefulWidget {
  final bool dialog;

  const ManagementModal({
    super.key,
    required this.dialog
  });

  @override
  State<ManagementModal> createState() => _ManagementModalState();
}

class _ManagementModalState extends State<ManagementModal> with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  late Animation<double> animation;
  final ExpandableController expandableController = ExpandableController();

  @override
  void initState() {
    expandableController.addListener(() async {
      await Future.delayed(const Duration(milliseconds: 200));
      if (expandableController.value == false) {
        animationController.animateTo(0);
      }
      else {
        animationController.animateBack(1);
      }
    });

    animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    )
    ..addListener(() => setState(() => {}));
    animation = Tween(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOut
    ));
    
    super.initState();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void updateBlocking({
      required bool value, 
      required String filter,
      int? time
    }) {
      toggleProtection(
        context: context,
        filter: filter,
        value: value,
        time: time,
      );
    }

    void disableWithCountdown(int time) async {
      updateBlocking(value: false, filter: 'general', time: time);
      expandableController.toggle();
    }

    if (widget.dialog == true) {
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 400
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: _Modal(
                    expandableController: expandableController,
                    updateBlocking: updateBlocking,
                    disableWithCountdown: disableWithCountdown,
                    animation: animation,
                  )
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context), 
                      child: Text(AppLocalizations.of(context)!.close),
                    ),
                  ],
                ),
              ),
              if (Platform.isIOS) const SizedBox(height: 16)
            ],
          ),
        ),
      );
    }
    // Inside an Apple sheet the chrome (grabber, title, dismiss) is already
    // provided, so only the content is returned here.
    return _Modal(
      expandableController: expandableController,
      updateBlocking: updateBlocking,
      disableWithCountdown: disableWithCountdown,
      animation: animation,
    );
  }
}

class _Modal extends StatelessWidget {
  final ExpandableController expandableController;
  final void Function({ required bool value, required String filter }) updateBlocking;
  final void Function(int) disableWithCountdown;
  final Animation<double> animation;

  const _Modal({
    required this.expandableController,
    required this.updateBlocking,
    required this.disableWithCountdown,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<StatusProvider>(context);

    final p = ApplePalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppleListSection(
          margin: const EdgeInsets.only(bottom: 12),
          background: Colors.transparent,
          children: [
            MainSwitch(
              expandableController: expandableController,
              updateBlocking: updateBlocking,
              disableWithCountdown: disableWithCountdown,
              animation: animation,
            ),
          ],
        ),
        AppleListSection(
          margin: EdgeInsets.zero,
          children: [
            SmallSwitch(
              label: AppLocalizations.of(context)!.ruleFiltering,
              icon: CupertinoIcons.line_horizontal_3_decrease,
              iconColor: p.indigo,
              value: statusProvider.serverStatus!.filteringEnabled,
              onChange: (value) => updateBlocking(value: value, filter: 'filtering'),
              disabled: statusProvider.protectionsManagementProcess.contains('filtering')
            ),
            SmallSwitch(
              label: AppLocalizations.of(context)!.safeBrowsing,
              icon: CupertinoIcons.checkmark_shield,
              iconColor: p.green,
              value: statusProvider.serverStatus!.safeBrowsingEnabled,
              onChange: (value) => updateBlocking(value: value, filter: 'safeBrowsing'),
              disabled: statusProvider.protectionsManagementProcess.contains('safeBrowsing')
            ),
            SmallSwitch(
              label: AppLocalizations.of(context)!.parentalFiltering,
              icon: CupertinoIcons.lock,
              iconColor: p.orange,
              value: statusProvider.serverStatus!.parentalControlEnabled,
              onChange: (value) => updateBlocking(value: value, filter: 'parentalControl'),
              disabled: statusProvider.protectionsManagementProcess.contains('parentalControl')
            ),
            SmallSwitch(
              label: AppLocalizations.of(context)!.safeSearch,
              icon: CupertinoIcons.search,
              iconColor: p.tint,
              value: statusProvider.serverStatus!.safeSearchEnabled,
              onChange: (value) => updateBlocking(value: value, filter: 'safeSearch'),
              disabled: statusProvider.protectionsManagementProcess.contains('safeSearch')
            ),
          ],
        ),
      ],
    );
  }
}
