import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Adds a client or a domain to one of the access control lists.
class AddClientModal extends StatelessWidget {
  final AccessSettingsList type;
  final void Function(String, AccessSettingsList) onConfirm;
  final bool dialog;

  const AddClientModal({
    super.key,
    required this.type,
    required this.onConfirm,
    required this.dialog,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    String title;
    IconData icon;
    Color color;
    switch (type) {
      case AccessSettingsList.allowed:
        title = l.allowClient;
        icon = CupertinoIcons.checkmark_shield;
        color = p.green;
        break;
      case AccessSettingsList.disallowed:
        title = l.disallowClient;
        icon = CupertinoIcons.shield;
        color = p.red;
        break;
      default:
        title = l.disallowedDomains;
        icon = CupertinoIcons.globe;
        color = p.tint;
    }

    return AppleFormModal(
      title: title,
      icon: icon,
      iconColor: color,
      dialog: dialog,
      body: _Content(type: type, onConfirm: onConfirm),
    );
  }
}

class _Content extends StatefulWidget {
  final AccessSettingsList type;
  final void Function(String, AccessSettingsList) onConfirm;

  const _Content({
    required this.type,
    required this.onConfirm,
  });

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  TextEditingController fieldController = TextEditingController();
  bool validData = false;

  void checkValidValues() {
    if (fieldController.text != '') {
      setState(() => validData = true);
    } else {
      setState(() => validData = false);
    }
  }

  @override
  void dispose() {
    fieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isClient = widget.type == AccessSettingsList.allowed ||
        widget.type == AccessSettingsList.disallowed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextFormField(
                controller: fieldController,
                style: AppleInput.style(context),
                onChanged: (_) => checkValidValues(),
                decoration: AppleInput.decoration(
                  context,
                  icon: CupertinoIcons.globe,
                  label: isClient ? l.clientIdentifier : l.domain,
                  helper: isClient ? l.addClientFieldDescription : null,
                ),
              ),
            ),
          ),
        ),
        AppleFormFooter(
          confirmLabel: l.confirm,
          confirmEnabled: validData,
          onConfirm: () {
            Navigator.pop(context);
            widget.onConfirm(fieldController.text, widget.type);
          },
        ),
      ],
    );
  }
}
