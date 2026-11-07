import 'package:flutter/cupertino.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/clients/client/client_screen_functions.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// The services group: whether the device follows the server, and the row
/// that opens the picker when it does not.
class BlockedServicesSection extends StatelessWidget {
  final bool useGlobalSettingsServices;
  final List<String> blockedServices;
  final void Function(List<String>) onUpdatedBlockedServices;
  final void Function(bool) onUpdateServicesGlobalSettings;

  const BlockedServicesSection({
    super.key,
    required this.useGlobalSettingsServices,
    required this.blockedServices,
    required this.onUpdatedBlockedServices,
    required this.onUpdateServicesGlobalSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    return AppleListSection(
      title: l.blockedServices,
      margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      children: [
        AppleSwitchListTile(
          icon: CupertinoIcons.checkmark_alt,
          iconColor: p.tint,
          title: l.useGlobalSettings,
          subtitle: l.useGlobalSettingsHelper,
          value: useGlobalSettingsServices,
          onChanged: onUpdateServicesGlobalSettings,
        ),
        AppleListTile(
          icon: CupertinoIcons.globe,
          iconColor: useGlobalSettingsServices ? p.label3 : p.red,
          title: l.selectBlockedServices,
          subtitle: useGlobalSettingsServices
              ? l.servicesSameAsServer
              : blockedServices.isNotEmpty
                  ? l.blockedServicesCount(blockedServices.length)
                  : l.noBlockedServicesSelected,
          enabled: !useGlobalSettingsServices,
          // Opens the services sheet, never a screen of its own.
          showChevron: false,
          onTap: useGlobalSettingsServices
              ? null
              : () => openServicesModal(
                    context: context,
                    blockedServices: blockedServices,
                    onUpdateBlockedServices: onUpdatedBlockedServices,
                  ),
        ),
      ],
    );
  }
}
