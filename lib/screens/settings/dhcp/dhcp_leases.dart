// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/settings/dhcp/delete_static_lease_modal.dart';
import 'package:adguard_home_manager/screens/settings/dhcp/add_static_lease_modal.dart';

import 'package:adguard_home_manager/providers/dhcp_provider.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/models/dhcp.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

class DhcpLeases extends StatelessWidget {
  final List<Lease> items;
  final bool staticLeases;

  const DhcpLeases({
    super.key,
    required this.items,
    required this.staticLeases,
  });

  @override
  Widget build(BuildContext context) {
    final dhcpProvider = Provider.of<DhcpProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    final width = MediaQuery.of(context).size.width;

    void deleteLease(Lease lease) async {
      ProcessModal processModal = ProcessModal();
      processModal.open(AppLocalizations.of(context)!.deleting);

      final result = await dhcpProvider.deleteLease(lease);

      processModal.close();

      if (result == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.staticLeaseDeleted, 
          color: Colors.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.staticLeaseNotDeleted, 
          color: Colors.red
        );
      }
    }

    void createLease(Lease lease) async {
      ProcessModal processModal = ProcessModal();
      processModal.open(AppLocalizations.of(context)!.creating);

      final result = await dhcpProvider.createLease(lease);

      processModal.close();

      if (result.successful == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.staticLeaseCreated, 
          color: Colors.green
        );
      }
      else if (result.successful == false && result.content == "already_exists") {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.staticLeaseExists, 
          color: Colors.red
        );
      }
      else if (result.successful == false && result.content == "server_not_configured") {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.serverNotConfigured, 
          color: Colors.red
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.staticLeaseNotCreated, 
          color: Colors.red
        );
      }
    }

    void openAddStaticLease() {
      if (width > 900 || !(Platform.isAndroid || Platform.isIOS)) {
        showDialog(
          context: context, 
          builder: (context) => AddStaticLeaseModal(
            onConfirm: createLease,
            dialog: true,
          ),
        );
      }
      else {
        showModalBottomSheet(
          context: context, 
          useRootNavigator: true,
          builder: (context) => AddStaticLeaseModal(
            onConfirm: createLease,
            dialog: false,
          ),
          backgroundColor: Colors.transparent,
          isScrollControlled: true
        );
      }
    }

    Widget leaseTile(Lease lease) => AppleListTile(
      title: lease.ip,
      subtitle: lease.hostname == ''
        ? lease.mac
        : "${lease.mac}\n${lease.hostname}",
      subtitleMaxLines: 2,
      icon: CupertinoIcons.desktopcomputer,
      iconColor: staticLeases == true ? p.indigo : p.tint,
      trailing: staticLeases == true
        ? IconButton(
            onPressed: () => showDialog(
              context: context,
              builder: (context) => DeleteStaticLeaseModal(
                onConfirm: () => deleteLease(lease)
              ),
            ),
            tooltip: l.deleteStaticLease,
            icon: Icon(CupertinoIcons.trash, color: p.red),
          )
        : null,
    );

    return AppleScreen(
      title: staticLeases == true ? l.dhcpStatic : l.dhcpLeases,
      floatingActionButton: staticLeases == true
        ? FloatingActionButton(
            onPressed: openAddStaticLease,
            backgroundColor: p.tint,
            foregroundColor: Colors.white,
            child: const Icon(CupertinoIcons.plus),
          )
        : null,
      slivers: items.isEmpty
        ? [
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppleEmptyState(
                icon: CupertinoIcons.list_bullet,
                title: staticLeases == true ? l.noDhcpStaticLeases : l.noLeases,
              ),
            ),
          ]
        : [
            SliverToBoxAdapter(
              child: AppleListSection(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                children: items.map(leaseTile).toList(),
              ),
            ),
          ],
    );
  }
}
