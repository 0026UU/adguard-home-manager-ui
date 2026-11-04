import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/settings/server_info/server_info.dart';
import 'package:adguard_home_manager/screens/settings/encryption/encryption.dart';
import 'package:adguard_home_manager/screens/settings/logs_settings/logs_settings.dart';
import 'package:adguard_home_manager/screens/settings/language/language_settings.dart';
import 'package:adguard_home_manager/screens/settings/dhcp/dhcp.dart';
import 'package:adguard_home_manager/screens/settings/statistics_settings/statistics_settings.dart';
import 'package:adguard_home_manager/screens/settings/update_server/update_screen.dart';
import 'package:adguard_home_manager/screens/settings/dns/dns.dart';
import 'package:adguard_home_manager/screens/settings/dns_rewrites/dns_rewrites.dart';
import 'package:adguard_home_manager/screens/settings/diagnostics/diagnostics_log_screen.dart';
import 'package:adguard_home_manager/screens/servers/servers.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/functions/generate_color_translation.dart';
import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/constants/colors.dart';
import 'package:adguard_home_manager/constants/languages.dart';
import 'package:adguard_home_manager/models/dhcp.dart';
import 'package:adguard_home_manager/models/querylog_config.dart';
import 'package:adguard_home_manager/models/rewrite_rules.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/services/api_client.dart';

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

  /// What the server says about itself, read once per connection: whether the
  /// query log is on and for how long, whether DHCP is serving and which pool
  /// it hands out, and how many DNS rewrites are written.
  QueryLogConfig? _queryLog;
  DhcpStatus? _dhcp;
  int? _rewrites;

  /// The licences Flutter registers while the app runs, so the number on the
  /// last group is the one the page below really lists.
  int? _licenses;

  String? _loadedFor;
  bool _savingQueryLog = false;
  bool _savingDhcp = false;

  @override
  void initState() {
    Provider.of<AppConfigProvider>(context, listen: false)
        .setSelectedSettingsScreen(screen: null);

    LicenseRegistry.licenses.toList().then((value) {
      if (mounted) setState(() => _licenses = value.length);
    });

    super.initState();
  }

  Future<void> loadServerValues(ApiClientV2 api, {required bool dhcpAvailable}) async {
    final queryLog = await api.getQueryLogInfo();
    final rewrites = await api.getDnsRewriteRules();
    DhcpStatus? dhcp;

    if (dhcpAvailable) {
      final result = await api.getDhcpData();
      if (result.successful == true) {
        dhcp = (result.content as DhcpModel).dhcpStatus;
      }
    }

    if (!mounted) return;

    setState(() {
      _queryLog = queryLog.successful == true
          ? queryLog.content as QueryLogConfig
          : null;
      _rewrites = rewrites.successful == true
          ? (rewrites.content as List<RewriteRules>).length
          : null;
      _dhcp = dhcp;
    });
  }

  /// The server has no switch of its own: the whole configuration it already
  /// has is written back with only `enabled` changed, and `/dhcp/status` is
  /// read again to keep the row honest.
  Future<void> saveDhcp(bool value) async {
    final api = Provider.of<ServersProvider>(context, listen: false).apiClient2;
    final status = _dhcp;

    if (api == null || status == null || _savingDhcp) return;

    setState(() => _savingDhcp = true);

    final saved = await api.saveDhcpConfig(
      data: {
        "enabled": value,
        "interface_name": status.interfaceName,
        if (status.v4 != null) "v4": {
          "gateway_ip": status.v4!.gatewayIp,
          "subnet_mask": status.v4!.subnetMask,
          "range_start": status.v4!.rangeStart,
          "range_end": status.v4!.rangeEnd,
          "lease_duration": status.v4!.leaseDuration,
        },
        if (status.v6 != null) "v6": {
          "range_start": status.v6!.rangeStart,
          "range_end": status.v6!.rangeEnd,
          "lease_duration": status.v6!.leaseDuration,
        },
      },
    );

    final echo = saved.successful == true ? await api.getDhcpData() : null;

    if (!mounted) return;

    setState(() {
      _savingDhcp = false;
      if (echo?.successful == true) {
        _dhcp = (echo!.content as DhcpModel).dhcpStatus;
      }
    });

    if (saved.successful != true) {
      showSnackbar(
        appConfigProvider:
            Provider.of<AppConfigProvider>(context, listen: false),
        label: AppLocalizations.of(context)!.settingsNotSaved,
        color: Colors.red,
      );
    }
  }

  /// Same here: the retention, the anonymising and the ignored domains the
  /// server already uses are sent back untouched.
  Future<void> saveQueryLog(bool value) async {
    final api = Provider.of<ServersProvider>(context, listen: false).apiClient2;
    final config = _queryLog;

    if (api == null || config == null || _savingQueryLog) return;

    setState(() => _savingQueryLog = true);

    final result = await api.updateQueryLogParameters(
      data: {
        "enabled": value,
        "interval": config.interval,
        "anonymize_client_ip": config.anonymizeClientIp,
        "ignored": config.ignored ?? const <String>[],
      },
    );

    if (!mounted) return;

    setState(() {
      _savingQueryLog = false;
      if (result.successful == true) {
        _queryLog = QueryLogConfig(
          ignored: config.ignored,
          interval: config.interval,
          enabled: value,
          anonymizeClientIp: config.anonymizeClientIp,
        );
      }
    });

    if (result.successful != true) {
      showSnackbar(
        appConfigProvider:
            Provider.of<AppConfigProvider>(context, listen: false),
        label: AppLocalizations.of(context)!.logsConfigNotUpdated,
        color: Colors.red,
      );
    }
  }

  /// The header action reads the server again: its status, and with it the
  /// values the rows show. Only a server that does not answer says so.
  Future<void> refresh() async {
    final serversProvider =
        Provider.of<ServersProvider>(context, listen: false);
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);
    final localizations = AppLocalizations.of(context)!;

    final api = serversProvider.apiClient2;
    if (api == null) return;

    final refreshed =
        await statusProvider.getServerStatus(withLoadingIndicator: false);
    if (refreshed != true) {
      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: localizations.serverStatusNotRefreshed,
        color: Colors.red,
      );
      return;
    }

    await loadServerValues(
      api,
      dhcpAvailable: statusProvider.serverStatus?.dhcpAvailable == true,
    );
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

    /// One settings row: pushes on phones, selects in the master pane.
    Widget row({
      required int thisItem,
      required IconData icon,
      required Color iconColor,
      required String title,
      required Widget screenToNavigate,
      String? subtitle,
      String? value,
      Color? valueColor,
      Widget? trailing,
    }) {
      return AppleListTile(
        icon: icon,
        iconColor: iconColor,
        title: title,
        subtitle: subtitle,
        value: value,
        valueColor: valueColor,
        trailing: trailing,
        selected: widget.twoColumns &&
            appConfigProvider.selectedSettingsScreen == thisItem,
        showChevron: !widget.twoColumns,
        onTap: () => open(thisItem: thisItem, screen: screenToNavigate),
      );
    }

    /// A count the design layer puts in a capsule before the disclosure.
    Widget? countTrailing(Object? count) {
      if (count == null) return null;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ApplePill(label: '$count', color: palette.label2),
          if (!widget.twoColumns) ...[
            const SizedBox(width: 6),
            const AppleChevron(),
          ],
        ],
      );
    }

    // The values the rows read are asked for once per server.
    final api = serversProvider.apiClient2;
    final server = serversProvider.selectedServer;
    if (api != null && server != null && _loadedFor != server.id) {
      _loadedFor = server.id;
      loadServerValues(
        api,
        dhcpAvailable: statusProvider.serverStatus?.dhcpAvailable == true,
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

    // The name the language list itself shows for the language in use.
    final languageName = languageFromTag(
      appConfigProvider.selectedLanguage ??
          Localizations.localeOf(context).toLanguageTag(),
    )?.name;

    String? queryLogRetention() {
      final interval = _queryLog?.interval;
      if (interval == null || interval <= 0) return null;

      final hours = interval ~/ Duration.millisecondsPerHour;
      return l.retainedFor(hours > 0 ? l.hours(hours) : l.minutes(1));
    }

    String? dhcpPool() {
      final v4 = _dhcp?.v4;
      if (v4 == null || v4.rangeStart.isEmpty || v4.rangeEnd == null) {
        return null;
      }

      return l.dhcpAddressPool(v4.rangeStart, v4.rangeEnd!);
    }

    // The switch writes back a pool the server already has; a DHCP server with
    // no interface picked yet is set up on its own page.
    final dhcpConfigured =
        (_dhcp?.interfaceName?.isNotEmpty ?? false) && _dhcp?.v4 != null;

    final appRows = <Widget>[
      row(
        thisItem: 0,
        icon: CupertinoIcons.textformat_abc,
        iconColor: palette.tint,
        title: l.language,
        value: languageName,
        screenToNavigate: const LanguageSettings(),
      ),
      row(
        thisItem: 1,
        icon: CupertinoIcons.chart_bar,
        iconColor: palette.indigo,
        title: l.statisticsAndDashboard,
        subtitle: l.statisticsAndDashboardHelper,
        screenToNavigate: const StatisticsSettings(),
      ),
      AppleListTile(
        icon: CupertinoIcons.doc_text,
        iconColor: palette.orange,
        title: l.queryLogSettings,
        subtitle: queryLogRetention(),
        selected: widget.twoColumns &&
            appConfigProvider.selectedSettingsScreen == 2,
        showChevron: false,
        trailing: AppleSwitch(
          value: _queryLog?.enabled == true,
          onChanged: _queryLog == null || _savingQueryLog
              ? null
              : () => saveQueryLog(_queryLog?.enabled != true),
        ),
        onTap: () => open(thisItem: 2, screen: const LogsSettings()),
      ),
      AppleSwitchListTile(
        icon: CupertinoIcons.bolt,
        iconColor: palette.green,
        title: l.autoRefreshLiveLogs,
        value: appConfigProvider.autoRefreshLiveLogs,
        onChanged: (value) => appConfigProvider.setAutoRefreshLiveLogs(value),
      ),
      AppleSwitchListTile(
        icon: CupertinoIcons.paintbrush,
        iconColor: palette.pink,
        title: l.statusColorUseThemeColor,
        subtitle: l.statusColorUseThemeColorHelper,
        value: appConfigProvider.useThemeColorForStatus == true,
        onChanged: (value) => appConfigProvider.setUseThemeColorForStatus(value),
      ),
    ];

    final serverRows = <Widget>[
      row(
        thisItem: 3,
        icon: CupertinoIcons.globe,
        iconColor: palette.tint,
        title: l.dnsSettings,
        subtitle: l.dnsSettingsSummary,
        screenToNavigate: DnsSettings(
          splitView: widget.twoColumns,
        ),
      ),
      row(
        thisItem: 4,
        icon: CupertinoIcons.lock,
        iconColor: palette.green,
        title: l.encryptionSettings,
        subtitle: l.encryptionSettingsSummary,
        screenToNavigate: const EncryptionSettings(),
      ),
      AppleListTile(
        icon: CupertinoIcons.wifi,
        iconColor: palette.indigo,
        title: l.dhcpSettings,
        subtitle: dhcpPool(),
        selected: widget.twoColumns &&
            appConfigProvider.selectedSettingsScreen == 5,
        showChevron: false,
        trailing: AppleSwitch(
          value: _dhcp?.enabled == true,
          onChanged: !dhcpConfigured || _savingDhcp
              ? null
              : () => saveDhcp(_dhcp?.enabled != true),
        ),
        onTap: () => open(thisItem: 5, screen: const DhcpScreen()),
      ),
      row(
        thisItem: 6,
        icon: CupertinoIcons.list_bullet,
        iconColor: palette.purple,
        title: l.dnsRewrites,
        trailing: countTrailing(
          _rewrites == null ? null : intFormat(_rewrites!, Platform.localeName),
        ),
        screenToNavigate: const DnsRewritesScreen(),
      ),
      row(
        thisItem: 7,
        icon: CupertinoIcons.desktopcomputer,
        iconColor: palette.orange,
        title: l.serverInformation,
        subtitle: serverStatus?.serverVersion,
        screenToNavigate: const ServerInformation(),
      ),
      row(
        thisItem: 8,
        icon: CupertinoIcons.refresh,
        iconColor: palette.teal,
        title: l.checkUpdates,
        value: serversProvider.updateAvailable.data?.newVersion == null
            ? null
            : l.updateAvailableToVersion(
                serversProvider.updateAvailable.data!.newVersion!),
        valueColor: updateAvailable ? palette.tint : null,
        screenToNavigate: const UpdateScreen(),
      ),
    ];

    final aboutRows = <Widget>[
      AppleListTile(
        icon: CupertinoIcons.doc,
        iconColor: palette.gray,
        title: l.openSourceLicenses,
        selected: widget.twoColumns &&
            appConfigProvider.selectedSettingsScreen == 9,
        showChevron: !widget.twoColumns,
        trailing: countTrailing(_licenses),
        onTap: () => open(
          thisItem: 9,
          screen: LicensePage(
            applicationName: 'AdGuard Home Manager',
            applicationVersion: appInfo == null
                ? null
                : '${appInfo.version} (${appInfo.buildNumber})',
          ),
        ),
      ),
      row(
        thisItem: 10,
        icon: CupertinoIcons.bolt,
        iconColor: palette.gray,
        title: l.diagnosticsLog,
        screenToNavigate: const DiagnosticsLogScreen(),
      ),
    ];

    return ScaffoldMessenger(
        key: widget.twoColumns ? _scaffoldMessengerKey : null,
        child: AppleScreen(
          title: l.settings,
          actions: [
            if (api != null) IconButton(
              onPressed: refresh,
              icon: const Icon(CupertinoIcons.arrow_clockwise),
              tooltip: l.refresh,
            ),
            const SizedBox(width: 8),
          ],
          subtitle: appInfo == null
            ? null
            : 'AdGuard Home Manager · ${appInfo.version} (${appInfo.buildNumber})',
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
                        actionLabel: l.switchOrManageServers,
                        onAction: () =>
                            open(thisItem: 11, screen: const Servers()),
                      ),
                    ),
                  appearanceSection(),
                  AppleListSection(title: l.appSettings, children: appRows),
                  if (server != null &&
                      serverStatus != null &&
                      serversProvider.apiClient2 != null)
                    AppleListSection(
                        title: l.serverSettings, children: serverRows),
                  AppleListSection(title: l.aboutApp, children: aboutRows),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                    child: Text(
                      l.unofficialClient,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: palette.label3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ));
  }
}
