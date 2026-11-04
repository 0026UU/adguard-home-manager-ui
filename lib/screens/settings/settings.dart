import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/settings/server_info/server_info.dart';
import 'package:adguard_home_manager/screens/settings/encryption/encryption.dart';
import 'package:adguard_home_manager/screens/settings/logs_settings/logs_settings.dart';
import 'package:adguard_home_manager/screens/settings/access_settings/access_settings.dart';
import 'package:adguard_home_manager/screens/settings/customization/customization.dart';
import 'package:adguard_home_manager/screens/settings/language/language_settings.dart';
import 'package:adguard_home_manager/screens/settings/dhcp/dhcp.dart';
import 'package:adguard_home_manager/screens/settings/statistics_settings/statistics_settings.dart';
import 'package:adguard_home_manager/screens/settings/safe_search_settings.dart';
import 'package:adguard_home_manager/screens/settings/update_server/update_screen.dart';
import 'package:adguard_home_manager/screens/settings/dns/dns.dart';
import 'package:adguard_home_manager/screens/settings/dns_rewrites/dns_rewrites.dart';
import 'package:adguard_home_manager/screens/servers/servers.dart';
import 'package:adguard_home_manager/screens/settings/advanced_setings.dart';
import 'package:adguard_home_manager/screens/settings/general_settings/general_settings.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/functions/open_url.dart';
import 'package:adguard_home_manager/functions/generate_color_translation.dart';
import 'package:adguard_home_manager/constants/colors.dart';
import 'package:adguard_home_manager/constants/urls.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';

final settingsNavigatorKey = GlobalKey<NavigatorState>();

class Settings extends StatelessWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            children: [
              const Expanded(
                  flex: 1,
                  child: _SettingsWidget(
                    twoColumns: true,
                  )),
              Expanded(
                flex: 2,
                child: Navigator(
                  key: settingsNavigatorKey,
                  onGenerateRoute: (settings) =>
                      MaterialPageRoute(builder: (ctx) => const SizedBox()),
                ),
              )
            ],
          );
        } else {
          return const _SettingsWidget(
            twoColumns: false,
          );
        }
      },
    );
  }
}

class _SettingsWidget extends StatefulWidget {
  final bool twoColumns;

  const _SettingsWidget({
    required this.twoColumns,
  });

