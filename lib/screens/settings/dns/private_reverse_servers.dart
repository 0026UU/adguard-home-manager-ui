// ignore_for_file: use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/providers/dns_provider.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';

class PrivateReverseDnsServersScreen extends StatefulWidget {
  const PrivateReverseDnsServersScreen({super.key});

  @override
  State<PrivateReverseDnsServersScreen> createState() => _PrivateReverseDnsServersScreenState();
}

class _PrivateReverseDnsServersScreenState extends State<PrivateReverseDnsServersScreen> {
  List<String> defaultReverseResolvers = [];
  bool editReverseResolvers = false;
  List<Map<String, dynamic>> reverseResolversControllers = [];
  bool usePrivateReverseDnsResolvers = false;
  bool enableReverseResolve = false;

  bool validValues = false;

  void validateAddress(Map<String, dynamic> item ,String value) {
    RegExp ipAddress = RegExp(r'(?:^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}$)|(?:^(?:(?:[a-fA-F\d]{1,4}:){7}(?:[a-fA-F\d]{1,4}|:)|(?:[a-fA-F\d]{1,4}:){6}(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|:[a-fA-F\d]{1,4}|:)|(?:[a-fA-F\d]{1,4}:){5}(?::(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,2}|:)|(?:[a-fA-F\d]{1,4}:){4}(?:(?::[a-fA-F\d]{1,4}){0,1}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,3}|:)|(?:[a-fA-F\d]{1,4}:){3}(?:(?::[a-fA-F\d]{1,4}){0,2}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,4}|:)|(?:[a-fA-F\d]{1,4}:){2}(?:(?::[a-fA-F\d]{1,4}){0,3}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,5}|:)|(?:[a-fA-F\d]{1,4}:){1}(?:(?::[a-fA-F\d]{1,4}){0,4}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,6}|:)|(?::(?:(?::[a-fA-F\d]{1,4}){0,5}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,7}|:)))(?:%[0-9a-zA-Z]{1,})?$)');
    RegExp domain = RegExp(r'^((http|https|tls|udp|tcp|quic|sdns):\/\/)?([a-z0-9|-]+\.)*[a-z0-9|-]+\.[a-z]+$');
    if (ipAddress.hasMatch(value) == true || domain.hasMatch(value) == true) {
      setState(() => item['error'] = null);
    }
    else {
      setState(() => item['error'] = AppLocalizations.of(context)!.invalidIpDomain);
    }

    checkDataValid();
  }

  void checkDataValid() {
    if (
      (
        editReverseResolvers == true &&
        reverseResolversControllers.every((element) => element['controller'].text != '') &&
        reverseResolversControllers.every((element) => element['error'] == null)
      ) == true
    ) {
      setState(() => validValues = true);
    }
    else {
      setState(() => validValues = false);
    }
  }

