import 'package:flutter/cupertino.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/constants/regexps.dart';
import 'package:adguard_home_manager/models/dhcp.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Adds a manual DHCP lease for one device.
class AddStaticLeaseModal extends StatelessWidget {
  final void Function(Lease) onConfirm;
  final bool dialog;

  const AddStaticLeaseModal(
      {super.key, required this.onConfirm, required this.dialog});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AppleFormModal(
      title: l.addStaticLease,
      icon: CupertinoIcons.desktopcomputer,
      dialog: dialog,
      body: _Content(onConfirm: onConfirm),
    );
  }
}

class _Content extends StatefulWidget {
  final void Function(Lease) onConfirm;

  const _Content({required this.onConfirm});

  @override
  State<_Content> createState() => __ContentState();
}

class __ContentState extends State<_Content> {
  final TextEditingController macController = TextEditingController();
  String? macError;
  final TextEditingController ipController = TextEditingController();
  String? ipError;
  final TextEditingController hostNameController = TextEditingController();
  String? hostNameError;

  bool validData = false;

  void validateMac(String value) {
    if (Regexps.macAddress.hasMatch(value)) {
      setState(() => macError = null);
    } else {
      setState(
          () => macError = AppLocalizations.of(context)!.macAddressNotValid);
    }
    validateData();
  }

  void validateIp(String value) {
    if (Regexps.ipv4Address.hasMatch(value) == true) {
      setState(() => ipError = null);
    } else {
      setState(() => ipError = AppLocalizations.of(context)!.ipNotValid);
    }
    validateData();
  }

  void validateData() {
    if (macController.text != '' &&
        macError == null &&
        ipController.text != '' &&
        ipError == null &&
        hostNameController.text != '' &&
        hostNameError == null) {
      setState(() => validData = true);
    } else {
      setState(() => validData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppleTextField(
                    label: AppLocalizations.of(context)!.macAddress,
                    controller: macController,
                    icon: CupertinoIcons.wifi,
                    error: macError,
                    onChanged: validateMac,
                    padding: const EdgeInsets.only(bottom: 12),
                  ),
                  AppleTextField(
                    label: AppLocalizations.of(context)!.ipAddress,
                    controller: ipController,
                    icon: CupertinoIcons.globe,
                    error: ipError,
                    onChanged: validateIp,
                    padding: const EdgeInsets.only(bottom: 12),
                  ),
                  AppleTextField(
                    label: AppLocalizations.of(context)!.hostName,
                    controller: hostNameController,
                    icon: CupertinoIcons.person,
                    error: hostNameError,
                    padding: const EdgeInsets.only(bottom: 12),
                    onChanged: (value) {
                      if (value != '') {
                        setState(() => hostNameError = null);
                      } else {
                        setState(() => hostNameError =
                            AppLocalizations.of(context)!.hostNameError);
                      }
                      validateData();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        AppleFormFooter(
          confirmLabel: AppLocalizations.of(context)!.confirm,
          confirmEnabled: validData,
          onConfirm: () {
            Navigator.pop(context);
            widget.onConfirm(
              Lease(
                mac: macController.text,
                hostname: hostNameController.text,
                ip: ipController.text,
              ),
            );
          },
        ),
      ],
    );
  }
}
