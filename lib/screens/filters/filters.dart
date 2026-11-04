// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/filters/filters_page.dart';
import 'package:adguard_home_manager/screens/filters/filters_triple_column.dart';
import 'package:adguard_home_manager/screens/filters/details/list_details_screen.dart';
import 'package:adguard_home_manager/screens/filters/modals/remove_custom_rule_modal.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/screens/filters/add_button.dart';
import 'package:adguard_home_manager/constants/enums.dart';

class Filters extends StatefulWidget {
  const Filters({super.key});

  @override
  State<Filters> createState() => _FiltersState();
}

class _FiltersState extends State<Filters> {
  @override
  void initState() {
    final filteringProvider = Provider.of<FilteringProvider>(context, listen: false);
    filteringProvider.fetchFilters(showLoading: true);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final filteringProvider = Provider.of<FilteringProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final width = MediaQuery.of(context).size.width;
    final palette = ApplePalette.of(context);

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

    // The navigation bar carries the one action the page has: adding a list,
    // the same flow the header of the filter lists opens.
    List<Widget> actions() {
      if (filteringProvider.loadStatus != LoadStatus.loaded) {
        return [];
      }

      return [
        AddFiltersButton(
          type: 'blacklist',
          widget: (onAdd) => IconButton(
            onPressed: onAdd,
            icon: const Icon(CupertinoIcons.plus),
            tooltip: AppLocalizations.of(context)!.addList,
          ),
        ),
        const SizedBox(width: 8),
      ];
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return FiltersTripleColumn(
            onRemoveCustomRule: openRemoveCustomRuleModal,
            onOpenDetailsModal: openListDetails,
          );
        }
        else {
          return FiltersPage(
            actions: actions(),
            onOpenDetailsModal: openListDetails,
          );
        }
      },
    );
  }
}