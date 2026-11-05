import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Cancel/confirm alert for a destructive or remote action.
class ConfirmActionModal extends StatelessWidget {
  final String title;
  final String message;
  final void Function() onConfirm;

  const ConfirmActionModal({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AppleAlertDialog(
      title: title,
      message: message,
      actions: [
        AppleSheetAction(label: l.cancel),
        AppleSheetAction(label: l.confirm, onTap: onConfirm),
      ],
    );
  }
}
