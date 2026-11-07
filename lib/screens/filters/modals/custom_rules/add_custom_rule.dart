import 'package:adguard_home_manager/constants/regexps.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/filters/modals/custom_rules/custom_rule_docs.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

enum _BlockingPresets { block, unblock, custom }

class AddCustomRule extends StatefulWidget {
  final void Function(String) onConfirm;
  final bool fullScreen;

  const AddCustomRule({
    super.key,
    required this.onConfirm,
    required this.fullScreen
  });

  @override
  State<AddCustomRule> createState() => _AddCustomRuleState();
}

class _AddCustomRuleState extends State<AddCustomRule> {
  final TextEditingController _domainController = TextEditingController();
  String? _domainError;

  _BlockingPresets _preset = _BlockingPresets.block;

  bool _addImportant = false;

  bool _checkValidValues() {
    if (
      _domainController.text != '' && 
      _domainError == null
    ) {
      return true;
    }
    else {
      return false;
    }
  }

  void validateDomain(String value) {
    if (Regexps.domain.hasMatch(value)) {
      setState(() => _domainError = null);
    }
    else {
      setState(() => _domainError = AppLocalizations.of(context)!.domainNotValid);
    }
    _checkValidValues();
  }

  void _confirm() {
    Navigator.pop(context);
    widget.onConfirm(
      _buildRule(
        domainController: _domainController,
        important: _addImportant,
        preset: _preset
      )
    );
  }
    
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    Widget editor() => _CustomRuleEditor(
      domainController: _domainController,
      domainError: _domainError,
      important: _addImportant,
      preset: _preset,
      setImportant: (v) => setState(() => _addImportant = v),
      setPreset: (v) => setState(() => _preset = v),
      validateDomain: validateDomain
    );

    Widget confirmButton() => IconButton(
      onPressed: _checkValidValues() == true
        ? () => _confirm()
        : null, 
      icon: const Icon(CupertinoIcons.checkmark),
      tooltip: l.confirm,
    );

    if (widget.fullScreen == true) {
      return Dialog.fullscreen(
        child: AppleScreen(
          title: l.addCustomRule,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(CupertinoIcons.xmark, size: 20, color: p.label2),
            tooltip: l.close,
          ),
          actions: [confirmButton()],
          slivers: [
            SliverToBoxAdapter(child: editor()),
          ],
        ),
      );
    }
    else {
      return AppleFormModal(
        title: l.addCustomRule,
        dialog: true,
        maxWidth: 500,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context), 
              icon: Icon(CupertinoIcons.xmark, size: 20, color: p.label2),
              tooltip: l.close,
            ),
            confirmButton(),
          ],
        ),
        body: SingleChildScrollView(
          child: editor(),
        ),
      );
    }
  }
}

class _CustomRuleEditor extends StatelessWidget {
  final TextEditingController domainController;
  final String? domainError;
  final bool important;
  final void Function(bool) setImportant;
  final _BlockingPresets preset;
  final void Function(_BlockingPresets) setPreset;
  final void Function(String) validateDomain;

  const _CustomRuleEditor({
    required this.domainController,
    required this.domainError,
    required this.important,
    required this.setImportant,
    required this.preset,
    required this.setPreset,
    required this.validateDomain,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    return Column(
      children: [
        const SizedBox(height: 20),
        // The preview reads exactly the rule the confirm writes, so it wears
        // the accent in the pill shape the design layer reserves for state.
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6
          ),
          decoration: BoxDecoration(
            color: p.pill(p.tint),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: p.tint
            )
          ),
          child: Text(
            _buildRule(
              domainController: domainController,
              important: important,
              preset: preset,
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.tint,
              fontSize: 15,
              fontWeight: FontWeight.w600
            ),
          )
        ),
        const SizedBox(height: 24),
        AppleTextField(
          label: l.domain,
          controller: domainController,
          icon: CupertinoIcons.link,
          onChanged: validateDomain,
          error: domainError,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppleSegmented(
            labels: [l.block, l.unblock, l.custom],
            selectedIndex: preset.index,
            onChanged: (v) => setPreset(_BlockingPresets.values[v]),
          ),
        ),
        const SizedBox(height: 16),
        AppleListSection(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            AppleListTile(
              title: l.addImportant,
              showChevron: false,
              onTap: () => setImportant(!important),
              trailing: AppleSwitch(
                value: important,
                onChanged: () => setImportant(!important),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const CustomRuleDocs(),
        const SizedBox(height: 20),
      ]
    );
  }
}

 String _buildRule({
  String? value,
  required TextEditingController domainController,
  required _BlockingPresets preset,
  required bool important
}) {
    String rule = "";
    String fieldValue = value ?? domainController.text;
    if (preset == _BlockingPresets.block) {
      rule = "||${fieldValue.trim()}^";
    }
    else if (preset == _BlockingPresets.unblock) {
      rule = "@@||${fieldValue.trim()}^";
    }
    else {
      rule = fieldValue.trim();
    }
    if (important == true) {
      rule = "$rule\$important";
    }
    return rule;
  }
