import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/widgets/apple/apple.dart';

class RemoveCustomRule extends StatelessWidget {
  final void Function() onConfirm;

  const RemoveCustomRule({
    super.key,
    required this.onConfirm
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AppleAlertDialog(
      title: l.removeCustomRule,
      message: l.removeCustomRuleMessage,
      actions: [
        AppleSheetAction(label: l.cancel),
        AppleSheetAction(label: l.confirm, destructive: true, onTap: onConfirm),
      ],
    );
  }
}
