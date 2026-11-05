// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:adguard_home_manager/constants/regexps.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/screens/settings/settings.dart';
import 'package:adguard_home_manager/screens/settings/dhcp/dhcp_not_available.dart';
import 'package:adguard_home_manager/widgets/confirm_action_modal.dart';
import 'package:adguard_home_manager/screens/settings/dhcp/dhcp_main_button.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/screens/settings/dhcp/dhcp_leases.dart';
import 'package:adguard_home_manager/screens/settings/dhcp/select_interface_modal.dart';

import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/dhcp_provider.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/models/dhcp.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';

class DhcpScreen extends StatefulWidget {
  const DhcpScreen({super.key});

  @override
  State<DhcpScreen> createState() => _DhcpScreenState();
}

class _DhcpScreenState extends State<DhcpScreen> {
  NetworkInterface? selectedInterface;

  bool enabled = false;

  final TextEditingController ipv4StartRangeController = TextEditingController();
  String? ipv4StartRangeError;
  final TextEditingController ipv4EndRangeController = TextEditingController();
  String? ipv4EndRangeError;
  final TextEditingController ipv4SubnetMaskController = TextEditingController();
  String? ipv4SubnetMaskError;
  final TextEditingController ipv4GatewayController = TextEditingController();
  String? ipv4GatewayError;
  final TextEditingController ipv4LeaseTimeController = TextEditingController();
  String? ipv4LeaseTimeError;

  final TextEditingController ipv6StartRangeController = TextEditingController();
  String? ipv6StartRangeError;
  final TextEditingController ipv6EndRangeController = TextEditingController();
  String? ipv6EndRangeError;
  final TextEditingController ipv6LeaseTimeController = TextEditingController();
  String? ipv6LeaseTimeError;

  bool dataValid = false;

  void loadDhcpStatus() async {
    final result = await Provider.of<DhcpProvider>(context, listen: false).loadDhcpStatus();
    if (!mounted || result == false) return;

    final dhcpProvider = Provider.of<DhcpProvider>(context, listen: false);
    if (dhcpProvider.dhcp == null) return;
  
    setState(() {
      if (dhcpProvider.dhcp!.dhcpStatus!.interfaceName != null && dhcpProvider.dhcp!.dhcpStatus!.interfaceName != '') {
        try {selectedInterface = dhcpProvider.dhcp!.networkInterfaces.firstWhere((iface) => iface.name == dhcpProvider.dhcp!.dhcpStatus!.interfaceName);} catch (_) {}
        enabled = dhcpProvider.dhcp!.dhcpStatus!.enabled;
        if (dhcpProvider.dhcp!.dhcpStatus!.v4 != null) {
          ipv4StartRangeController.text = dhcpProvider.dhcp!.dhcpStatus!.v4!.rangeStart;
          ipv4EndRangeController.text = dhcpProvider.dhcp!.dhcpStatus!.v4!.rangeEnd ?? '';
          ipv4SubnetMaskController.text = dhcpProvider.dhcp!.dhcpStatus!.v4!.subnetMask ?? '';
          ipv4GatewayController.text = dhcpProvider.dhcp!.dhcpStatus!.v4!.gatewayIp ?? '';
          ipv4LeaseTimeController.text = dhcpProvider.dhcp!.dhcpStatus!.v4!.leaseDuration.toString();
        }
      }
    });

    checkDataValid();
  }

  void validateIpV4(String value, String errorVar, String errorMessage) {
    void setValue(String? error) {
      switch (errorVar) {
        case 'ipv4StartRangeError':
          setState(() => ipv4StartRangeError = error);
          break;

        case 'ipv4EndRangeError':
          setState(() => ipv4EndRangeError = error);
          break;

        case 'ipv4SubnetMaskError':
          setState(() => ipv4SubnetMaskError = error);
          break;

        case 'ipv4GatewayError':
          setState(() => ipv4GatewayError = error);
          break;
      }
    }

    if (Regexps.ipv4Address.hasMatch(value)) {
      setValue(null);
    }
    else {
      setValue(errorMessage);
    }
    checkDataValid();
  }

  void validateIpV6(String value, String errorVar, String errorMessage) {
    void setValue(String? error) {
      switch (errorVar) {
        case 'ipv6StartRangeError':
          setState(() => ipv4StartRangeError = error);
          break;

        case 'ipv6EndRangeError':
          setState(() => ipv4EndRangeError = error);
          break;

        case 'ipv6GatewayError':
          setState(() => ipv4GatewayError = error);
          break;
      }
    }

    if (Regexps.ipv6Address.hasMatch(value)) {
      setValue(null);
    }
    else {
      setValue(errorMessage);
    }
    checkDataValid();
  }

