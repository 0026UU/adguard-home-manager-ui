// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/filters/details/add_list_modal.dart';
import 'package:adguard_home_manager/screens/filters/modals/delete_list_modal.dart';

import 'package:adguard_home_manager/functions/open_url.dart';
import 'package:adguard_home_manager/functions/format_time.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/models/filtering.dart';

/// What one filter list is and what can be done to it.
///
/// The same screen reaches the user two ways: as a card on the wide filter
/// page, where it closes with the button that opened the other Apple modals,
/// and as its own screen on a phone, where the bar carries the actions and the
/// group of rows scrolls under a large title.
class ListDetailsScreen extends StatefulWidget {
  final int listId;
  final String type;
  final bool dialog;

  const ListDetailsScreen({
    super.key,
    required this.listId,
    required this.type,
    required this.dialog
  });

  @override
  State<ListDetailsScreen> createState() => _ListDetailsScreenState();
}

class _ListDetailsScreenState extends State<ListDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final filteringProvider = Provider.of<FilteringProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    Filter? list;
    try {
      list = filteringProvider.filtering != null
        ? widget.type == 'whitelist'
          ? filteringProvider.filtering!.whitelistFilters.firstWhere((l) => l.id == widget.listId)
          : filteringProvider.filtering!.filters.firstWhere((l) => l.id == widget.listId)
        : null;
    } catch (e) {
      // ------- //
    }

    void updateList({
      required FilteringListActions action,
      required Filter filterList,
    }) async {
      ProcessModal processModal = ProcessModal();
      processModal.open(
        action == FilteringListActions.edit
          ? l.savingList
          : action == FilteringListActions.disable 
            ? l.disablingList
            : l.enablingList,
      );
      final result = await filteringProvider.updateList(
        list: filterList, 
        type: widget.type, 
        action: action
      );
      processModal.close();
      if (result == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.listDataUpdated, 
          color: p.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.listDataNotUpdated, 
          color: p.red
        );
      }
    }

    // Turning a list off is the ordinary action of this screen, so it lives on
    // the bar both ways: as the last button of the card's header row, and as
    // the action of the pushed screen. The glyph says which way it moves.
    Widget toggleAction(Filter list) => IconButton(
      onPressed: () => updateList(
        action: list.enabled == true
          ? FilteringListActions.disable
          : FilteringListActions.enable,
        filterList: list,
      ),
      icon: Icon(
        list.enabled == true
          ? CupertinoIcons.shield_slash
          : CupertinoIcons.checkmark_shield,
        color: list.enabled == true ? p.label3 : p.green,
      ),
      tooltip: list.enabled == true ? l.disableList : l.enableList,
    );

    Widget closeAction() => IconButton(
      onPressed: () => Navigator.pop(context),
      padding: EdgeInsets.zero,
      tooltip: l.close,
      icon: Icon(
        CupertinoIcons.xmark_circle_fill,
        size: 22,
        color: p.label3,
      ),
    );

    final actions = <Widget>[
      if (list != null) ...[
        toggleAction(list),
        _Actions(
          list: list, 
          type: widget.type, 
          updateList: (action, filterList) => updateList(action: action, filterList: filterList),
        ),
      ],
      closeAction(),
    ];

    if (widget.dialog == true) {
      return AppleFormModal(
        title: l.listDetails,
        dialog: true,
        maxWidth: 500,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: actions,
        ),
        body: list != null
          ? SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _Content(
                isDialog: widget.dialog,
                list: list,
                type: widget.type,
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              child: Text(
                l.listNotAvailable,
                style: TextStyle(fontSize: 17, color: p.label2),
              ),
            ),
      );
    }
    else {
      return AppleScreen(
        title: l.listDetails,
        leading: AppleBackButton(
          label: l.back,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (list != null) ...[
            toggleAction(list),
            _Actions(
              list: list, 
              type: widget.type, 
              updateList: (action, filterList) => updateList(action: action, filterList: filterList),
            ),
          ],
        ],
        slivers: [
          if (list != null)
            SliverToBoxAdapter(
              child: _Content(
                isDialog: widget.dialog,
                list: list,
                type: widget.type,
              ),
            ),
          if (list == null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppleEmptyState(
                icon: CupertinoIcons.exclamationmark_triangle,
                title: l.listNotAvailable,
                color: p.red,
              ),
            ),
        ],
      );
    }
  }
}

