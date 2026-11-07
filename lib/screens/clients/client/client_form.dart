import 'package:flutter/cupertino.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/clients/client/blocked_services_section.dart';
import 'package:adguard_home_manager/screens/clients/client/client_screen.dart';
import 'package:adguard_home_manager/screens/clients/client/client_screen_functions.dart';
import 'package:adguard_home_manager/screens/clients/client/identifiers_section.dart';
import 'package:adguard_home_manager/screens/clients/client/settings_tile.dart';
import 'package:adguard_home_manager/screens/clients/client/tags_section.dart';
import 'package:adguard_home_manager/screens/clients/client/upstream_servers_section.dart';
import 'package:adguard_home_manager/screens/clients/client/blocking_schedule.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/models/safe_search.dart';

/// The add/edit form of one device, as an inset-grouped Apple form: the name
/// field, then a group per concern the server stores on the client entry.
class ClientForm extends StatelessWidget {
  final Client? client;
  final TextEditingController nameController;
  final List<ControllerListItem> identifiersControllers;
  final List<String> selectedTags;
  final bool useGlobalSettingsFiltering;
  final bool? enableFiltering;
  final bool? enableSafeBrowsing;
  final bool? enableParentalControl;
  final SafeSearch? safeSearch;
  final SafeSearch defaultSafeSearch;
  final bool useGlobalSettingsServices;
  final List<String> blockedServices;
  final void Function(List<String>) updateBlockedServices;
  final List<ControllerListItem> upstreamServers;
  final void Function(List<ControllerListItem>) updateUpstreamServers;
  final void Function(List<String>) updateSelectedTags;
  final void Function(List<ControllerListItem>) updateIdentifiersControllers;
  final void Function() enableDisableGlobalSettingsFiltering;
  final void Function(bool) updateEnableFiltering;
  final void Function(bool) updateEnableSafeBrowsing;
  final void Function(bool) updateEnableParentalControl;
  final void Function(SafeSearch) updateSafeSearch;
  final void Function(bool) updateUseGlobalSettingsServices;
  final bool ignoreClientQueryLog;
  final void Function(bool) updateIgnoreClientQueryLog;
  final bool ignoreClientStatistics;
  final void Function(bool) updateIgnoreClientStatistics;
  final bool enableDnsCache;
  final void Function(bool) updateEnableDnsCache;
  final TextEditingController dnsCacheField;
  final String? dnsCacheError;
  final void Function(String?) updateDnsCacheError;
  final BlockedServicesSchedule blockedServicesSchedule;
  final void Function(BlockedServicesSchedule) setBlockedServicesSchedule;

