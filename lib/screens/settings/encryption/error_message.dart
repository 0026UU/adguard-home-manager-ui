import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Reads the error the server answered with, as an iOS alert.
class ErrorMessageEncryption extends StatelessWidget {
  final String errorMessage;

  const ErrorMessageEncryption({
    super.key,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AppleAlertDialog(
      title: l.error,
      message: errorMessage,
      actions: [
        AppleSheetAction(label: l.close),
      ],
    );
  }
}
