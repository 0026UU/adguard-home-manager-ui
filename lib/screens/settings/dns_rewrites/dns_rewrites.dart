// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/settings/dns_rewrites/delete_dns_rewrite.dart';
import 'package:adguard_home_manager/screens/settings/dns_rewrites/dns_rewrite_modal.dart';

import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/rewrite_rules_provider.dart';
import 'package:adguard_home_manager/models/rewrite_rules.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';

/// The rewrite table of the server: one rule per row, the domain it matches
/// and the address it answers with.
class DnsRewritesScreen extends StatefulWidget {
  const DnsRewritesScreen({super.key});

  @override
  State<DnsRewritesScreen> createState() => _DnsRewritesScreenState();
}

class _DnsRewritesScreenState extends State<DnsRewritesScreen> {
  @override
  void initState() {
    Provider.of<RewriteRulesProvider>(context, listen: false).fetchData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final rewriteRulesProvider = Provider.of<RewriteRulesProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final width = MediaQuery.of(context).size.width;
    final p = ApplePalette.of(context);
    final l = AppLocalizations.of(context)!;

    void deleteDnsRewrite(RewriteRules rule) async {
      final processModal = ProcessModal();
      processModal.open(l.deleting);

      final result = await rewriteRulesProvider.deleteDnsRewrite(rule);

      processModal.close();

      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: result
          ? l.dnsRewriteRuleDeleted
          : l.dnsRewriteRuleNotDeleted,
        color: result ? p.green : p.red,
      );
    }

    void addDnsRewrite(RewriteRules rule, _) async {
      final processModal = ProcessModal();
      processModal.open(l.addingRewrite);

      final result = await rewriteRulesProvider.addDnsRewrite(rule);

      processModal.close();

      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: result ? l.dnsRewriteRuleAdded : l.dnsRewriteRuleNotAdded,
        color: result ? p.green : p.red,
      );
    }

    void updateRewriteRule(RewriteRules newRule, RewriteRules previousRule) async {
      final processModal = ProcessModal();
      processModal.open(l.updatingRule);

      final result = await rewriteRulesProvider.editDnsRewrite(newRule, previousRule);

      processModal.close();

      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: result ? l.dnsRewriteRuleUpdated : l.dnsRewriteRuleNotUpdated,
        color: result ? p.green : p.red,
      );
    }

    // The form is a card on a wide screen and a sheet on a phone, the same way
    // the rest of the Apple forms are presented.
    void openForm({RewriteRules? rule, required bool isAdd}) {
      final asDialog = isDesktop(width) || !(Platform.isAndroid || Platform.isIOS);

      void onConfirm(RewriteRules newRule, RewriteRules? previousRule) {
        if (isAdd) {
          addDnsRewrite(newRule, previousRule);
        }
        else {
          updateRewriteRule(newRule, previousRule!);
        }
      }

      final form = DnsRewriteModal(
        onConfirm: onConfirm,
        dialog: asDialog,
        rule: rule,
        onDelete: (deleted) => showDialog(
          context: context,
          builder: (context) => DeleteDnsRewrite(
            onConfirm: () => deleteDnsRewrite(deleted),
          ),
        ),
      );

      if (asDialog) {
        showDialog(context: context, builder: (context) => form);
      }
      else {
        showModalBottomSheet(
          context: context,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => form,
        );
      }
    }

    return AppleScreen(
      title: l.dnsRewrites,
      subtitle: l.dnsRewritesSubtitle,
      // A pushed route has a route to go back from; a column does not. The
      // design layer names the capsule after the screen behind it, which the
      // page itself cannot know, so it keeps the fallback label.
      leading: isDesktop(width)
        ? null
        : AppleBackButton(
            label: l.back,
            onPressed: () => Navigator.pop(context),
          ),
      onRefresh: () async {
        final result = await rewriteRulesProvider.fetchData();
        if (result == false) {
          showSnackbar(
            appConfigProvider: appConfigProvider,
            label: l.rewriteRulesNotLoaded,
            color: p.red,
          );
        }
      },
      slivers: [
        if (rewriteRulesProvider.loadStatus == LoadStatus.loading)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppleLoading(),
          ),

        if (rewriteRulesProvider.loadStatus == LoadStatus.error)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppleEmptyState(
              icon: CupertinoIcons.exclamationmark_triangle,
              title: l.rewriteRulesNotLoaded,
              color: p.red,
            ),
          ),

        if (rewriteRulesProvider.loadStatus == LoadStatus.loaded) ...[
          if (rewriteRulesProvider.rewriteRules?.isEmpty ?? true)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppleEmptyState(
                icon: CupertinoIcons.arrow_2_circlepath_circle,
                title: l.noRewriteRules,
                color: p.label3,
              ),
            )
          else
            SliverToBoxAdapter(
              child: AppleListSection(
                title: l.rules,
                margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                headerTrailing: AppleHeaderAction(
                  label: l.add,
                  onPressed: () => openForm(isAdd: true),
                ),
                children: [
                  for (final rule in rewriteRulesProvider.rewriteRules!)
                    AppleListTile(
                      // A rule that answers nothing is still worth reading, so
                      // its state rides on the subtitle instead of a control
                      // the design layer does not draw.
                      title: rule.domain,
                      subtitle: rule.enabled
                        ? rule.answer
                        : '${rule.answer} · ${l.disabled}',
                      onTap: () => openForm(rule: rule, isAdd: false),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
