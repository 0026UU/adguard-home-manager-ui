// ignore_for_file: use_build_context_synchronously

import 'package:adguard_home_manager/constants/regexps.dart';
import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/providers/dns_provider.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';

class BootstrapDnsScreen extends StatefulWidget {
  const BootstrapDnsScreen({super.key});

  @override
  State<BootstrapDnsScreen> createState() => _BootstrapDnsScreenState();
}

class _BootstrapDnsScreenState extends State<BootstrapDnsScreen> {
  List<Map<String, dynamic>> bootstrapControllers = [];

  bool validValues = false;

  void validateIp(Map<String, dynamic> field, String value) {
    if (Regexps.ipv4Address.hasMatch(value) == true || Regexps.ipv6Address.hasMatch(value) == true) {
      setState(() => field['error'] = null);
    }
    else {
      setState(() => field['error'] = AppLocalizations.of(context)!.invalidIp);
    }
    checkValidValues();
  }

  void checkValidValues() {
    if (
      bootstrapControllers.isNotEmpty &&
      bootstrapControllers.every((element) => element['controller'].text != '') &&
      bootstrapControllers.every((element) => element['error'] == null)
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

    for (var item in dnsProvider.dnsInfo!.bootstrapDns) {
      final controller = TextEditingController();
      controller.text = item;
      bootstrapControllers.add({
        'controller': controller,
        'error': null
      });
    }
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

      final result = await dnsProvider.saveBootstrapDnsConfig({
        "bootstrap_dns": bootstrapControllers.map((e) => e['controller'].text).toList(),
      });

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
      title: l.bootstrapDns,
      subtitle: l.bootstrapDnsDescription,
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
        SliverToBoxAdapter(
          child: AppleListSection(
            // The bar above the card is the row that opens this screen, which
            // already says "Bootstrap DNS", so the group keeps its header for
            // the action alone and hands its own explanation to the footer.
            headerTrailing: AppleHeaderAction(
              label: l.addItem,
              onPressed: () {
                setState(() => bootstrapControllers.add({
                  'controller': TextEditingController(),
                  'error': null
                }));
                checkValidValues();
              },
            ),
            footer: l.bootstrapDnsServersInfo,
            margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            children: [
              if (bootstrapControllers.isEmpty)
                AppleEmptyState(
                  icon: CupertinoIcons.lock,
                  title: l.noBootstrapDns,
                  color: p.label3,
                ),
              for (final c in bootstrapControllers)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppleTextField(
                          label: l.dnsServer,
                          icon: CupertinoIcons.lock,
                          controller: c['controller'],
                          error: c['error'],
                          onChanged: (value) => validateIp(c, value),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      IconButton(
                        tooltip: l.remove,
                        onPressed: () {
                          setState(() => bootstrapControllers = bootstrapControllers.where((con) => con != c).toList());
                          checkValidValues();
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
      ],
    );
  }
}