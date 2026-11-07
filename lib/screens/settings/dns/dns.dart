// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/settings/settings.dart';
import 'package:adguard_home_manager/screens/settings/dns/fallback_dns.dart';
import 'package:adguard_home_manager/screens/settings/dns/test_upstream_dns_modal.dart';
import 'package:adguard_home_manager/screens/settings/dns/clear_dns_cache_dialog.dart';
import 'package:adguard_home_manager/screens/settings/dns/cache_config.dart';
import 'package:adguard_home_manager/screens/settings/dns/dns_server_settings.dart';
import 'package:adguard_home_manager/screens/settings/dns/bootstrap_dns.dart';
import 'package:adguard_home_manager/screens/settings/dns/private_reverse_servers.dart';
import 'package:adguard_home_manager/screens/settings/dns/upstream_dns.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/providers/dns_provider.dart';
import 'package:adguard_home_manager/functions/clear_dns_cache.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/services/api_client.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';

/// The DNS page of the design layer: the upstreams the server asks, what it
/// caches and how often a client may ask.
///
/// Every row either reads a field of `/dns_info` or opens the screen that has
/// always edited it, so the page summarises the configuration without taking
/// the editing away from the screens that know how to validate it.
class DnsSettings extends StatefulWidget {
  final bool splitView;

  const DnsSettings({
    super.key,
    required this.splitView,
  });

  @override
  State<DnsSettings> createState() => _DnsSettingsState();
}

class _DnsSettingsState extends State<DnsSettings> {
  /// The DNS mode the server reported before the page switched parallel
  /// requests on, so switching them off returns to it instead of quietly
  /// picking another mode.
  String? _modeBeforeParallel;

