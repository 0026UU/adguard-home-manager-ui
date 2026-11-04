import 'package:flutter/cupertino.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/home/management_modal/management_modal.dart';

import 'package:adguard_home_manager/models/server_status.dart';

/// Grouped protection list shown at the top of the home screen.
class ServerStatusWidget extends StatelessWidget {
  final ServerStatus serverStatus;

  const ServerStatusWidget({
    super.key,
    required this.serverStatus,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    void openManagement() {
      showAppleSheet(
        context,
        title: AppLocalizations.of(context)!.allProtections,
        initialFraction: 0.65,
        body: const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ManagementModal(dialog: false),
        ),
      );
    }

    Widget row({
      required IconData icon,
      required Color iconColor,
      required String label,
      required bool enabled,
    }) {
      return AppleListTile(
        title: label,
        showChevron: false,
        leading: AppleIconBadge(icon: icon, color: iconColor),
        trailing: ApplePill(
          label: enabled
            ? AppLocalizations.of(context)!.enabled
            : AppLocalizations.of(context)!.disabled,
          color: enabled ? p.green : p.label3,
        ),
      );
    }

    return AppleListSection(
      title: AppLocalizations.of(context)!.serverStatus,
      headerTrailing: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: openManagement,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.allProtections,
                style: TextStyle(fontSize: 13, color: p.tint),
              ),
              const SizedBox(width: 3),
              Icon(CupertinoIcons.chevron_right, size: 11, color: p.tint),
            ],
          ),
        ),
      ),
      children: [
        row(
          icon: CupertinoIcons.line_horizontal_3_decrease,
          iconColor: p.indigo,
          label: AppLocalizations.of(context)!.ruleFilteringWidget,
          enabled: serverStatus.filteringEnabled,
        ),
        row(
          icon: CupertinoIcons.checkmark_shield,
          iconColor: p.green,
          label: AppLocalizations.of(context)!.safeBrowsingWidget,
          enabled: serverStatus.safeBrowsingEnabled,
        ),
        row(
          icon: CupertinoIcons.lock,
          iconColor: p.orange,
          label: AppLocalizations.of(context)!.parentalFilteringWidget,
          enabled: serverStatus.parentalControlEnabled,
        ),
        row(
          icon: CupertinoIcons.search,
          iconColor: p.tint,
          label: AppLocalizations.of(context)!.safeSearchWidget,
          enabled: serverStatus.safeSearchEnabled,
        ),
      ],
    );
  }
}
