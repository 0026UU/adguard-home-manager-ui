// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/screens/filters/modals/custom_rules/add_custom_rule.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// The rules one device carries of its own.
///
/// The server matches them before every list of its own, so an exception rule
/// written here whitelists a host for this device alone and a blocking rule
/// blocks a host the lists let through. Nothing is written until the confirm
/// below is pressed, the way the other sheets of the device form behave.
class ClientRulesModal extends StatefulWidget {
  final List<String> rules;
  final void Function(List<String>) onConfirm;

  const ClientRulesModal({
    super.key,
    required this.rules,
    required this.onConfirm,
  });

  @override
  State<ClientRulesModal> createState() => _ClientRulesModalState();
}

class _ClientRulesModalState extends State<ClientRulesModal> {
  late final List<String> _rules;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _rules = List<String>.of(widget.rules);
  }

  bool _isAllow(String rule) => rule.startsWith('@@');

  /// Opens the same rule builder the global list opens, so a rule is written
  /// the same way in both places.
  void _add() {
    if (_finished) return;

    final width = MediaQuery.of(context).size.width;

    showGeneralDialog(
      context: context,
      barrierColor: !(width > 700 || !(Platform.isAndroid || Platform.isIOS))
        ? Colors.transparent
        : Colors.black54,
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: const Offset(0, 0),
          ).animate(
            CurvedAnimation(parent: anim1, curve: Curves.easeInOutCubicEmphasized),
          ),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => AddCustomRule(
        fullScreen: !(width > 700 || !(Platform.isAndroid || Platform.isIOS)),
        onConfirm: _append,
      ),
    );
  }

  void _append(String rule) {
    if (_finished || !mounted) return;

    if (_rules.contains(rule)) {
      AppleToast.show(
        context,
        message: AppLocalizations.of(context)!.ruleAlreadyOnList,
        icon: CupertinoIcons.exclamationmark_circle,
      );
      return;
    }

    setState(() => _rules.add(rule));
  }

  void _remove(String rule) {
    if (_finished) return;
    setState(() => _rules.remove(rule));
  }

  void _cancel() {
    if (_finished) return;
    _finished = true;
    Navigator.pop(context);
  }

  void _confirm() {
    if (_finished) return;
    setState(() => _finished = true);
    // The caller gets its own list, including an empty one to remove every
    // rule of the device.
    widget.onConfirm(List<String>.of(_rules));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    Widget pill(String rule) {
      if (_isAllow(rule)) return ApplePill(label: l.allowed, color: p.green);
      if (rule.startsWith('!') || rule.startsWith('#')) {
        return ApplePill(label: l.comment, color: p.label3);
      }
      return ApplePill(label: l.blocked, color: p.red);
    }

    return AppleSheet(
      title: l.clientRules,
      leading: AppleIconBadge(icon: CupertinoIcons.textformat, color: p.tint),
      trailing: IconButton(
        onPressed: _finished ? null : _cancel,
        tooltip: l.close,
        icon: Icon(CupertinoIcons.xmark, size: 20, color: p.label2),
      ),
      actions: [
        AppleListTile(
          icon: CupertinoIcons.plus_circle,
          iconColor: p.green,
          title: l.addClientRule,
          showChevron: false,
          onTap: _finished ? null : _add,
        ),
      ],
      body: Material(
        color: Colors.transparent,
        child: AppleListSection(
          background: p.window,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          footer: l.clientRulesHelper,
          children: [
            if (_rules.isEmpty)
              AppleEmptyState(
                icon: CupertinoIcons.textformat,
                title: l.noClientRules,
              )
            else
              for (final rule in _rules)
                AppleListTile(
                  title: rule,
                  subtitleWidget: pill(rule),
                  mono: true,
                  showChevron: false,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  trailing: IconButton(
                    onPressed: _finished ? null : () => _remove(rule),
                    tooltip: l.delete,
                    splashRadius: 18,
                    icon: Icon(CupertinoIcons.trash, color: p.red),
                  ),
                ),
          ],
        ),
      ),
      footer: SafeArea(
        top: false,
        child: AppleFormFooter(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          confirmLabel: l.confirm,
          confirmEnabled: !_finished,
          cancelEnabled: !_finished,
          onConfirm: _confirm,
          onCancel: _cancel,
        ),
      ),
    );
  }
}