  @override
  void initState() {
    final dnsProvider = Provider.of<DnsProvider>(context, listen: false);

    for (var item in dnsProvider.dnsInfo!.defaultLocalPtrUpstreams) {
      defaultReverseResolvers.add(item);
    }
    if (dnsProvider.dnsInfo!.localPtrUpstreams.isEmpty) {
      reverseResolversControllers.add({
        'controller': TextEditingController(),
        'error': null
      });
    }
    for (var item in dnsProvider.dnsInfo!.localPtrUpstreams) {
      final controller = TextEditingController();
      controller.text = item;
      reverseResolversControllers.add({
        'controller': controller,
        'error': null
      });
    }
    if (dnsProvider.dnsInfo!.localPtrUpstreams.isNotEmpty) {
      editReverseResolvers = true;
    }
    usePrivateReverseDnsResolvers = dnsProvider.dnsInfo!.usePrivatePtrResolvers ?? false;
    enableReverseResolve = dnsProvider.dnsInfo!.resolveClients ?? false;
    validValues = true;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final dnsProvider = Provider.of<DnsProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final width = MediaQuery.of(context).size.width;
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    void saveData() async {
      ProcessModal processModal = ProcessModal();
      processModal.open(l.savingConfig);

      final result = await dnsProvider.savePrivateReverseServersConfig(
        editReverseResolvers == true
          ? {
            "local_ptr_upstreams": List<String>.from(reverseResolversControllers.map((e) => e['controller'].text)),
            "use_private_ptr_resolvers": usePrivateReverseDnsResolvers,
            "resolve_clients": enableReverseResolve
          } : {
            "use_private_ptr_resolvers": usePrivateReverseDnsResolvers,
            "resolve_clients": enableReverseResolve
          }
      );

      processModal.close();

      if (result.successful == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.dnsConfigSaved, 
          color: p.green
        );
      }
      else if (result.successful == false && result.statusCode == 400) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.someValueNotValid, 
          color: p.red
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.dnsConfigNotSaved, 
          color: p.red
        );
      } 
    }

    return AppleScreen(
      title: l.privateReverseDnsServers,
      subtitle: l.privateReverseDnsDescription,
      leading: isDesktop(width)
        ? null
        : AppleBackButton(
            label: l.back,
            onPressed: () => Navigator.pop(context),
          ),
      actions: [
        IconButton(
          onPressed: validValues == true
            ? () => saveData()
            : null, 
          icon: const Icon(CupertinoIcons.checkmark),
          tooltip: l.save,
        ),
      ],
      slivers: [
        if (editReverseResolvers == false)
          SliverToBoxAdapter(
            child: AppleListSection(
              title: l.reverseDnsDefault,
              // The sentence and the button that used to sit under it are the
              // two halves of the same header now: what the group holds on the
              // left, the way to write your own on the right.
              headerTrailing: AppleHeaderAction(
                label: l.edit,
                onPressed: () {
                  setState(() => editReverseResolvers = true);
                  checkDataValid();
                },
              ),
              footer: l.privateReverseDnsServersDescription,
              margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              children: [
                for (final item in defaultReverseResolvers)
                  AppleListTile(
                    title: item.replaceAll(RegExp(r'\(|\)'), ''),
                    mono: true,
                    showChevron: false,
                  ),
              ],
            ),
          ),
        if (editReverseResolvers == true)
          SliverToBoxAdapter(
            child: AppleListSection(
              title: l.serverAddress,
              headerTrailing: AppleHeaderAction(
                label: l.addItem,
                onPressed: () {
                  setState(() => reverseResolversControllers.add({
                    'controller': TextEditingController(),
                    'error': null
                  }));
                  checkDataValid();
                },
              ),
              footer: l.privateReverseDnsServersDescription,
              margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              children: [
                if (reverseResolversControllers.isEmpty)
                  AppleEmptyState(
                    icon: CupertinoIcons.location_fill,
                    title: l.noServerAddressesAdded,
                    color: p.label3,
                  ),
                for (final c in reverseResolversControllers)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppleTextField(
                            label: l.serverAddress,
                            icon: CupertinoIcons.location_fill,
                            controller: c['controller'],
                            error: c['error'],
                            onChanged: (value) => validateAddress(c, value),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        IconButton(
                          tooltip: l.remove,
                          onPressed: () {
                            setState(() => reverseResolversControllers = reverseResolversControllers.where((con) => con != c).toList());
                            checkDataValid();
                          }, 
                          icon: Icon(
                            CupertinoIcons.minus_circle,
                            size: 19,
                            color: p.red,
                          ),
                        )
                      ],
                    ),
                  ),
              ],
            ),
          ),
        SliverToBoxAdapter(
          child: AppleListSection(
            children: [
              AppleSwitchListTile(
                icon: CupertinoIcons.location_fill,
                iconColor: p.indigo,
                value: usePrivateReverseDnsResolvers,
                onChanged: (value) => setState(() => usePrivateReverseDnsResolvers = value), 
                title: l.usePrivateReverseDnsResolvers,
                subtitle: l.usePrivateReverseDnsResolversDescription,
              ),
              AppleSwitchListTile(
                icon: CupertinoIcons.arrow_2_circlepath,
                iconColor: p.teal,
                value: enableReverseResolve,
                onChanged: (value) => setState(() => enableReverseResolve = value), 
                title: l.enableReverseResolving,
                subtitle: l.enableReverseResolvingDescription,
              ),
            ],
          ),
        ),
      ],
    );
  }
}