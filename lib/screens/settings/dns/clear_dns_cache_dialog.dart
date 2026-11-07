import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Asks before the cache of the server is emptied, as an iOS alert.
class ClearDnsCacheDialog extends StatelessWidget {
  final void Function() onConfirm;

  const ClearDnsCacheDialog({
    super.key,
    required this.onConfirm
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AppleAlertDialog(
      title: l.clearDnsCache,
      message: l.clearDnsCacheMessage,
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
