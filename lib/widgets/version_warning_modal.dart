import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

class VersionWarningModal extends StatelessWidget {
  final String version;

  const VersionWarningModal({
    super.key,
    required this.version,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AppleAlertDialog(
      title: l.unsupportedVersion,
      message: l.unsupprtedVersionMessage(version),
      actions: [
        AppleSheetAction(label: l.iUnderstand),
      ],
    );
  }
}