  @override
  void initState() {
    Provider.of<DnsProvider>(context, listen: false).fetchDnsData(showLoading: true);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final dnsProvider = Provider.of<DnsProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final width = MediaQuery.of(context).size.width;
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final dnsInfo = dnsProvider.dnsInfo;

    void navigate(Widget w) {
      if (widget.splitView) {
        Navigator.of(settingsNavigatorKey.currentContext!).push(MaterialPageRoute(builder: (ctx) => w));
      }
      else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => w
          )
        );
      }
    }

    void clearCache() async {
      final result = await clearDnsCache(context, serversProvider.selectedServer!);
      if (result.successful == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider, 
          label: l.dnsCacheCleared, 
          color: p.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider, 
          label: l.dnsCacheNotCleared, 
          color: p.red
        );
      }
    }

    /// The three answers the DNS screens give after a write, so a switch on
    /// this page reports exactly what the screen editing the same value does.
    void reportSaved(ApiResponse result) {
      if (result.successful == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.dnsConfigSaved,
          color: p.green,
        );
      }
      else if (result.statusCode == 400) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.someValueNotValid,
          color: p.red,
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.dnsConfigNotSaved,
          color: p.red,
        );
      }
    }

    Future<void> writeUpstreamMode(String mode) async {
      final info = dnsInfo;
      if (info == null) return;

      final processModal = ProcessModal();
      processModal.open(l.savingConfig);

      // `/dns_config` is written whole, so the upstreams and their timeout go
      // back as the server sent them and only the mode changes.
      final result = await dnsProvider.saveUpstreamDnsConfig({
        "upstream_dns": info.upstreamDns,
        "upstream_mode": mode,
        "upstream_timeout": info.upstreamTimeout,
      });

      processModal.close();
      reportSaved(result);
    }

    Future<void> writeEdns(bool value) async {
      final info = dnsInfo;
      if (info == null) return;

      final processModal = ProcessModal();
      processModal.open(l.savingConfig);

      // The same payload `DnsServerSettingsScreen` sends, with only the EDNS
      // flag moved. Everything the page does not show travels back untouched.
      final result = await dnsProvider.saveDnsServerConfig({
        "ratelimit": info.ratelimit,
        "edns_cs_enabled": value,
        "edns_cs_use_custom": value ? (info.ednsCsUseCustom ?? false) : false,
        "edns_cs_custom_ip": value ? (info.ednsCsCustomIp ?? '') : '',
        "dnssec_enabled": info.dnssecEnabled,
        "disable_ipv6": info.disableIpv6,
        "blocking_mode": info.blockingMode,
        "blocking_ipv4": info.blockingIpv4,
        "blocking_ipv6": info.blockingIpv6,
        "blocked_response_ttl": info.blockedResponseTtl,
        "ratelimit_subnet_len_ipv4": info.ratelimitSubnetLenIpv4,
        "ratelimit_subnet_len_ipv6": info.ratelimitSubnetLenIpv6,
        "ratelimit_whitelist": info.ratelimitWhitelist,
      });

      processModal.close();
      reportSaved(result);
    }

    // A resolver written with a scheme the server reaches over TLS or QUIC is
    // an encrypted upstream, which is what the design layer counts here.
    final encryptedUpstreams = dnsInfo?.upstreamDns
      .where((item) => item.startsWith('tls://') || item.startsWith('quic://'))
      .length;

    return AppleScreen(
      title: l.dnsSettings,
      subtitle: l.dnsSettingsSubtitle,
      leading: isDesktop(width)
        ? null
        : AppleBackButton(
            label: l.back,
            onPressed: () => Navigator.pop(context),
          ),
      actions: [
        IconButton(
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => const TestUpstreamDnsModal(),
          ),
          icon: const Icon(CupertinoIcons.checkmark_seal),
          tooltip: l.testUpstreamDnsServers,
        ),
        IconButton(
          onPressed: () => showDialog(
            context: context,
            builder: (context) => ClearDnsCacheDialog(onConfirm: clearCache),
          ),
          icon: const Icon(CupertinoIcons.trash),
          tooltip: l.clearDnsCache,
        ),
      ],
      onRefresh: () async {
        await dnsProvider.fetchDnsData();
      },
      slivers: [
        if (dnsProvider.loadStatus == LoadStatus.loading)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppleLoading(label: l.loadingDnsConfig),
          ),

        if (dnsProvider.loadStatus == LoadStatus.error)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppleEmptyState(
              icon: CupertinoIcons.exclamationmark_triangle,
              title: l.dnsConfigNotLoaded,
              // The refresh handle belongs to the config list, and the list
              // is exactly what did not arrive, so this card has to offer the
              // retry itself.
              action: AppleFormButton(
                label: l.refresh,
                background: p.tint,
                foreground: Colors.white,
                onPressed: () => dnsProvider.fetchDnsData(showLoading: true),
              ),
              color: p.red,
            ),
          ),

        if (dnsProvider.loadStatus == LoadStatus.loaded && dnsInfo != null) ...[
          SliverToBoxAdapter(
            child: AppleListSection(
              title: l.upstreamDns,
              margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              headerTrailing: AppleHeaderAction(
                label: l.add,
                onPressed: () => navigate(const UpstreamDnsScreen()),
              ),
              children: [
                if (dnsInfo.upstreamDns.isEmpty)
                  AppleListTile(
                    title: l.noUpstreamDns,
                    showChevron: false,
                  )
                else
                  for (final upstream in dnsInfo.upstreamDns)
                    AppleListTile(
                      title: upstream,
                      mono: true,
                      showChevron: false,
                      onTap: () => navigate(const UpstreamDnsScreen()),
                    ),
                AppleListTile(
                  title: l.bootstrapDns,
                  subtitle: dnsInfo.bootstrapDns.isEmpty
                    ? l.noBootstrapDns
                    : dnsInfo.bootstrapDns.join(' · '),
                  icon: CupertinoIcons.lock,
                  iconColor: p.green,
                  onTap: () => navigate(const BootstrapDnsScreen()),
                ),
                if (dnsInfo.fallbackDns != null)
                  AppleListTile(
                    title: l.fallbackDnsServers,
                    subtitle: dnsInfo.fallbackDns!.isEmpty
                      ? l.noFallbackDnsAdded
                      : dnsInfo.fallbackDns!.join(' · '),
                    icon: CupertinoIcons.arrow_swap,
                    iconColor: p.teal,
                    onTap: () => navigate(const FallbackDnsScreen()),
                  ),
                AppleListTile(
                  title: l.dotDoqUpstreams,
                  icon: CupertinoIcons.globe,
                  iconColor: p.tint,
                  // The capsule only earns its place once there is something
                  // to count: a bare "0" of nothing is not a fact. The row
                  // then opens the list the number came from, so the
                  // disclosure and the count travel together.
                  trailing: encryptedUpstreams == null ||
                          encryptedUpstreams == 0
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ApplePill(
                              label: intFormat(
                                encryptedUpstreams,
                                Platform.localeName,
                              ),
                              color: p.label2,
                            ),
                            const SizedBox(width: 6),
                            const AppleChevron(),
                          ],
                        ),
                  onTap: () => navigate(const UpstreamDnsScreen()),
                ),
                AppleSwitchListTile(
                  icon: CupertinoIcons.arrow_2_circlepath,
                  iconColor: p.orange,
                  title: l.parallelRequests,
                  subtitle: l.parallelRequestsSubtitle,
                  // `/dns_info` answers with "parallel" for the mode and with
                  // nothing else, so the switch is the mode of the server.
                  value: dnsInfo.upstreamMode == 'parallel',
                  onChanged: (value) {
                    if (value) {
                      _modeBeforeParallel = dnsInfo.upstreamMode;
                      writeUpstreamMode('parallel');
                    }
                    else {
                      writeUpstreamMode(_modeBeforeParallel ?? '');
                    }
                  },
                ),
                AppleSwitchListTile(
                  icon: CupertinoIcons.bolt,
                  iconColor: p.purple,
                  title: l.enableEdns,
                  value: dnsInfo.ednsCsEnabled,
                  onChanged: writeEdns,
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: AppleListSection(
              title: l.advancedSettings,
              children: [
                AppleListTile(
                  // Zero asks the server not to limit anybody at all.
                  title: l.rateLimit,
                  value: dnsInfo.ratelimit == 0
                    ? l.disabled
                    : l.queriesPerSecond(dnsInfo.ratelimit),
                  onTap: () => navigate(const DnsServerSettingsScreen()),
                ),
                AppleListTile(
                  title: l.dnsCacheSize,
                  value: dnsInfo.cacheSize == null
                    ? null
                    : bytesFormat(dnsInfo.cacheSize!, Platform.localeName),
                  onTap: () => navigate(const CacheConfigDnsScreen()),
                ),
                AppleListTile(
                  title: l.overrideMinimumTtl,
                  value: dnsInfo.cacheTtlMin == null
                    ? null
                    : l.seconds(dnsInfo.cacheTtlMin!),
                  onTap: () => navigate(const CacheConfigDnsScreen()),
                ),
                AppleListTile(
                  title: l.overrideMaximumTtl,
                  value: dnsInfo.cacheTtlMax == null
                    ? null
                    : l.seconds(dnsInfo.cacheTtlMax!),
                  onTap: () => navigate(const CacheConfigDnsScreen()),
                ),
                AppleListTile(
                  title: l.privateReverseDnsServers,
                  icon: CupertinoIcons.person,
                  iconColor: p.indigo,
                  onTap: () => navigate(const PrivateReverseDnsServersScreen()),
                ),
                AppleListTile(
                  title: l.dnsServerSettings,
                  icon: CupertinoIcons.settings,
                  iconColor: p.gray,
                  onTap: () => navigate(const DnsServerSettingsScreen()),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
