// ignore_for_file: use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/settings/server_info/dns_addresses_modal.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/models/server_info.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';

/// What the server says about itself: its version, the ports it listens on and
/// the states it is in.
///
/// The design layer also shows the run mode, how long the process has been up,
/// the CPU architecture and how many clients are registered. `/status` answers
/// none of that, so those lines are left out instead of being filled with
/// numbers the server never sent.
class ServerInformation extends StatefulWidget {
  const ServerInformation({super.key});

  @override
  State<ServerInformation> createState() => _ServerInformationState();
}

class _ServerInformationState extends State<ServerInformation> {
  ServerInfo serverInfo = ServerInfo(loadStatus: LoadStatus.loading);

  Future<void> fetchServerInfo() async {
    final result = await Provider.of<ServersProvider>(context, listen: false).apiClient2!.getServerInfo();
    if (!mounted) return;
    if (result.successful == true) {
      setState(() {
        serverInfo.data = result.content as ServerInfoData;
        serverInfo.loadStatus = LoadStatus.loaded;
      });
    }
    else {
      setState(() => serverInfo.loadStatus = LoadStatus.error);
    }
  }

  @override
  void initState() {
    fetchServerInfo();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final width = MediaQuery.of(context).size.width;
    final serversProvider = Provider.of<ServersProvider>(context);
    final data = serverInfo.data;

    // The design layer puts the address of the server under its name. The
    // addresses `/status` reports come first; the connection the app opened is
    // the only other real answer when the server publishes none.
    String? host;
    if (data != null && data.dnsAddresses.isNotEmpty) {
      host = data.dnsAddresses.first;
    }
    else {
      host = serversProvider.selectedServer?.domain;
    }

    void openDnsAddresses() {
      if (width > 700) {
        showDialog(
          context: context, 
          builder: (context) => DnsAddressesModal(
            dnsAddresses: data!.dnsAddresses,
            isDialog: true,
          )
        );
      }
      else {
        showModalBottomSheet(
          context: context, 
          builder: (context) => DnsAddressesModal(
            dnsAddresses: data!.dnsAddresses,
            isDialog: false,
          ),
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          useSafeArea: true
        );
      }
    }

    String yesNo(bool value) => value ? l.yes : l.no;

    return AppleScreen(
      title: l.serverInformation,
      subtitle: host,
      leading: isDesktop(width)
        ? null
        : AppleBackButton(
            label: l.back,
            onPressed: () => Navigator.pop(context),
          ),
      onRefresh: fetchServerInfo,
      slivers: [
        if (serverInfo.loadStatus == LoadStatus.loading)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppleLoading(label: l.loadingServerInfo),
          ),

        if (serverInfo.loadStatus == LoadStatus.error)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppleEmptyState(
              icon: CupertinoIcons.exclamationmark_triangle,
              title: l.serverInfoNotLoaded,
              color: p.red,
            ),
          ),

        if (serverInfo.loadStatus == LoadStatus.loaded && data != null) ...[
          SliverToBoxAdapter(
            child: AppleListSection(
              margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              children: [
                AppleListTile(
                  title: l.serverVersion,
                  value: data.version,
                  showChevron: false,
                ),
                AppleListTile(
                  title: l.httpPort,
                  value: data.httpPort.toString(),
                  showChevron: false,
                ),
                AppleListTile(
                  title: l.dnsPort,
                  value: data.dnsPort.toString(),
                  showChevron: false,
                ),
                AppleListTile(
                  title: l.protectionEnabled,
                  value: yesNo(data.protectionEnabled),
                  valueColor: data.protectionEnabled ? p.green : p.red,
                  showChevron: false,
                ),
                AppleListTile(
                  title: l.dhcpAvailable,
                  value: yesNo(data.dhcpAvailable),
                  valueColor: data.dhcpAvailable ? p.green : p.label2,
                  showChevron: false,
                ),
                AppleListTile(
                  title: l.serverRunning,
                  value: yesNo(data.running),
                  valueColor: data.running ? p.green : p.red,
                  showChevron: false,
                ),
                if (data.language.isNotEmpty)
                  AppleListTile(
                    title: l.serverLanguage,
                    value: data.language,
                    showChevron: false,
                  ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: AppleListSection(
              title: l.dnsAddresses,
              children: [
                AppleListTile(
                  title: l.seeDnsAddresses,
                  subtitle: data.dnsAddresses.isEmpty
                    ? null
                    : data.dnsAddresses.join(' · '),
                  icon: CupertinoIcons.globe,
                  iconColor: p.tint,
                  onTap: openDnsAddresses,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
