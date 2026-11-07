// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/settings/dns/comment_modal.dart';

import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/providers/dns_provider.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';

class UpstreamDnsScreen extends StatefulWidget {
  const UpstreamDnsScreen({super.key});

  @override
  State<UpstreamDnsScreen> createState() => _UpstreamDnsScreenState();
}

class _UpstreamDnsScreenState extends State<UpstreamDnsScreen> {
  List<Map<String, dynamic>> dnsServers = [];

  String upstreamMode = "";

  bool validValues = false;

  final upstreamTimeoutController = TextEditingController();
  String? upstreamTimeoutError;

  void checkValidValues() {
    // Reading element['controller.text'] asked the map for a key nobody sets,
    // so every row looked fine and an empty server could be saved.
    final rowsOk = dnsServers.isNotEmpty && dnsServers.every(
      (element) => element['controller'] == null
        ? true
        : element['controller'].text.trim().isNotEmpty,
    );

    setState(() => validValues = rowsOk && upstreamTimeoutError == null);
  }

  @override
  void initState() {
    final dnsProvider = Provider.of<DnsProvider>(context, listen: false);

    for (var item in dnsProvider.dnsInfo!.upstreamDns) {
      if (item.contains("#")) {
        dnsServers.add({
          'comment': item
        });
      }
      else {
        final controller = TextEditingController();
        controller.text = item;
        dnsServers.add({
          'controller': controller
        });
      }
    }
    upstreamMode = dnsProvider.dnsInfo!.upstreamMode ?? "";
    upstreamTimeoutController.text = dnsProvider.dnsInfo!.upstreamTimeout != null ? dnsProvider.dnsInfo!.upstreamTimeout.toString() : "";
    // Nothing has been touched yet, so the page is only as sound as the rows
    // the server gave us.
    validValues = dnsServers.isNotEmpty;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final dnsProvider = Provider.of<DnsProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    
    final width = MediaQuery.of(context).size.width;
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    void validateTimeout(String value) {
      setState(() {
        upstreamTimeoutError = value != '' && int.tryParse(value) != null && int.parse(value) > 0
          ? null
          : value == ''
            ? AppLocalizations.of(context)!.fieldCannotBeEmpty
            : AppLocalizations.of(context)!.invalidValue;
      });

      // A sound timeout does not make an empty server row sound, so the
      // verdict stays with the one place that looks at all of them.
      checkValidValues();
    }

    void openAddCommentModal() {
      if (width > 900 || !(Platform.isAndroid || Platform.isIOS)) {
        showDialog(
          context: context, 
          builder: (context) => CommentModal(
            onConfirm: (value) {
              setState(() {
                dnsServers.add({
                  'comment': value
                });
              });
            },
            dialog: true,
          ),
        );
      }
      else {
        showModalBottomSheet(
          context: context, 
          useRootNavigator: true,
          builder: (context) => CommentModal(
            onConfirm: (value) {
              setState(() {
                dnsServers.add({
                  'comment': value
                });
              });
            },
            dialog: false,
          ),
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          isDismissible: true
        );
      }
    }

    void openEditCommentModal(Map<String, dynamic> item, int position) {
      if (width > 900 || !(Platform.isAndroid || Platform.isIOS)) {
        showDialog(
          context: context, 
          builder: (context) => CommentModal(
            comment: item['comment'],
            onConfirm: (value) {
              setState(() => dnsServers[position] = { 'comment': value });
            },
            dialog: true,
          ),
        );
      }
      else {
        showModalBottomSheet(
          context: context, 
          useRootNavigator: true,
          builder: (context) => CommentModal(
            comment: item['comment'],
            onConfirm: (value) {
              setState(() => dnsServers[position] = { 'comment': value });
            },
            dialog: false,
          ),
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          isDismissible: true
        );
      }
    }

    void saveData() async {
      ProcessModal processModal = ProcessModal();
      processModal.open(l.savingConfig);

      final result = await dnsProvider.saveUpstreamDnsConfig({
        "upstream_dns": dnsServers.map((e) => e['controller'] != null ? e['controller'].text : e['comment']).toList(),
        "upstream_mode": upstreamMode,
        "upstream_timeout": int.tryParse(upstreamTimeoutController.text)
      });

      processModal.close();

      if (!context.mounted) return;
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

    // A line of the upstream list is either an address or a comment, and the
    // three modes are one of them in force: the rows carry the mark the design
    // layer puts on the choice that is active, the way the blocking-mode rows
    // of the server settings do.
    AppleListTile modeRow(String value, String title, String description) =>
        AppleListTile(
          title: title,
          subtitle: description,
          showChevron: false,
          onTap: () => setState(() => upstreamMode = value),
          trailing: upstreamMode == value
            ? Icon(CupertinoIcons.checkmark, color: p.tint)
            : const SizedBox.shrink(),
        );

    return AppleScreen(
      title: l.upstreamDns,
      subtitle: l.upstreamDnsDescription,
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
            headerTrailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppleHeaderAction(label: l.comment, onPressed: openAddCommentModal),
                const SizedBox(width: 14),
                AppleHeaderAction(
                  label: l.address,
                  onPressed: () {
                    setState(() => dnsServers.add({
                      'controller': TextEditingController()
                    }));
                    checkValidValues();
                  },
                ),
              ],
            ),
            margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            children: [
              if (dnsServers.isEmpty)
                AppleEmptyState(
                  icon: CupertinoIcons.lock,
                  title: l.noUpstreamDns,
                  color: p.label3,
                ),
              for (final item in dnsServers)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                  child: Row(
                    children: [
                      if (item['controller'] != null) Expanded(
                        child: AppleTextField(
                          label: l.dnsServer,
                          icon: CupertinoIcons.lock,
                          controller: item['controller'],
                          onChanged: (_) => checkValidValues(),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      if (item['comment'] != null) Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                item['comment'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 16, color: p.label2),
                              ),
                            ),
                            IconButton(
                              onPressed: () => openEditCommentModal(item, dnsServers.indexOf(item)), 
                              icon: Icon(
                                CupertinoIcons.pencil,
                                size: 19,
                                color: p.tint,
                              ),
                              tooltip: l.edit,
                            )
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() => dnsServers = dnsServers.where((i) => i != item).toList());
                          checkValidValues();
                        }, 
                        icon: Icon(
                          CupertinoIcons.minus_circle,
                          size: 19,
                          color: p.red,
                        ),
                        tooltip: l.remove,
                      )
                    ],
                  ),
                ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: AppleListSection(
            title: l.dnsMode,
            margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
            children: [
              modeRow("", l.loadBalancing, l.loadBalancingDescription),
              modeRow("parallel", l.parallelRequests, l.parallelRequestsDescription),
              modeRow("fastest_addr", l.fastestIpAddress, l.fastestIpAddressDescription),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: AppleFormGroupLabel(
            l.others,
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 7),
          ),
        ),
        SliverToBoxAdapter(
          child: AppleTextField(
            label: l.upstreamTimeout,
            icon: CupertinoIcons.timer,
            controller: upstreamTimeoutController,
            onChanged: validateTimeout,
            helper: l.upstreamTimeoutHelper,
            helperMaxLines: 2,
            error: upstreamTimeoutError,
          ),
        ),
      ],
    );
  }
}