import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/config/minimum_server_version.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

class UnsupportedVersionModal extends StatelessWidget {
  final String serverVersion;
  final void Function() onClose;

  const UnsupportedVersionModal({
    super.key,
    required this.serverVersion,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    final minimum = serverVersion.contains("b")
        ? MinimumServerVersion.beta
        : MinimumServerVersion.stable;

    return AppleAlertDialog(
      title: l.unsupportedServerVersion,
      message:
          "${l.unsupportedServerVersionMessage}\n\n${l.yourVersion(serverVersion)}\n${l.minimumRequiredVersion(minimum)}",
      actions: [
        AppleSheetAction(label: l.close, onTap: onClose),
      ],
    );
  }
}
