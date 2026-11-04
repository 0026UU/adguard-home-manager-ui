import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/constants/regexps.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Adds or edits a filter list, gated by whether it is a whitelist.
class AddListModal extends StatelessWidget {
  final String type;
  final Filter? list;
  final void Function(
      {required String name,
      required String url,
      required String type})? onConfirm;
  final void Function({required Filter list, required String type})? onEdit;
  final bool dialog;

  const AddListModal(
      {super.key,
      required this.type,
      this.list,
      this.onConfirm,
      this.onEdit,
      required this.dialog});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final isWhitelist = type == 'whitelist';

    final String title;
    if (list != null) {
      title = isWhitelist ? l.editWhitelist : l.editBlacklist;
    } else {
      title = isWhitelist ? l.addWhitelist : l.addBlacklist;
    }

    return AppleFormModal(
      title: title,
      icon:
          isWhitelist ? CupertinoIcons.checkmark_shield : CupertinoIcons.shield,
      iconColor: isWhitelist ? p.green : p.red,
      dialog: dialog,
      body: _Content(
        list: list,
        onConfirm: onConfirm,
        onEdit: onEdit,
        type: type,
      ),
    );
  }
}

class _Content extends StatefulWidget {
  final String type;
  final Filter? list;
  final void Function(
      {required String name,
      required String url,
      required String type})? onConfirm;
  final void Function({required Filter list, required String type})? onEdit;

  const _Content({
    required this.type,
    required this.list,
    required this.onConfirm,
    required this.onEdit,
  });

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController urlController = TextEditingController();
  String? urlError;

  bool validData = false;

  void checkValidValues() {
    if (nameController.text != '' && urlController.text != '') {
      setState(() => validData = true);
    } else {
      setState(() => validData = false);
    }
  }

  void validateUrl(String value) {
    if (Regexps.url.hasMatch(value)) {
      setState(() => urlError = null);
    } else {
      final pathRegex = RegExp(
          r'^(((\\|\/)[a-z0-9^&@{}\[\],$=!\-#\(\)%\.\+~_]+)*(\\|\/))([^\\\/:\*\<>\|]+\.[a-z0-9]+)$');
      if (pathRegex.hasMatch(value)) {
        setState(() => urlError = null);
      } else {
        setState(() => urlError = AppLocalizations.of(context)!.urlNotValid);
      }
    }
  }

  @override
  void initState() {
    if (widget.list != null) {
      nameController.text = widget.list!.name;
      urlController.text = widget.list!.url;

      validData = true;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  TextFormField(
                    controller: nameController,
                    style: AppleInput.style(context),
                    onChanged: (_) => checkValidValues(),
                    decoration: AppleInput.decoration(
                      context,
                      icon: CupertinoIcons.textformat,
                      label: l.name,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: urlController,
                    style: AppleInput.style(context),
                    onChanged: validateUrl,
                    enabled: widget.list == null,
                    decoration: AppleInput.decoration(
                      context,
                      icon: CupertinoIcons.globe,
                      error: urlError,
                      label: l.urlAbsolutePath,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AppleFormFooter(
          confirmLabel: widget.list != null ? l.save : l.confirm,
          onConfirm: () {
            Navigator.pop(context);
            if (widget.list != null) {
              final Filter newList = Filter(
                  url: urlController.text,
                  name: nameController.text,
                  lastUpdated: widget.list!.lastUpdated,
                  id: widget.list!.id,
                  rulesCount: widget.list!.rulesCount,
                  enabled: widget.list!.enabled);
              widget.onEdit!(list: newList, type: widget.type);
            } else {
              widget.onConfirm!(
                  name: nameController.text,
                  url: urlController.text,
                  type: widget.type);
            }
          },
        ),
      ],
    );
  }
}
