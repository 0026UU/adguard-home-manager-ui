import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:adguard_home_manager/screens/clients/client/client_rules_modal.dart';
import 'package:adguard_home_manager/screens/clients/client/client_screen.dart';
import 'package:adguard_home_manager/screens/clients/client/remove_client_modal.dart';
import 'package:adguard_home_manager/screens/clients/client/safe_search_modal.dart';
import 'package:adguard_home_manager/screens/clients/client/services_modal.dart';
import 'package:adguard_home_manager/screens/clients/client/tags_modal.dart';

import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/models/safe_search.dart';

void openTagsModal({
  required BuildContext context,
  required List<String> selectedTags,
  required void Function(List<String>) onSelectedTags
}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (context) => TagsModal(
      selectedTags: selectedTags,
      tags: Provider.of<ClientsProvider>(context, listen: false).clients!.supportedTags,
      onConfirm: onSelectedTags,
    )
  );
}

void openClientRulesModal({
  required BuildContext context,
  required List<String> rules,
  required void Function(List<String>) onRules
}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (context) => ClientRulesModal(
      rules: rules,
      onConfirm: onRules,
    )
  );
}

void openServicesModal({
  required BuildContext context,
  required List<String> blockedServices,
  required void Function(List<String>) onUpdateBlockedServices
}) {
  final width = MediaQuery.of(context).size.width;
  final asDialog = width > 700 || !(Platform.isAndroid || Platform.isIOS);

  if (asDialog) {
    showDialog<void>(
      context: context,
      builder: (context) => ServicesModal(
        dialog: true,
        blockedServices: blockedServices,
        onConfirm: onUpdateBlockedServices,
      )
    );
  } else {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ServicesModal(
        dialog: false,
        blockedServices: blockedServices,
        onConfirm: onUpdateBlockedServices,
      )
    );
  }
}

void openDeleteClientScreen({
  required BuildContext context,
  required void Function() onDelete
}) {
  showDialog(
    context: context, 
    builder: (ctx) => RemoveClientModal(
      onConfirm: () {
        // The alert's own button has already dismissed this dialog. Popping
        // again here would destroy the page that asked for the deletion before
        // the server had been touched, so the caller keeps the only pop it
        // needs: the one it makes once the entry really is gone.
        onDelete();
      }
    )
  );
}

void openSafeSearchModal({
  required BuildContext context,
  required void Function(SafeSearch) onUpdateSafeSearch,
  required SafeSearch? safeSearch,
  required SafeSearch defaultSafeSearch
}) {
  final width = MediaQuery.of(context).size.width;
  final asDialog = width > 700 || !(Platform.isAndroid || Platform.isIOS);
  final settings = safeSearch ?? defaultSafeSearch;

  if (asDialog) {
    showDialog<void>(
      context: context,
      builder: (context) => SafeSearchModal(
        dialog: true,
        safeSearch: settings,
        onConfirm: onUpdateSafeSearch,
      )
    );
  } else {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeSearchModal(
        dialog: false,
        safeSearch: settings,
        onConfirm: onUpdateSafeSearch,
      )
    );
  }
}

void openClientFormModal({
  required BuildContext context,
  required double width,
  Client? client,
  required void Function(Client) onConfirm,
  void Function(Client)? onDelete,
  ClientInitialData? initialData,
}) {
  showGeneralDialog(
    context: context, 
    barrierColor: !(width > 900 || !(Platform.isAndroid | Platform.isIOS))
      ?Colors.transparent 
      : const Color(0x66000000),
    transitionBuilder: (context, anim1, anim2, child) {
      return SlideTransition(
        position: Tween(
          begin: const Offset(0, 1), 
          end: const Offset(0, 0)
        ).animate(
          CurvedAnimation(
            parent: anim1, 
            curve: Curves.easeInOutCubicEmphasized
          )
        ),
        child: child,
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) => ClientScreen(
      fullScreen: !(width > 900 || !(Platform.isAndroid | Platform.isIOS)),
      client: client,
      onConfirm: onConfirm,
      onDelete: onDelete,
      initialData: initialData,
    ),
  );
}

bool validateNumber(String value) {
  if (value == "") return true;
  final regexp = RegExp(r'^\d+$');
  return regexp.hasMatch(value);
}