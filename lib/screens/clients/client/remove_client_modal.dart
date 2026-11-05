import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/widgets/apple/apple.dart';

class RemoveClientModal extends StatelessWidget {
  final void Function() onConfirm;

  const RemoveClientModal({
    super.key,
    required this.onConfirm
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return AppleAlertDialog(
      title: localizations.removeClient,
      message: localizations.removeClientMessage,
      actions: [
        AppleSheetAction(label: localizations.cancel),
        AppleSheetAction(
          label: localizations.confirm,
          destructive: true,
          onTap: onConfirm,
        ),
      ],
    );
  }
}