  @override
  State<_SettingsWidget> createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<_SettingsWidget> {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    Provider.of<AppConfigProvider>(context, listen: false)
        .setSelectedSettingsScreen(screen: null);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final serversProvider = Provider.of<ServersProvider>(context);
    final statusProvider = Provider.of<StatusProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final palette = ApplePalette.of(context);

    if (!widget.twoColumns &&
        appConfigProvider.selectedSettingsScreen != null) {
      appConfigProvider.setSelectedSettingsScreen(screen: null);
    }

    /// Settings entries push on phones and replace the detail pane on wide
    /// layouts; the header card opens the same way as a row.
    void open({required int thisItem, required Widget screen}) {
      if (widget.twoColumns) {
        appConfigProvider.setSelectedSettingsScreen(
            screen: thisItem, notify: true);
        Navigator.of(settingsNavigatorKey.currentContext!).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) =>
                screen,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      } else {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (context) => screen));
      }
    }

    /// One settings section row: pushes on phones, selects in the master pane.
    Widget row({
      required int thisItem,
      required IconData icon,
      required Color iconColor,
      required String title,
      required String subtitle,
      required Widget screenToNavigate,
      Widget? trailing,
    }) {
      return AppleListTile(
        icon: icon,
        iconColor: iconColor,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        selected: widget.twoColumns &&
            appConfigProvider.selectedSettingsScreen == thisItem,
        showChevron: !widget.twoColumns,
        onTap: () => open(thisItem: thisItem, screen: screenToNavigate),
      );
    }

    final updateAvailable = serversProvider.updateAvailable.data != null;

    final appleStyle = appConfigProvider.useAppleStyle == true;

    /// The look of the app is kept on the first screen of the settings page,
    /// the way the design layer draws it, so the theme does not hide behind
    /// a sub-screen.
    Widget appearanceSection() {
      return AppleListSection(
        title: l.appearance,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.theme,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.25,
                    color: palette.label,
                  ),
                ),
                const SizedBox(height: 11),
                AppleSegmented(
                  height: 36,
                  labels: [l.autoTheme, l.light, l.dark],
                  selectedIndex: appConfigProvider.selectedThemeNumber,
                  onChanged: (value) =>
                      appConfigProvider.setSelectedTheme(value),
                ),
              ],
            ),
          ),
          AppleListTile(
            title: l.accentColor,
            showChevron: false,
            // The Apple theme keeps the system tint, so the swatches behind
            // this row only apply while the classic theme is on.
            value: appleStyle
                ? l.systemBlue
                : colorTranslation(context, appConfigProvider.staticColor),
            onTap: appleStyle
                ? null
                : () => showAppleActionSheet(
                      context,
                      title: l.accentColor,
                      actions: [
                        for (var i = 0; i < colors.length; i++)
                          AppleSheetAction(
                            label: colorTranslation(context, i),
                            color: colors[i],
                            icon: appConfigProvider.staticColor == i
                                ? CupertinoIcons.checkmark
                                : null,
                            onTap: () => appConfigProvider.setStaticColor(i),
                          ),
                      ],
                    ),
          ),
          AppleListTile(
            title: l.statusColors,
            showChevron: false,
            value: appConfigProvider.useThemeColorForStatus == true
                ? l.themeColorForStatus
                : l.semanticColors,
            onTap: () => showAppleActionSheet(
                  context,
                  title: l.statusColors,
                  actions: [
                    AppleSheetAction(
                      label: l.semanticColors,
                      icon: appConfigProvider.useThemeColorForStatus == false
                          ? CupertinoIcons.checkmark
                          : null,
                      onTap: () =>
                          appConfigProvider.setUseThemeColorForStatus(false),
                    ),
                    AppleSheetAction(
                      label: l.themeColorForStatus,
                      icon: appConfigProvider.useThemeColorForStatus == true
                          ? CupertinoIcons.checkmark
                          : null,
                      onTap: () =>
                          appConfigProvider.setUseThemeColorForStatus(true),
                    ),
                  ],
                ),
          ),
        ],
      );
    }

    final server = serversProvider.selectedServer;
    final serverStatus = statusProvider.serverStatus;
    final appInfo = appConfigProvider.getAppInfo;

    // The address is only shown when the user has not hidden it.
    final address = server == null || appConfigProvider.hideServerAddress == true
      ? null
      : "${server.connectionMethod}://${server.domain}"
            "${server.path ?? ""}${server.port != null ? ':${server.port}' : ""}";

    final details = [
      if (address != null) address,
      if (serverStatus != null) serverStatus.serverVersion,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' · ');

    final serverRows = <Widget>[
      row(
        thisItem: 0,
        icon: CupertinoIcons.search,
        iconColor: palette.indigo,
        title: l.safeSearch,
        subtitle: l.safeSearchSettings,
        screenToNavigate: const SafeSearchSettingsScreen(),
      ),
      row(
        thisItem: 1,
        icon: CupertinoIcons.list_bullet,
        iconColor: palette.teal,
        title: l.logsSettings,
        subtitle: l.logsSettingsDescription,
        screenToNavigate: const LogsSettings(),
      ),
      row(
        thisItem: 2,
        icon: CupertinoIcons.chart_bar,
        iconColor: palette.green,
        title: l.statisticsSettings,
        subtitle: l.statisticsSettingsDescription,
        screenToNavigate: const StatisticsSettings(),
      ),
      row(
        thisItem: 3,
        icon: CupertinoIcons.lock,
        iconColor: palette.orange,
        title: l.accessSettings,
        subtitle: l.accessSettingsDescription,
        screenToNavigate: const AccessSettings(),
      ),
      row(
        thisItem: 4,
        icon: CupertinoIcons.antenna_radiowaves_left_right,
        iconColor: palette.tint,
        title: l.dhcpSettings,
        subtitle: l.dhcpSettingsDescription,
        screenToNavigate: const DhcpScreen(),
      ),
      row(
        thisItem: 5,
        icon: CupertinoIcons.wifi,
        iconColor: palette.purple,
        title: l.dnsSettings,
        subtitle: l.dnsSettingsDescription,
        screenToNavigate: DnsSettings(
          splitView: widget.twoColumns,
        ),
      ),
      row(
        thisItem: 6,
        icon: CupertinoIcons.lock_shield,
        iconColor: palette.green,
        title: l.encryptionSettings,
        subtitle: l.encryptionSettingsDescription,
        screenToNavigate: const EncryptionSettings(),
      ),
      row(
        thisItem: 7,
        icon: CupertinoIcons.arrow_2_circlepath,
        iconColor: palette.tint,
        title: l.dnsRewrites,
        subtitle: l.dnsRewritesDescription,
        screenToNavigate: const DnsRewritesScreen(),
      ),
      if (updateAvailable)
        row(
          thisItem: 8,
          icon: CupertinoIcons.arrow_down_circle,
          iconColor: palette.red,
          title: l.updates,
          subtitle: l.updatesDescription,
          trailing: serversProvider.updateAvailable.data!.canAutoupdate == true
              ? Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: palette.red),
                )
              : null,
          screenToNavigate: const UpdateScreen(),
        ),
      row(
        thisItem: 9,
        icon: CupertinoIcons.info_circle,
        iconColor: palette.gray,
        title: l.serverInformation,
        subtitle: l.serverInformationDescription,
        screenToNavigate: const ServerInformation(),
      ),
    ];

    return ScaffoldMessenger(
        key: widget.twoColumns ? _scaffoldMessengerKey : null,
        child: AppleScreen(
          title: l.settings,
          subtitle: appInfo == null
            ? null
            : "${l.appVersion} ${appInfo.version} (${appInfo.buildNumber})",
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.only(top: 10),
              sliver: SliverList.list(
                children: [
                  if (server != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: AppleBigRow(
                        icon: Icons.dns_outlined,
                        color: palette.green,
                        colorTo: palette.teal,
                        title: server.name,
                        details: details.isEmpty ? null : details,
                        status: serverStatus != null ? l.connected : null,
                        actionLabel: l.servers,
                        onAction: () =>
                            open(thisItem: 12, screen: const Servers()),
                      ),
                    ),
                  appearanceSection(),
                  if (serversProvider.selectedServer != null &&
                      statusProvider.serverStatus != null &&
                      serversProvider.apiClient2 != null)
                    AppleListSection(
                        title: l.serverSettings, children: serverRows),
                  AppleListSection(
                    title: l.appSettings,
                    children: [
                      row(
                        thisItem: 10,
                        icon: CupertinoIcons.paintbrush,
                        iconColor: palette.pink,
                        title: l.customization,
                        subtitle: l.customizationDescription,
                        screenToNavigate: const Customization(),
                      ),
                      row(
                        thisItem: 11,
                        icon: CupertinoIcons.globe,
                        iconColor: palette.tint,
                        title: l.language,
                        subtitle: l.languageDescription,
                        screenToNavigate: const LanguageSettings(),
                      ),
                      row(
                        thisItem: 12,
                        icon: CupertinoIcons.desktopcomputer,
                        iconColor: palette.teal,
                        title: l.servers,
                        subtitle: serversProvider.selectedServer != null
                            ? statusProvider.serverStatus != null
                                ? "${l.connectedTo} ${serversProvider.selectedServer!.name}"
                                : "${l.selectedServer} ${serversProvider.selectedServer!.name}"
                            : l.noServerSelected,
                        screenToNavigate: const Servers(),
                      ),
                      row(
                        thisItem: 13,
                        icon: CupertinoIcons.gear,
                        iconColor: palette.gray,
                        title: l.generalSettings,
                        subtitle: l.generalSettingsDescription,
                        screenToNavigate:
                            GeneralSettings(splitView: widget.twoColumns),
                      ),
                      row(
                        thisItem: 14,
                        icon: CupertinoIcons.wrench,
                        iconColor: palette.gray,
                        title: l.advancedSettings,
                        subtitle: l.advancedSetupDescription,
                        screenToNavigate: const AdvancedSettings(),
                      ),
                    ],
                  ),
                  AppleListSection(
                    title: l.aboutApp,
                    children: [
                      AppleListTile(
                        title: l.appVersion,
                        value: appConfigProvider.getAppInfo?.version,
                        showChevron: false,
                      ),
                      AppleListTile(
                        title: l.applicationDetails,
                        subtitle: l.applicationDetailsDescription,
                        trailing: Icon(CupertinoIcons.arrow_up_right,
                            color: palette.label3),
                        onTap: () => openUrl(Urls.appDetailsWebpage),
                      ),
                      AppleListTile(
                        title: l.myOtherApps,
                        subtitle: l.myOtherAppsDescription,
                        trailing: Icon(CupertinoIcons.arrow_up_right,
                            color: palette.label3),
                        onTap: () => openUrl(Urls.jgeek00AppsWebpage),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ));
  }
}
