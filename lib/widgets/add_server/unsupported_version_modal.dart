import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/config/minimum_server_version.dart';
import 'package:adguard_home_manager/functions/compare_versions.dart';
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

    // A version that could not be read is measured against the release floor,
    // which is the one a user can actually upgrade to.
    final minimum = AghVersion.tryParse(serverVersion)?.isPreRelease ?? false
        ? MinimumServerVersion.beta
        : MinimumServerVersion.stable;

    return AppleAlertDialog(
      title: l.unsupportedServerVersion,
      message:
          "${l.unsupportedServerVersionMessage}\n\n${l.yourVersion(serverVersion.isEmpty ? l.unknownResult : serverVersion)}\n${l.minimumRequiredVersion(minimum)}",
      actions: [
        AppleSheetAction(label: l.close, onTap: onClose),
      ],
    );
  }
}