/// The record the server keeps for one list, as the group of rows the design
/// layer reads a record from.
class _Content extends StatelessWidget {
  final Filter list;
  final bool isDialog;
  final String type;

  const _Content({
    required this.list,
    required this.isDialog,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    // The colour of a list that does nothing is a statement of state, so it
    // comes from the palette unless the user asked the theme to carry it.
    final statusColor = list.enabled == true
      ? (appConfigProvider.useThemeColorForStatus == true
        ? p.tint
        : p.green)
      : (appConfigProvider.useThemeColorForStatus == true
        ? p.label3
        : p.red);

    return AppleListSection(
      margin: isDialog == true
        ? EdgeInsets.zero
        : const EdgeInsets.fromLTRB(16, 20, 16, 0),
      children: [
        AppleListTile(
          icon: CupertinoIcons.power,
          iconColor: statusColor,
          title: l.currentStatus,
          value: list.enabled == true ? l.enabled : l.disabled,
          valueColor: statusColor,
          showChevron: false,
        ),
        AppleListTile(
          icon: CupertinoIcons.text_badge_checkmark,
          title: l.name,
          subtitle: list.name,
          showChevron: false,
        ),
        AppleListTile(
          icon: CupertinoIcons.link,
          title: "URL",
          subtitle: list.url,
          mono: true,
          showChevron: false,
          trailing: IconButton(
            onPressed: () => openUrl(list.url), 
            icon: const Icon(CupertinoIcons.arrow_up_right),
            tooltip: l.openListUrl,
          ),
        ),
        AppleListTile(
          icon: CupertinoIcons.list_bullet,
          title: l.rules,
          value: list.rulesCount.toString(),
          showChevron: false,
        ),
        AppleListTile(
          icon: CupertinoIcons.shield_fill,
          title: l.listType,
          subtitle: type == 'whitelist' ? l.whitelist : l.blacklist,
          showChevron: false,
        ),
        if (list.lastUpdated != null)
          AppleListTile(
            icon: CupertinoIcons.clock_fill,
            title: l.latestUpdate,
            subtitle: convertTimestampLocalTimezone(list.lastUpdated!, 'dd-MM-yyyy HH:mm'),
            showChevron: false,
          ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  final Filter? list;
  final String type;
  final void Function(FilteringListActions, Filter) updateList;

  const _Actions({
    required this.list,
    required this.type,
    required this.updateList,
  });

  @override
  Widget build(BuildContext context) {
    final filteringProvider = Provider.of<FilteringProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final width = MediaQuery.of(context).size.width;
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => {
            if (width > 700 || !(Platform.isAndroid || Platform.isIOS)) {
              showDialog(
                context: context, 
                builder: (ctx) => AddListModal(
                  list: list,
                  type: type,
                  onEdit: ({required Filter list, required String type}) async => updateList(FilteringListActions.edit, list),
                  dialog: true,
                ),
              )
            }
            else {
              showModalBottomSheet(
                context: context, 
                useRootNavigator: true,
                builder: (ctx) => AddListModal(
                  list: list,
                  type: type,
                  onEdit: ({required Filter list, required String type}) async => updateList(FilteringListActions.edit, list),
                  dialog: false,
                ),
                isScrollControlled: true,
                backgroundColor: Colors.transparent
              )
            }
          }, 
          icon: const Icon(CupertinoIcons.pencil),
          color: p.tint,
          tooltip: l.edit,
        ),
        IconButton(
          onPressed: () {
            showDialog(
              context: context, 
              builder: (c) => DeleteListModal(
                onConfirm: () async {
                  ProcessModal processModal = ProcessModal();
                  processModal.open(l.deletingList);
                  final result = await filteringProvider.deleteList(
                    listUrl: list!.url, 
                    type: type,
                  );
                  processModal.close();
                  if (result == true) {
                    showSnackbar(
                      appConfigProvider: appConfigProvider,
                      label: l.listDeleted, 
                      color: p.green
                    );
                    Navigator.pop(context);
                  }
                  else {
                    showSnackbar(
                      appConfigProvider: appConfigProvider,
                      label: l.listNotDeleted, 
                      color: p.red
                    );
                  }
                }
              )
            );
          }, 
          // Deleting a list takes the file and every rule read from it, so the
          // control says so in the colour the layer reserves for it.
          icon: const Icon(CupertinoIcons.trash),
          color: p.red,
          tooltip: l.delete,
        ),
      ],
    );
  }
}