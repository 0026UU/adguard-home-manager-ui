import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// The page the design layer pushes for the local rules: a title, one
/// monospaced field, three templates to insert and the cancel/save pair.
///
/// Saving hands the lines back to the caller, which owns the request and its
/// result message, so this page never talks to the server itself.
class EditCustomRules extends StatefulWidget {
  final void Function(List<String>) onConfirm;

  const EditCustomRules({
    super.key,
    required this.onConfirm,
  });

  @override
  State<EditCustomRules> createState() => _EditCustomRulesState();
}

class _EditCustomRulesState extends State<EditCustomRules> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();

    final rules = Provider.of<FilteringProvider>(context, listen: false)
      .filtering
      ?.userRules;

    _controller.text = rules?.join('\n') ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A template goes in at the caret on a line of its own, so what lands in the
  /// field is a rule rather than the tail of the one being typed.
  void _insert(String template) {
    final l = AppLocalizations.of(context)!;
    final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);

    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : start;
    final prefix = start > 0 && text[start - 1] != '\n' ? '\n' : '';
    final suffix = end < text.length && text[end] != '\n' ? '\n' : '';
    final inserted = '$prefix$template$suffix';

    _controller.value = TextEditingValue(
      text: text.replaceRange(start, end, inserted),
      selection: TextSelection.collapsed(offset: start + inserted.length),
    );

    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: l.templateInserted,
    );
  }

  void _save() {
    // A blank line is spacing, not a rule, and the server keeps a list of them.
    final rules = _controller.text
      .split('\n')
      .map((line) => line.trimRight())
      .where((line) => line.isNotEmpty)
      .toList();

    Navigator.pop(context);
    widget.onConfirm(rules);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AppleScreen(
      title: l.customRules,
      subtitle: l.customRulesEditorHint,
      // The capsule is named after the page behind it, which on a pushed route
      // is the filters tab.
      leading: Navigator.canPop(context)
        ? AppleBackButton(
            label: l.filters,
            onPressed: () => Navigator.pop(context),
          )
        : null,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppleGroupHeader(
                  title: l.rules,
                  trailing: l.adblockSyntax,
                  padding: EdgeInsets.zero,
                ),
                _RulesField(controller: _controller),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: AppleListSection(
            title: l.insert,
            margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
            children: [
              AppleListTile(
                title: '||domain^',
                subtitle: l.templateBlockDomain,
                onTap: () => _insert('||domain^'),
              ),
              AppleListTile(
                title: '@@||domain^',
                subtitle: l.templateAllowDomain,
                onTap: () => _insert('@@||domain^'),
              ),
              AppleListTile(
                title: r'$important',
                subtitle: l.templateImportant,
                onTap: () => _insert(r'$important'),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: AppleFormFooter(
              confirmLabel: l.save,
              onConfirm: _save,
            ),
          ),
        ),
      ],
    );
  }
}

/// The field itself: no outline, a card behind it and a monospaced face, the way
/// the design layer draws code you are meant to read while editing it.
class _RulesField extends StatelessWidget {
  final TextEditingController controller;

  const _RulesField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        // A dozen lines stay on screen before the field starts to grow.
        minLines: 12,
        maxLines: null,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.7,
          color: p.label,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }
}
