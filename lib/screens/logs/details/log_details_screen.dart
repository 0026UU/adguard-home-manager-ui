// ignore_for_file: use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/functions/open_url.dart';
import 'package:adguard_home_manager/functions/copy_clipboard.dart';
import 'package:adguard_home_manager/constants/urls.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/functions/get_filtered_status.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/functions/format_time.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';

class LogDetailsScreen extends StatelessWidget {
  final Log log;
  final bool dialog;
  final bool twoColumns;

  const LogDetailsScreen({
    super.key,
    required this.log,
    required this.dialog,
    required this.twoColumns,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final statusProvider = Provider.of<StatusProvider>(context);

    void blockUnblock(String domain, String newStatus) async {
      final ProcessModal processModal = ProcessModal();
      processModal.open(l.savingUserFilters);

      final rules = await statusProvider.blockUnblockDomain(
          domain: domain, newStatus: newStatus);

      processModal.close();

      if (rules == true) {
        showSnackbar(
            appConfigProvider: appConfigProvider,
            label: l.userFilteringRulesUpdated,
            color: Colors.green);
      } else {
        showSnackbar(
            appConfigProvider: appConfigProvider,
            label: l.userFilteringRulesNotUpdated,
            color: Colors.red);
      }
    }

    // Already filtered by a rule, so the action offers to allow it.
    final filtered = getFilteredStatus(
            context, appConfigProvider, log.reason, true)['filtered'] ==
        true;

    final searchAction = IconButton(
      onPressed: () =>
          openUrl("${Urls.googleSearchUrl}?q=${log.question.name}"),
      icon: Icon(CupertinoIcons.globe, color: p.tint),
      tooltip: l.searchDomainInternet,
    );

    final blockAction = IconButton(
      onPressed: log.question.name != null
          ? () =>
              blockUnblock(log.question.name!, filtered ? 'unblock' : 'block')
          : null,
      icon: Icon(
        filtered
            ? CupertinoIcons.checkmark_circle_fill
            : CupertinoIcons.slash_circle_fill,
        color: filtered ? p.green : p.red,
      ),
      tooltip: filtered ? l.unblockDomain : l.blockDomain,
    );

    if (dialog) {
      return AppleFormModal(
        title: l.logDetails,
        icon: CupertinoIcons.doc_text,
        dialog: true,
        maxWidth: 500,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [searchAction, blockAction],
        ),
        body: SingleChildScrollView(child: _Content(log: log)),
      );
    }

    return AppleScreen(
      title: l.logDetails,
      // Embedded in a column layout there is no route to go back from.
      leading: twoColumns
          ? null
          : IconButton(
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              icon: Icon(CupertinoIcons.back, color: p.tint, size: 28),
            ),
      actions: [
        searchAction,
        if (statusProvider.filteringStatus != null) blockAction,
        const SizedBox(width: 6),
      ],
      slivers: [
        SliverToBoxAdapter(child: _Content(log: log)),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  final Log log;

  const _Content({
    required this.log,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final statusProvider = Provider.of<StatusProvider>(context);

    final filter =
        getFilteredStatus(context, appConfigProvider, log.reason, true);
    final filtered = filter['filtered'];

    // Same reading as the log rows: blocked red, allowed green, rewrites the
    // accent, anything unknown grey.
    final Color statusColor;
    if (log.reason.startsWith('Rewrite')) {
      statusColor = p.tint;
    } else if (filtered == true) {
      statusColor = p.red;
    } else if (filtered == false) {
      statusColor =
          appConfigProvider.useThemeColorForStatus == true ? p.tint : p.green;
    } else {
      statusColor = p.label3;
    }

    Filter? getList(int id) {
      try {
        return statusProvider.filteringStatus!.filters
            .firstWhere((filter) => filter.id == id, orElse: () {
          return statusProvider.filteringStatus!.whitelistFilters
              .firstWhere((filter) => filter.id == id);
        });
      } catch (_) {
        return null;
      }
    }

    // Only rules whose list is known get a row, like before.
    final ruleRows = <Widget>[];
    for (final rule in log.rules) {
      final list = getList(rule.filterListId);
      if (list == null) {
        continue;
      }
      ruleRows.add(
        AppleListTile(
          title: rule.text,
          icon: CupertinoIcons.doc_text,
          iconColor: statusColor,
          subtitle: list.name,
          showChevron: false,
        ),
      );
    }

    return Column(
      children: [
        AppleListSection(
          title: l.status,
          children: [
            AppleListTile(
              title: l.result,
              icon: CupertinoIcons.shield_lefthalf_fill,
              iconColor: statusColor,
              subtitleWidget: Text(
                filter['label'],
                style:
                    TextStyle(color: statusColor, fontWeight: FontWeight.w600),
              ),
              showChevron: false,
              trailing: log.cached == true
                  ? ApplePill(label: "CACHE", color: p.teal, fontSize: 11)
                  : null,
            ),
            if (log.rule != null)
              AppleListTile(
                title: l.blockingRule,
                icon: CupertinoIcons.list_dash,
                iconColor: statusColor,
                subtitle: log.rule,
                subtitleMaxLines: 4,
                showChevron: false,
              ),
            AppleListTile(
              title: l.date,
              icon: CupertinoIcons.calendar,
              iconColor: p.indigo,
              subtitle: convertTimestampLocalTimezone(log.time, 'dd-MM-yyyy'),
              showChevron: false,
            ),
            AppleListTile(
              title: l.time,
              icon: CupertinoIcons.clock,
              iconColor: p.teal,
              subtitle: convertTimestampLocalTimezone(log.time, 'HH:mm:ss'),
              showChevron: false,
            ),
          ],
        ),
        AppleListSection(
          title: l.request,
          children: [
            if (log.question.name != null)
              AppleListTile(
                title: l.domain,
                icon: CupertinoIcons.globe,
                subtitle: log.question.name,
                onTap: () => copyToClipboard(
                  value: log.question.name!,
                  successMessage: l.domainCopiedClipboard,
                ),
              ),
            AppleListTile(
              title: l.type,
              icon: CupertinoIcons.tag,
              iconColor: p.pink,
              subtitle: log.question.type,
              showChevron: false,
            ),
            AppleListTile(
              title: l.clas,
              icon: CupertinoIcons.cube_box,
              iconColor: p.purple,
              subtitle: log.question.questionClass,
              showChevron: false,
            ),
          ],
        ),
        AppleListSection(
          title: l.response,
          children: [
            if (log.upstream != null && log.upstream != '')
              AppleListTile(
                title: l.dnsServer,
                icon: CupertinoIcons.list_bullet,
                subtitle: log.upstream,
                onTap: () => copyToClipboard(
                  value: log.upstream!,
                  successMessage: l.dnsServerAddressCopied,
                ),
              ),
            AppleListTile(
              title: l.elapsedTime,
              icon: CupertinoIcons.stopwatch,
              iconColor: p.orange,
              subtitle: "${double.parse(log.elapsedMs).toStringAsFixed(2)} ms",
              showChevron: false,
            ),
            if (log.status != null)
              AppleListTile(
                title: l.responseCode,
                icon: CupertinoIcons.doc_plaintext,
                iconColor: p.gray,
                subtitle: log.status,
                showChevron: false,
              ),
          ],
        ),
        AppleListSection(
          title: l.client,
          children: [
            AppleListTile(
              title: l.deviceIp,
              icon: CupertinoIcons.wifi,
              subtitle: log.client,
              onTap: () => copyToClipboard(
                value: log.client,
                successMessage: l.clientIpCopied,
              ),
            ),
            if (log.clientInfo != null && log.clientInfo!.name != '')
              AppleListTile(
                title: l.deviceName,
                icon: CupertinoIcons.person,
                iconColor: p.purple,
                subtitle: log.clientInfo!.name,
                onTap: () => copyToClipboard(
                  value: log.clientInfo!.name,
                  successMessage: l.clientNameCopied,
                ),
              ),
          ],
        ),
        if (ruleRows.isNotEmpty)
          AppleListSection(
            title: l.rules,
            children: ruleRows,
          ),
        if (log.answer.isNotEmpty)
          AppleListSection(
            title: l.answers,
            children: [
              for (final a in log.answer)
                AppleListTile(
                  title: a.value,
                  icon: CupertinoIcons.arrow_down_circle,
                  iconColor: p.green,
                  subtitle: "TTL: ${a.ttl.toString()}",
                  showChevron: false,
                  trailing:
                      ApplePill(label: a.type, color: p.indigo, fontSize: 11),
                ),
            ],
          ),
      ],
    );
  }
}
