import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
              child: Wrap(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: macController,
                      style: AppleInput.style(context),
                      onChanged: validateMac,
                      decoration: AppleInput.decoration(
                        context,
                        icon: CupertinoIcons.wifi,
                        error: macError,
                        label: AppLocalizations.of(context)!.macAddress,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: TextFormField(
                      controller: ipController,
                      style: AppleInput.style(context),
                      onChanged: validateIp,
                      decoration: AppleInput.decoration(
                        context,
                        icon: CupertinoIcons.globe,
                        error: ipError,
                        label: AppLocalizations.of(context)!.ipAddress,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextFormField(
                      controller: hostNameController,
                      style: AppleInput.style(context),
                      onChanged: (value) {
                        if (value != '') {
                          setState(() => hostNameError = null);
                        } else {
                          setState(() => hostNameError =
                              AppLocalizations.of(context)!.hostNameError);
                        }
                        validateData();
                      },
                      decoration: AppleInput.decoration(
                        context,
                        icon: CupertinoIcons.person,
                        error: hostNameError,
                        label: AppLocalizations.of(context)!.hostName,
                      ),
                    ),
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