  bool checkDataValid() {
    if (
      ipv4StartRangeController.text != '' &&
      ipv4StartRangeError == null &&
      ipv4EndRangeController.text != '' &&
      ipv4EndRangeError == null &&
      ipv4SubnetMaskController.text != '' && 
      ipv4SubnetMaskError == null &&
      ipv4GatewayController.text != '' &&
      ipv4GatewayError == null 
    ) {
      return true;
    }
    else {
      return false;
    }
  }

  void clearAll() {
    setState(() {
      selectedInterface = null;
      enabled = false;

      ipv4StartRangeController.text = '';
      ipv4StartRangeError = null;
      ipv4StartRangeController.text = '';
      ipv4EndRangeError = null;
      ipv4EndRangeController.text = '';
      ipv4EndRangeError = null;
      ipv4SubnetMaskController.text = '';
      ipv4SubnetMaskError = null;
      ipv4GatewayController.text = '';
      ipv4GatewayError = null;
      ipv4LeaseTimeController.text = '';
      ipv4LeaseTimeError = null;

      ipv6StartRangeController.text = '';
      ipv6StartRangeError = null;
      ipv6EndRangeController.text = '';
      ipv6EndRangeError = null;
      ipv6LeaseTimeController.text = '';
      ipv6LeaseTimeError = null;
    });
  }

  @override
  void initState() {
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    if (mounted && statusProvider.serverStatus?.dhcpAvailable == true) loadDhcpStatus();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final statusProvider = Provider.of<StatusProvider>(context);
    final dhcpProvider = Provider.of<DhcpProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final width = MediaQuery.of(context).size.width;

    void saveSettings() async {
      ProcessModal processModal = ProcessModal();
      processModal.open(AppLocalizations.of(context)!.savingSettings);
      final result = await serversProvider.apiClient2!.saveDhcpConfig(
        data: {
          "enabled": enabled,
          "interface_name": selectedInterface!.name,
          if (selectedInterface!.ipv4Addresses.isNotEmpty) "v4": {
            "gateway_ip": ipv4GatewayController.text,
            "subnet_mask": ipv4SubnetMaskController.text,
            "range_start": ipv4StartRangeController.text,
            "range_end": ipv4EndRangeController.text,
            "lease_duration": ipv4LeaseTimeController.text != '' ? int.parse(ipv4LeaseTimeController.text) : null
          },
          if (selectedInterface!.ipv6Addresses.isNotEmpty) "v6": {
            "range_start": ipv6StartRangeController.text,
            "range_end": ipv6EndRangeController.text,
            "lease_duration": ipv6LeaseTimeController.text != '' ? int.parse(ipv6LeaseTimeController.text) : null
          }
        }
      );
      if (!mounted) return;
      processModal.close();
      if (result.successful == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.settingsSaved, 
          color: Colors.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.settingsNotSaved, 
          color: Colors.red
        );
      }
    }

    void restoreConfig() async {
      Future.delayed(const Duration(seconds: 0), () async {
        ProcessModal processModal = ProcessModal();
        processModal.open(AppLocalizations.of(context)!.restoringConfig);
        final result = await serversProvider.apiClient2!.resetDhcpConfig();
        if (!mounted) return;
        processModal.close();
        if (result.successful == true) {
          clearAll();
          showSnackbar(
            appConfigProvider: appConfigProvider,
            label: AppLocalizations.of(context)!.configRestored, 
            color: Colors.green
          );
        }
        else {
          showSnackbar(
            appConfigProvider: appConfigProvider,
            label: AppLocalizations.of(context)!.configNotRestored, 
            color: Colors.red
          );
        }
      });
    }

    void restoreLeases() async {
      Future.delayed(const Duration(seconds: 0), () async {
        ProcessModal processModal = ProcessModal();
        processModal.open(AppLocalizations.of(context)!.restoringLeases);

        final result = await serversProvider.apiClient2!.restoreAllLeases();

        processModal.close();

        if (result.successful == true) {
          DhcpModel data = dhcpProvider.dhcp!;
          data.dhcpStatus!.staticLeases = [];
          data.dhcpStatus!.leases = [];
          dhcpProvider.setDhcpData(data);

          showSnackbar(
            appConfigProvider: appConfigProvider,
            label: AppLocalizations.of(context)!.leasesRestored, 
            color: Colors.green
          );
        }
        else {
          showSnackbar(
            appConfigProvider: appConfigProvider,
            label: AppLocalizations.of(context)!.leasesNotRestored, 
            color: Colors.red
          );
        }
      });
    }

