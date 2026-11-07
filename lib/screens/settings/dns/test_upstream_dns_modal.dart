import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/dns_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';

class _Item {
  final String url;
  final bool value;

  const _Item({
    required this.url,
    required this.value
  });
}

class TestUpstreamDnsModal extends StatefulWidget {
  const TestUpstreamDnsModal({super.key});

  @override
  State<TestUpstreamDnsModal> createState() => _TestUpstreamDnsModalState();
}

class _TestUpstreamDnsModalState extends State<TestUpstreamDnsModal> {
  LoadStatus loadStatus = LoadStatus.loading;
  List<_Item>? values;

  void checkDns() async {
    final dnsProvider = Provider.of<DnsProvider>(context, listen: false);
    if (dnsProvider.dnsInfo == null) {
      setState(() => loadStatus = LoadStatus.error);
      return;
    }
    final result = await Provider.of<ServersProvider>(context, listen: false).apiClient2!.testUpstreamDns(
      body: {
        "bootstrap_dns": dnsProvider.dnsInfo!.bootstrapDns,
        "fallback_dns": [],
        "private_upstream": dnsProvider.dnsInfo!.defaultLocalPtrUpstreams,
        "upstream_dns": dnsProvider.dnsInfo!.upstreamDns
      }
    );
    if (!mounted) return;
    if (result.successful == true) {
      setState(() {
        values = List<_Item>.from(
          (result.content as Map<String, dynamic>).entries.map((e) => _Item(
            url: e.key, 
            value: e.value == "OK" ? true : false
          ))  
        );
        loadStatus = LoadStatus.loaded;
      });
    }
    else {
      setState(() => loadStatus = LoadStatus.error);
    }
  }

  @override
  void initState() {
    checkDns();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    return AppleFormModal(
      title: l.testUpstreamDnsServers,
      dialog: true,
      icon: CupertinoIcons.checkmark_seal,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (context) {
              switch (loadStatus) {
                case LoadStatus.loading:
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CupertinoActivityIndicator(radius: 14),
                    ),
                  );
        
                case LoadStatus.loaded:
                  return Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: values!.map((v) => AppleListTile(
                          title: v.url,
                          mono: true,
                          showChevron: false,
                          trailing: v.value == true
                            ? Icon(
                                CupertinoIcons.checkmark_circle_fill,
                                color: p.green,
                                size: 20,
                              )
                            : Icon(
                                CupertinoIcons.xmark_circle_fill,
                                color: p.red,
                                size: 20,
                              ),
                        )).toList(),
                      ),
                    ),
                  );
              
                case LoadStatus.error:
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          color: p.red,
                          size: 30,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l.errorTestUpstreamDns,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: p.label2
                          ),
                        )
                      ],
                    ),
                  );
        
                default:
                  return const SizedBox();
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: AppleButton.secondary(
              label: l.close,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}