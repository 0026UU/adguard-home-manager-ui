import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/clients/client/client_screen_functions.dart';
import 'package:adguard_home_manager/screens/clients/client/client_screen.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/options_menu.dart';

import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/functions/copy_clipboard.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/models/menu_option.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/functions/get_filtered_status.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/functions/format_time.dart';

class LogTile extends StatelessWidget {
  final Log log;
  final int length;
  final int index;
  final bool? isLogSelected;
  final void Function(Log) onLogTap;
  final bool? useAlwaysNormalTile;
  final bool twoColumns;

  const LogTile({
    super.key,
    required this.log,
    required this.length,
    required this.index,
    this.isLogSelected,
    required this.onLogTap,
    this.useAlwaysNormalTile,
    required this.twoColumns,
  });

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final statusProvider = Provider.of<StatusProvider>(context);
    final clientsProvider = Provider.of<ClientsProvider>(context);
    final filteringProvider = Provider.of<FilteringProvider>(context);

    final localizations = AppLocalizations.of(context)!;
    final palette = ApplePalette.of(context);

    String logClient() {
      if (appConfigProvider.showIpLogs == true) {
        return log.client;
      }
      else if (log.clientInfo != null && log.clientInfo!.name != "") {
        return log.clientInfo!.name;
      }
      else {
        return log.client;
      }
    }

    Widget statusPill() {
      final filter = getFilteredStatus(context, appConfigProvider, log.reason, false);
      final filtered = filter['filtered'];

      final Color color;
      if (log.reason.startsWith('Rewrite')) {
        color = palette.tint;
      }
      else if (filtered == true) {
        color = palette.red;
      }
      else if (filtered == false) {
        color = appConfigProvider.useThemeColorForStatus == true
          ? palette.tint
          : palette.green;
      }
      else {
        color = palette.label3;
      }

      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 170),
        child: ApplePill(
          label: filter['label'] as String,
          color: color,
          fontSize: 11,
        ),
      );
    }

    void blockUnblock({required String domain, required String newStatus}) async {
      if (!context.mounted) return;
      
      final ProcessModal processModal = ProcessModal();
      processModal.open(localizations.savingUserFilters);

      final rules = await statusProvider.blockUnblockDomain(
        domain: domain,
        newStatus: newStatus
      );

      processModal.close();

      if (!context.mounted) return;
      if (rules == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider, 
          label: localizations.userFilteringRulesUpdated, 
          color: Colors.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider, 
          label: localizations.userFilteringRulesNotUpdated, 
          color: Colors.red
        );
      }
    }

    void confirmAddClient(Client client) async {
      if (!context.mounted) return;

      ProcessModal processModal = ProcessModal();
      processModal.open(localizations.addingClient);
      
      final result = await clientsProvider.addClient(client);
      
      processModal.close();

      if (!context.mounted) return;

      if (result == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: localizations.clientAddedSuccessfully, 
          color: Colors.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: localizations.clientNotAdded, 
          color: Colors.red
        );
      }
    }

    void blockUnblockRuleClient() async {
      if (!context.mounted) return;

      ProcessModal processModal = ProcessModal();
      processModal.open(localizations.addingRule);

      final rule = isDomainBlocked(log.reason) == true
        ? "@@||${log.question.name}^\$client='${log.client}'"
        : "||${log.question.name}^\$client='${log.client}'";

      final result = await filteringProvider.addCustomRule(rule);

      processModal.close();

      if (!context.mounted) return;
      if (result == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: isDomainBlocked(log.reason) == true 
            ? localizations.domainUnblockedThisClient(log.question.name!)
            : localizations.domainBlockedThisClient(log.question.name!), 
          color: Colors.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: localizations.ruleNotAdded, 
          color: Colors.red
        );
      }
    }

    void allowDisallowClient() async {
      ProcessModal processModal = ProcessModal();
      processModal.open(
        log.clientInfo!.disallowed == true 
          ? localizations.allowingClient
          : localizations.disallowingClient
      );

      final result = await clientsProvider.addClientList(
        log.client, 
        log.clientInfo!.disallowed == true
          ? AccessSettingsList.allowed
          : AccessSettingsList.disallowed
      );

      processModal.close();
      
      if (!context.mounted) return;
      if (result.successful == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: localizations.clientAddedSuccessfully, 
          color: Colors.green
        );
      }
      else if (result.successful == false && result.content == 'client_another_list') {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: localizations.clientAnotherList, 
          color: Colors.red
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: localizations.changesNotSaved,
          color: Colors.red
        );
      }
    }

    void openAddClient() {
      Future.delayed(
        const Duration(milliseconds: 0), 
        () {
          if (!context.mounted) return;
          openClientFormModal(
            context: context, 
            width: MediaQuery.of(context).size.width, 
            onConfirm: confirmAddClient,
            initialData: ClientInitialData(name:  "Client ${log.client}", ip: log.client)
          );
        }
      );
    }

    final domainBlocked = isDomainBlocked(log.reason);
    final blockToggleIcon = domainBlocked == true
      ? CupertinoIcons.checkmark_circle
      : CupertinoIcons.minus_circle;

    final tile = AppleLogRow(
      leading: statusPill(),
      title: log.question.name ?? localizations.notAvailable,
      time: convertTimestampLocalTimezone(log.time, 'HH:mm:ss'),
      details: [
        logClient(),
        if (appConfigProvider.showTimeLogs == true && log.elapsedMs != '')
          "${double.parse(log.elapsedMs).toStringAsFixed(2)} ms",
      ],
      selected: isLogSelected == true,
      onTap: () => onLogTap(log),
    );

    return OptionsMenu(
      options: (_) => [
        if (log.question.name != null) MenuOption(
          title: domainBlocked == true
            ? localizations.unblockDomain
            : localizations.blockDomain,
          icon: blockToggleIcon,
          action: () => blockUnblock(
            domain: log.question.name!, 
            newStatus: domainBlocked == true ? 'unblock' : 'block'
          )
        ),
        if (filteringProvider.filtering != null) MenuOption(
          title: domainBlocked == true 
            ? localizations.unblockThisClientOnly
            : localizations.blockThisClientOnly,
          icon: blockToggleIcon,
          action: blockUnblockRuleClient
        ),
        if (log.clientInfo?.name == "") MenuOption(
          title: localizations.addPersistentClient,
          icon: CupertinoIcons.person_add,
          action: openAddClient
        ),
        MenuOption(
          title: log.clientInfo!.disallowed == true
            ? localizations.allowThisClient
            : localizations.disallowThisClient,
          icon: log.clientInfo!.disallowed == true
            ? CupertinoIcons.checkmark_circle
            : CupertinoIcons.minus_circle,
          action: allowDisallowClient
        ),
        if (log.question.name != null) MenuOption(
          title: localizations.copyClipboard,
          icon: CupertinoIcons.doc_on_clipboard, 
          action: () => copyToClipboard(
            value: log.question.name!, 
            successMessage: localizations.copiedClipboard
          )
        )
      ],
      child: Column(
        children: [
          tile,
          if (index != length - 1)
            const AppleSeparator(
              indent: AppleLogRow.separatorInset,
              endIndent: AppleLogRow.separatorInset,
            ),
        ],
      ),
    );
  }
}
