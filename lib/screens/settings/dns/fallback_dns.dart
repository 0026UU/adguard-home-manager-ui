import 'dart:io';

import 'package:adguard_home_manager/constants/regexps.dart';
import 'package:adguard_home_manager/screens/settings/dns/comment_modal.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/providers/dns_provider.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';

class FallbackDnsScreen extends StatefulWidget {
  const FallbackDnsScreen({super.key});

  @override
  State<FallbackDnsScreen> createState() => _FallbackDnsScreenState();
}

class _FallbackDnsScreenState extends State<FallbackDnsScreen> {
  List<Map<String, dynamic>> fallbackControllers = [];

  bool validValues = false;

  void validateIp(Map<String, dynamic> field, String value) {
    if (Regexps.ipv4Address.hasMatch(value) == true || Regexps.ipv6Address.hasMatch(value) || Regexps.url.hasMatch(value) == true) {
      setState(() => field['error'] = null);
    }
    else {
      setState(() => field['error'] = AppLocalizations.of(context)!.invalidIpOrUrl);
    }
    checkValidValues();
  }

  void checkValidValues() {
    if (fallbackControllers.every((element) => element['error'] == null)) {
      setState(() => validValues = true);
    }
    else {
      setState(() => validValues = false);
    }
  }

  @override
  void initState() {
    final dnsProvider = Provider.of<DnsProvider>(context, listen: false);

    for (var item in dnsProvider.dnsInfo!.fallbackDns!) {
      if (item.contains("#")) {
        fallbackControllers.add({
          'comment': item
        });
      }
      else {
        final controller = TextEditingController();
        controller.text = item;
        fallbackControllers.add({
          'controller': controller,
          'error': null,
          'isComment': item.contains("#")
        });
      }
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

      final result = await dnsProvider.saveFallbackDnsConfig({
        "fallback_dns": fallbackControllers.map(
          (e) => e['controller'] != null 
            ? e['controller'].text
            : e['comment']
        ).toList(),
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

    void openAddCommentModal() {
      if (width > 900 || !(Platform.isAndroid || Platform.isIOS)) {
        showDialog(
          context: context, 
          builder: (context) => CommentModal(
            onConfirm: (value) {
              setState(() {
                fallbackControllers.add({
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
                fallbackControllers.add({
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
              setState(() => fallbackControllers[position] = { 'comment': value });
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
              setState(() => fallbackControllers[position] = { 'comment': value });
            },
            dialog: false,
          ),
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          isDismissible: true
        );
      }
    }

    return AppleScreen(
      title: l.fallbackDnsServers,
      subtitle: l.fallbackDnsServersDescription,
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
            // The two things a fallback line can be are the two actions the
            // header offers; the words the buttons used to carry are the same
            // words, moved onto the caption line of the group.
            headerTrailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppleHeaderAction(label: l.comment, onPressed: openAddCommentModal),
                const SizedBox(width: 14),
                AppleHeaderAction(
                  label: l.address,
                  onPressed: () {
                    setState(() => fallbackControllers.add({
                      'controller': TextEditingController(),
                      'error': null
                    }));
                    checkValidValues();
                  },
                ),
              ],
            ),
            footer: l.fallbackDnsServersInfo,
            margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            children: [
              if (fallbackControllers.isEmpty)
                AppleEmptyState(
                  icon: CupertinoIcons.arrow_swap,
                  title: l.noFallbackDnsAdded,
                  color: p.label3,
                ),
              for (final c in fallbackControllers)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                  child: Row(
                    children: [
                      if (c['controller'] != null) Expanded(
                        child: AppleTextField(
                          label: c['isComment'] == true 
                            ? l.comment
                            : l.dnsServer,
                          icon: c['isComment'] == true
                            ? CupertinoIcons.chat_bubble
                            : CupertinoIcons.arrow_swap,
                          controller: c['controller'],
                          error: c['error'],
                          onChanged: (value) => validateIp(c, value),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      if (c['comment'] != null) Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                c['comment'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 16, color: p.label2),
                              ),
                            ),
                            IconButton(
                              onPressed: () => openEditCommentModal(c, fallbackControllers.indexOf(c)), 
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
                          setState(() => fallbackControllers = fallbackControllers.where((con) => con != c).toList());
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
      ],
    );
  }
}