    void askRestoreLeases() {
      Future.delayed(const Duration(seconds: 0), () => {
        showDialog(
          context: context, 
          builder: (context) => ConfirmActionModal(
            title: AppLocalizations.of(context)!.restoreLeases,
            message: AppLocalizations.of(context)!.restoreLeasesMessage, 
            onConfirm: () => restoreLeases()
          )
        )
      });
    }

    void askRestoreConfig() {
      Future.delayed(const Duration(seconds: 0), () => {
        showDialog(
          context: context, 
          builder: (context) => ConfirmActionModal(
            title: AppLocalizations.of(context)!.restoreConfiguration,
            message: AppLocalizations.of(context)!.restoreConfigurationMessage,
            onConfirm: () => restoreConfig()
          )
        )
      });
    }

    void selectInterface() {
      ScaffoldMessenger.of(context).clearSnackBars();
      Future.delayed(const Duration(seconds: 0), () {
        if (width > 900 || !(Platform.isAndroid || Platform.isIOS)) {
          showDialog(
            context: context, 
            builder: (context) => SelectInterfaceModal(
              interfaces: dhcpProvider.dhcp!.networkInterfaces, 
              onSelect: (interface) => setState(() {
                clearAll();
                selectedInterface = interface;
              }),
              dialog: true,
            )
          );
        }
        else {
          showModalBottomSheet(
            context: context, 
            useRootNavigator: true,
            builder: (context) => SelectInterfaceModal(
              interfaces: dhcpProvider.dhcp!.networkInterfaces, 
              onSelect: (i) => setState(() {
                clearAll();
                selectedInterface = i;
              }),
              dialog: false,
            ),
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent
          );
        }
      });
    }

    if (statusProvider.serverStatus?.dhcpAvailable != true) {
      return const DhcpNotAvailable();
    }

    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    Widget fill(Widget child) => SliverFillRemaining(
      hasScrollBody: false,
      child: child
    );

    // The lease duration is sent as a plain integer, so anything but a number
    // is refused before the request is made.
    ValueChanged<String> leaseTime(void Function(String? error) setError) =>
      (value) => setState(
        () => setError(
          int.tryParse(value).runtimeType == int ? null : l.leaseTimeNotValid
        )
      );

    void openMenu() => showAppleActionSheet(
      context,
      cancelLabel: l.cancel,
      actions: [
        AppleSheetAction(
          label: l.changeInterface,
          icon: CupertinoIcons.arrow_2_circlepath,
          onTap: selectInterface
        ),
        AppleSheetAction(
          label: l.restoreLeases,
          icon: CupertinoIcons.list_bullet,
          onTap: askRestoreLeases
        ),
        AppleSheetAction(
          label: l.restoreConfiguration,
          icon: CupertinoIcons.gear,
          onTap: askRestoreConfig,
          destructive: true
        ),
      ],
    );

    void openLeases({required bool isStatic}) {
      final leases = isStatic
        ? dhcpProvider.dhcp!.dhcpStatus!.staticLeases
        : dhcpProvider.dhcp!.dhcpStatus!.leases;

      final route = MaterialPageRoute(
        builder: (context) => DhcpLeases(
          items: leases,
          staticLeases: isStatic
        )
      );

      // On a desktop window the settings pane owns its own navigator.
      if (width > 900 && !(Platform.isAndroid || Platform.isIOS)) {
        Navigator.of(settingsNavigatorKey.currentContext!).push(route);
      }
      else {
        Navigator.of(context).push(route);
      }
    }

