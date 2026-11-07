// ignore_for_file: use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/settings/access_settings/clients_list.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';

/// AdGuard Home's Settings - General - Access control, as one Apple screen.
///
/// The three lists the server answers `/access` with are mutually exclusive
/// for one identifier, so they are three segments of the same page rather
/// than three screens: the segment picks the list, [ClientsList] writes it.
class AccessSettings extends StatefulWidget {
  const AccessSettings({super.key});

  @override
  State<AccessSettings> createState() => _AccessSettingsState();
}

class _AccessSettingsState extends State<AccessSettings> {
  static const List<AccessSettingsList> _lists = [
    AccessSettingsList.allowed,
    AccessSettingsList.disallowed,
    AccessSettingsList.domains,
  ];

  AccessSettingsList _selected = AccessSettingsList.allowed;

  @override
  void initState() {
    Provider.of<ClientsProvider>(context, listen: false)
        .fetchClients(updateLoading: true);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final clientsProvider = Provider.of<ClientsProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final width = MediaQuery.of(context).size.width;
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    final blocked = clientsProvider.clients?.clientsAllowedBlocked;

    List<String> entries() {
      if (blocked == null) return const [];

      switch (_selected) {
        case AccessSettingsList.allowed:
          return blocked.allowedClients;
        case AccessSettingsList.disallowed:
          return blocked.disallowedClients;
        case AccessSettingsList.domains:
          return blocked.blockedHosts;
      }
    }

    // The lists are the server's, so a refresh that found nothing has to say
    // so: the rows still on screen are the ones from before the failure.
    Future<void> refresh() async {
      final result = await clientsProvider.fetchClients();
      if (result == false && context.mounted) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.clientsNotLoaded,
          color: p.red,
        );
      }
    }

    List<Widget> content() {
      if (clientsProvider.loadStatus == LoadStatus.loading) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppleLoading(label: l.loadingClients),
          ),
        ];
      }

      if (clientsProvider.loadStatus == LoadStatus.error || blocked == null) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppleEmptyState(
              icon: CupertinoIcons.exclamationmark_triangle,
              title: l.clientsNotLoaded,
              // The pull handle belongs to the list, and the list is what did
              // not arrive, so this card carries the retry itself.
              action: AppleButton(
                label: l.refresh,
                onPressed: refresh,
              ),
              color: p.red,
            ),
          ),
        ];
      }

      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ClientsList(
              type: _selected,
              data: entries(),
            ),
          ),
        ),
      ];
    }

    return AppleScreen(
      title: l.accessSettings,
      subtitle: l.accessSettingsDescription,
      leading: isDesktop(width)
          ? null
          : AppleBackButton(
              label: l.back,
              onPressed: () => Navigator.pop(context),
            ),
      header: AppleSegmented(
        labels: [l.allowedClients, l.disallowedClients, l.disallowedDomains],
        selectedIndex: _lists.indexOf(_selected),
        onChanged: (index) => setState(() => _selected = _lists[index]),
      ),
      onRefresh: refresh,
      slivers: content(),
    );
  }
}
