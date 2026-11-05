import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/constants/regexps.dart';
import 'package:adguard_home_manager/models/rewrite_rules.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Adds or edits a DNS rewrite rule, with a delete action when editing.
class DnsRewriteModal extends StatelessWidget {
  final void Function(RewriteRules newRule, RewriteRules? previousRule)
      onConfirm;
  final bool dialog;
  final RewriteRules? rule;
  final void Function(RewriteRules) onDelete;

  const DnsRewriteModal(
      {super.key,
      required this.onConfirm,
      required this.dialog,
      this.rule,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AppleFormModal(
      title: rule != null ? l.editRewriteRule : l.addDnsRewrite,
      icon: rule != null ? CupertinoIcons.pencil : CupertinoIcons.plus,
      dialog: dialog,
      body: _Content(
        onConfirm: onConfirm,
        onDelete: onDelete,
        rule: rule,
      ),
    );
  }
}

class _Content extends StatefulWidget {
  final void Function(RewriteRules newRule, RewriteRules? previousRule)
      onConfirm;
  final RewriteRules? rule;
  final void Function(RewriteRules) onDelete;

  const _Content({required this.onConfirm, this.rule, required this.onDelete});

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  final TextEditingController domainController = TextEditingController();
  String? domainError;
  final TextEditingController answerController = TextEditingController();

  bool validData = false;

  // The update endpoint rewrites the whole rule, so a form that did not carry
  // the state over would quietly switch a disabled rule back on.
  late bool enabled = widget.rule?.enabled ?? true;

  void validateDomain(String value) {
    if (Regexps.wildcardDomain.hasMatch(value)) {
      setState(() => domainError = null);
    } else {
      setState(
          () => domainError = AppLocalizations.of(context)!.domainNotValid);
    }
    checkValidValues();
  }

  void checkValidValues() {
    if (domainController.text != '' &&
        domainError == null &&
        answerController.text != '') {
      setState(() => validData = true);
    } else {
      setState(() => validData = false);
    }
  }

  @override
  void initState() {
    if (widget.rule != null) {
      domainController.text = widget.rule!.domain;
      answerController.text = widget.rule!.answer;
      validData = true;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    RewriteRules currentRule() => RewriteRules(
          domain: domainController.text,
          answer: answerController.text,
          enabled: enabled,
        );

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
                    controller: domainController,
                    style: AppleInput.style(context),
                    onChanged: validateDomain,
                    decoration: AppleInput.decoration(
                      context,
                      icon: CupertinoIcons.globe,
                      error: domainError,
                      label: l.domain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: answerController,
                    style: AppleInput.style(context),
                    onChanged: (_) => checkValidValues(),
                    decoration: AppleInput.decoration(
                      context,
                      icon: CupertinoIcons.arrow_up_right,
                      label: l.answer,
                    ),
                  ),

                  // `/rewrite/add` ignores the flag, so only an existing rule
                  // can be saved switched off.
                  if (widget.rule != null) ...[
                    const SizedBox(height: 6),
                    AppleSwitchListTile(
                      title: l.enabled,
                      value: enabled,
                      onChanged: (value) => setState(() => enabled = value),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        AppleFormFooter(
          confirmLabel: l.confirm,
          confirmEnabled: validData,
          leading: widget.rule == null
              ? null
              : AppleFormButton(
                  label: l.delete,
                  background: Colors.transparent,
                  foreground: p.red,
                  width: 74,
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDelete(currentRule());
                  },
                ),
          onConfirm: () {
            Navigator.pop(context);
            widget.onConfirm(currentRule(), widget.rule);
          },
        ),
      ],
    );
  }
}
