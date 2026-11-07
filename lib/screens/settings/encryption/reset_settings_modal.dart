import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Asks before the encryption configuration is reset, as an iOS alert.
class ResetSettingsModal extends StatelessWidget {
  final void Function() onConfirm;

  const ResetSettingsModal({
    super.key,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AppleAlertDialog(
      title: l.resetSettings,
      message: l.resetEncryptionSettingsDescription,
      actions: [
        AppleSheetAction(label: l.cancel),
        AppleSheetAction(
          label: l.confirm,
          destructive: true,
          onTap: onConfirm,
        ),
      ],
    );
  }
}
