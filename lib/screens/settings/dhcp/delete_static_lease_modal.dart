import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Confirms the removal of a manually created DHCP lease.
class DeleteStaticLeaseModal extends StatelessWidget {
  final void Function() onConfirm;

  const DeleteStaticLeaseModal({
    super.key,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AppleAlertDialog(
      title: l.deleteStaticLease,
      message: l.deleteStaticLeaseDescription,
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
