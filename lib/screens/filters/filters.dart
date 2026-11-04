// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/filters/details/check_host_modal.dart';
import 'package:adguard_home_manager/screens/filters/filters_tabs_view.dart';
import 'package:adguard_home_manager/screens/filters/filters_triple_column.dart';
import 'package:adguard_home_manager/screens/filters/details/list_details_screen.dart';
import 'package:adguard_home_manager/screens/filters/modals/remove_custom_rule_modal.dart';
import 'package:adguard_home_manager/screens/filters/modals/blocked_services_screen.dart';
import 'package:adguard_home_manager/screens/filters/modals/update_interval_lists_modal.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/models/clients.dart';

class Filters extends StatefulWidget {
  const Filters({super.key});

  @override
  State<Filters> createState() => _FiltersState();
}

class _FiltersState extends State<Filters> {
  List<AutoClient> generateClientsList(List<AutoClient> clients, List<String> ips) {
    return clients.where((client) => ips.contains(client.ip)).toList();
  }

  @override
  void initState() {
    final filteringProvider = Provider.of<FilteringProvider>(context, listen: false);
    filteringProvider.fetchFilters(showLoading: true);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final filteringProvider = Provider.of<FilteringProvider>(context);
    final statusProvider = Provider.of<StatusProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final width = MediaQuery.of(context).size.width;
    final palette = ApplePalette.of(context);

    void updateLists() async {
      ProcessModal processModal = ProcessModal();
      processModal.open(AppLocalizations.of(context)!.updatingLists);
      final result = await filteringProvider.updateLists();
      if (!mounted) return;
      processModal.close();
      if (result['success'] == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: "${result['data']['updated']} ${AppLocalizations.of(context)!.listsUpdated}", 
          color: palette.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.listsNotUpdated, 
          color: palette.red
        );
      }
    }

    void showCheckHostModal() {
      Future.delayed(const Duration(seconds: 0), () {
        if (width > 700 || !(Platform.isAndroid || Platform.isIOS)) {
          showDialog(
            context: context, 
            builder: (context) => const CheckHostModal(
              dialog: true,
            ),
          );
        }
        else {
          showModalBottomSheet(
            context: context, 
            useRootNavigator: true,
            builder: (context) => const CheckHostModal(
              dialog: false,
            ),
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
          );
        }
      });
    }

    void enableDisableFiltering() async {
      ProcessModal processModal = ProcessModal();
      processModal.open(
        statusProvider.serverStatus!.filteringEnabled == true
          ? AppLocalizations.of(context)!.disableFiltering
          : AppLocalizations.of(context)!.enableFiltering
      );

      final result = await filteringProvider.enableDisableFiltering();

      processModal.close();

      if (result == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.filteringStatusUpdated, 
          color: palette.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.filteringStatusNotUpdated, 
          color: palette.red
        );
      }
    }

    void setUpdateFrequency(int value) async {
      ProcessModal processModal = ProcessModal();
      processModal.open(AppLocalizations.of(context)!.changingUpdateFrequency);

      final result = await filteringProvider.changeUpdateFrequency(value);

      processModal.close();

      if (result == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.updateFrequencyChanged, 
          color: palette.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.updateFrequencyNotChanged, 
          color: palette.red
        );
      }
    }

    void openBlockedServices() {
      Future.delayed(const Duration(seconds: 0), () {
        openBlockedServicesModal(context: context, width: width);
      });
    }

    void removeCustomRule(String rule) async {
      ProcessModal processModal = ProcessModal();
      processModal.open(AppLocalizations.of(context)!.deletingRule);

      final result = await filteringProvider.removeCustomRule(rule);

      processModal.close();

      if (result == true) {
        showSnackbar( 
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.ruleRemovedSuccessfully, 
          color: palette.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.ruleNotRemoved, 
          color: palette.red
        );  
      }
    }

    void openRemoveCustomRuleModal(String rule) {
      showDialog(
        context: context, 
        builder: (context) => RemoveCustomRule(
          onConfirm: () => removeCustomRule(rule),
        )
      );
    }

    void openListDetails(Filter filter, String type) {
      if (width > 900) {
        showDialog(
          context: context, 
          builder: (context) => ListDetailsScreen(
            listId: filter.id, 
            type: type,
            dialog: width > 900 || !(Platform.isAndroid | Platform.isIOS),
          ),
        );
      }
      else {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => ListDetailsScreen(
            listId: filter.id, 
            type: type,
            dialog: width > 900 || !(Platform.isAndroid | Platform.isIOS),
          ),
        ));
      }
    }

    List<Widget> actions() {
      if (filteringProvider.loadStatus == LoadStatus.loaded) {
        return [
          if (statusProvider.loadStatus == LoadStatus.loaded) IconButton(
            onPressed: enableDisableFiltering, 
            tooltip: filteringProvider.filtering!.enabled == true
              ? AppLocalizations.of(context)!.disableFiltering
              : AppLocalizations.of(context)!.enableFiltering,
            icon: Stack(
              children: [
                const Icon(CupertinoIcons.power),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: palette.chromeSolid
                    ),
                    child: Icon(
                      filteringProvider.filtering!.enabled == true
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.circle,
                      size: 11,
                      color: filteringProvider.filtering!.enabled == true
                        ? appConfigProvider.useThemeColorForStatus == true
                          ? palette.tint
                          : palette.green
                        : appConfigProvider.useThemeColorForStatus == true
                          ? palette.label3
                          : palette.red
                    ),
                  ),
                )
              ],
            )
          ),
          IconButton(
            onPressed: () {
              if (width > 900 || !(Platform.isAndroid || Platform.isIOS)) {
                showDialog(
                  context: context, 
                  builder: (context) => UpdateIntervalListsModal(
                    interval: filteringProvider.filtering!.interval,
                    onChange: setUpdateFrequency,
                    dialog: true,
                  ),
                );
              }
              else {
                showModalBottomSheet(
                  context: context, 
                  useRootNavigator: true,
                  builder: (context) => UpdateIntervalListsModal(
                    interval: filteringProvider.filtering!.interval,
                    onChange: setUpdateFrequency,
                    dialog: false,
                  ),
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true
                );
              }
            }, 
            icon: const Icon(CupertinoIcons.clock),
            tooltip:  AppLocalizations.of(context)!.updateFrequency,
          ),
          PopupMenuButton(
            icon: const Icon(CupertinoIcons.ellipsis),
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: updateLists,
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.arrow_2_circlepath),
                    const SizedBox(width: 10),
                    Text(AppLocalizations.of(context)!.updateLists)
                  ],
                )
              ),
              PopupMenuItem(
                onTap: openBlockedServices,
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.nosign),
                    const SizedBox(width: 10),
                    Text(AppLocalizations.of(context)!.blockedServices)
                  ],
                )
              ),
              PopupMenuItem(
                onTap: showCheckHostModal,
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.shield),
                    const SizedBox(width: 10),
                    Text(AppLocalizations.of(context)!.checkHostFiltered)
                  ],
                )
              ),
            ]
          ),
          const SizedBox(width: 5),
        ];
      }
      else {
        return [];
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return FiltersTripleColumn(
            onRemoveCustomRule: openRemoveCustomRuleModal,
            onOpenDetailsModal: openListDetails,
            actions: actions(),
          );
        }
        else {
          return FiltersTabsView(
            appConfigProvider: appConfigProvider, 
            actions: actions(),
            onRemoveCustomRule: openRemoveCustomRuleModal,
            onOpenDetailsModal: openListDetails,
          );
        }
      },
    );
  }
}