    List<Widget> content() {
      if (dhcpProvider.loadStatus == LoadStatus.loading) {
        return [fill(AppleLoading(label: l.loadingDhcp))];
      }

      if (dhcpProvider.loadStatus == LoadStatus.error) {
        return [
          fill(
            AppleEmptyState(
              icon: CupertinoIcons.exclamationmark_triangle_fill,
              title: l.dhcpSettingsNotLoaded,
              color: p.red,
            )
          )
        ];
      }

      if (selectedInterface == null) {
        return [
          fill(
            AppleEmptyState(
              icon: CupertinoIcons.antenna_radiowaves_left_right,
              title: l.neededSelectInterface,
              action: SizedBox(
                width: 320,
                child: AppleButton(
                  label: l.selectInterface,
                  onPressed: selectInterface
                ),
              ),
            )
          )
        ];
      }

      return [
        SliverToBoxAdapter(
          child: DhcpMainButton(
            selectedInterface: selectedInterface,
            enabled: enabled,
            setEnabled: (v) => setState(() => enabled = v)
          )
        ),
        if (selectedInterface!.ipv4Addresses.isNotEmpty) ...[
          SliverToBoxAdapter(child: AppleFormGroupLabel(l.ipv4settings)),
          SliverToBoxAdapter(
            child: AppleTextField(
              label: l.startOfRange,
              icon: CupertinoIcons.arrow_left_to_line,
              controller: ipv4StartRangeController,
              error: ipv4StartRangeError,
              keyboardType: TextInputType.number,
              onChanged: (value) => validateIpV4(
                value, 'ipv4StartRangeError', l.ipNotValid
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AppleTextField(
              label: l.endOfRange,
              icon: CupertinoIcons.arrow_right_to_line,
              controller: ipv4EndRangeController,
              error: ipv4EndRangeError,
              keyboardType: TextInputType.number,
              onChanged: (value) => validateIpV4(
                value, 'ipv4EndRangeError', l.ipNotValid
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AppleTextField(
              label: l.subnetMask,
              icon: CupertinoIcons.square_split_2x1_fill,
              controller: ipv4SubnetMaskController,
              error: ipv4SubnetMaskError,
              keyboardType: TextInputType.number,
              onChanged: (value) => validateIpV4(
                value, 'ipv4SubnetMaskError', l.subnetMaskNotValid
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AppleTextField(
              label: l.gateway,
              icon: CupertinoIcons.globe,
              controller: ipv4GatewayController,
              error: ipv4GatewayError,
              keyboardType: TextInputType.number,
              onChanged: (value) => validateIpV4(
                value, 'ipv4GatewayError', l.gatewayNotValid
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AppleTextField(
              label: l.leaseTime,
              icon: CupertinoIcons.timer,
              controller: ipv4LeaseTimeController,
              error: ipv4LeaseTimeError,
              keyboardType: TextInputType.number,
              onChanged: leaseTime((error) => ipv4LeaseTimeError = error),
            ),
          ),
        ],
        if (selectedInterface!.ipv6Addresses.isNotEmpty) ...[
          SliverToBoxAdapter(child: AppleFormGroupLabel(l.ipv6settings)),
          SliverToBoxAdapter(
            child: AppleTextField(
              label: l.startOfRange,
              icon: CupertinoIcons.arrow_left_to_line,
              controller: ipv6StartRangeController,
              error: ipv6StartRangeError,
              keyboardType: TextInputType.number,
              onChanged: (value) => validateIpV6(
                value, 'ipv6StartRangeError', l.ipNotValid
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AppleTextField(
              label: l.endOfRange,
              icon: CupertinoIcons.arrow_right_to_line,
              controller: ipv6EndRangeController,
              error: ipv6EndRangeError,
              keyboardType: TextInputType.number,
              onChanged: (value) => validateIpV6(
                value, 'ipv6EndRangeError', l.ipNotValid
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AppleTextField(
              label: l.leaseTime,
              icon: CupertinoIcons.timer,
              controller: ipv6LeaseTimeController,
              error: ipv6LeaseTimeError,
              keyboardType: TextInputType.number,
              onChanged: leaseTime((error) => ipv6LeaseTimeError = error),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: AppleListSection(
              title: l.dhcpLeases,
              children: [
                AppleListTile(
                  title: l.dhcpLeases,
                  icon: CupertinoIcons.list_bullet,
                  onTap: () => openLeases(isStatic: false)
                ),
                AppleListTile(
                  title: l.dhcpStatic,
                  icon: CupertinoIcons.person_2_fill,
                  iconColor: p.indigo,
                  onTap: () => openLeases(isStatic: true)
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return AppleScreen(
      title: l.dhcpSettings,
      actions: selectedInterface != null
        ? [
            IconButton(
              onPressed: checkDataValid() == true
                ? () => saveSettings()
                : null,
              icon: const Icon(CupertinoIcons.checkmark),
              tooltip: l.save,
            ),
            IconButton(
              onPressed: openMenu,
              icon: const Icon(CupertinoIcons.ellipsis),
            ),
            const SizedBox(width: 6),
          ]
        : const [],
      slivers: content(),
    );
  }
}