  const ClientForm({
    super.key,
    required this.client,
    required this.nameController,
    required this.identifiersControllers,
    required this.selectedTags,
    required this.useGlobalSettingsFiltering,
    required this.enableFiltering,
    required this.enableParentalControl,
    required this.enableSafeBrowsing,
    required this.safeSearch,
    required this.blockedServices,
    required this.updateBlockedServices,
    required this.upstreamServers,
    required this.updateUpstreamServers,
    required this.defaultSafeSearch,
    required this.useGlobalSettingsServices,
    required this.updateSelectedTags,
    required this.updateIdentifiersControllers,
    required this.enableDisableGlobalSettingsFiltering,
    required this.updateEnableFiltering,
    required this.updateEnableParentalControl,
    required this.updateEnableSafeBrowsing,
    required this.updateSafeSearch,
    required this.updateUseGlobalSettingsServices,
    required this.ignoreClientQueryLog,
    required this.ignoreClientStatistics,
    required this.updateIgnoreClientQueryLog,
    required this.updateIgnoreClientStatistics,
    required this.enableDnsCache,
    required this.updateEnableDnsCache,
    required this.dnsCacheField,
    required this.dnsCacheError,
    required this.updateDnsCacheError,
    required this.blockedServicesSchedule,
    required this.setBlockedServicesSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    return Column(
      children: [
        AppleTextField(
          label: l.name,
          icon: CupertinoIcons.person,
          controller: nameController,
          // The server keys a client by its name, so an edit keeps it read-only.
          enabled: client == null,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        ),
        AppleListSection(
          title: l.tags,
          margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          children: [
            TagsSection(
              selectedTags: selectedTags,
              onTagsSelected: updateSelectedTags,
            ),
          ],
        ),
        IdentifiersSection(
          identifiersControllers: identifiersControllers,
          onUpdateIdentifiersControllers: updateIdentifiersControllers,
          onCheckValidValues: () => {},
        ),
        AppleListSection(
          title: l.clientSettings,
          margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          children: [
            AppleSwitchListTile(
              icon: CupertinoIcons.checkmark_alt,
              iconColor: p.tint,
              title: l.useGlobalSettings,
              subtitle: l.useGlobalSettingsHelper,
              value: useGlobalSettingsFiltering,
              onChanged: (_) => enableDisableGlobalSettingsFiltering(),
            ),
            SettingsTile(
              label: l.enableFiltering,
              icon: CupertinoIcons.nosign,
              iconColor: p.red,
              value: enableFiltering,
              onChange: updateEnableFiltering,
              useGlobalSettingsFiltering: useGlobalSettingsFiltering,
            ),
            SettingsTile(
              label: l.enableSafeBrowsing,
              icon: CupertinoIcons.lock,
              iconColor: p.green,
              value: enableSafeBrowsing,
              onChange: updateEnableSafeBrowsing,
              useGlobalSettingsFiltering: useGlobalSettingsFiltering,
            ),
            SettingsTile(
              label: l.enableParentalControl,
              icon: CupertinoIcons.person_crop_square,
              iconColor: p.orange,
              value: enableParentalControl,
              onChange: updateEnableParentalControl,
              useGlobalSettingsFiltering: useGlobalSettingsFiltering,
            ),
            AppleListTile(
              icon: CupertinoIcons.search,
              iconColor: useGlobalSettingsFiltering ? p.label3 : p.tint,
              title: l.safeSearch,
              subtitle: useGlobalSettingsFiltering
                  ? null
                  : (safeSearch?.enabled ?? false)
                      ? l.enabled
                      : l.disabled,
              enabled: !useGlobalSettingsFiltering,
              // Opens the safe-search sheet, not a screen.
              showChevron: false,
              onTap: useGlobalSettingsFiltering
                  ? null
                  : () => openSafeSearchModal(
                        context: context,
                        defaultSafeSearch: defaultSafeSearch,
                        safeSearch: safeSearch,
                        onUpdateSafeSearch: updateSafeSearch,
                      ),
            ),
          ],
        ),
        AppleListSection(
          title: l.queryLogsAndStatistics,
          margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          children: [
            AppleSwitchListTile(
              title: l.ignoreClientQueryLog,
              value: ignoreClientQueryLog,
              onChanged: updateIgnoreClientQueryLog,
            ),
            AppleSwitchListTile(
              title: l.ignoreClientStatistics,
              value: ignoreClientStatistics,
              onChanged: updateIgnoreClientStatistics,
            ),
          ],
        ),
        BlockedServicesSection(
          useGlobalSettingsServices: useGlobalSettingsServices,
          blockedServices: blockedServices,
          onUpdatedBlockedServices: updateBlockedServices,
          onUpdateServicesGlobalSettings: updateUseGlobalSettingsServices,
        ),
        UpstreamServersSection(
          upstreamServers: upstreamServers,
          onCheckValidValues: () => {},
          onUpdateUpstreamServers: updateUpstreamServers,
        ),
        AppleListSection(
          title: l.upstreamDnsCacheConfiguration,
          margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          children: [
            AppleSwitchListTile(
              title: l.enableDnsCachingClient,
              value: enableDnsCache,
              onChanged: updateEnableDnsCache,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: AppleTextField(
                label: l.dnsCacheSize,
                icon: CupertinoIcons.number,
                controller: dnsCacheField,
                error: dnsCacheError,
                keyboardType: TextInputType.number,
                onChanged: (value) => updateDnsCacheError(
                  !validateNumber(value) ? l.invalidValue : null,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        BlockingSchedule(
          blockedServicesSchedule: blockedServicesSchedule,
          setBlockedServicesSchedule: setBlockedServicesSchedule,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
