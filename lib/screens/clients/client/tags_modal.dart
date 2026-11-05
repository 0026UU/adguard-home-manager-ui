import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

class TagsModal extends StatefulWidget {
  final List<String> selectedTags;
  final List<String> tags;
  final void Function(List<String>) onConfirm;

  const TagsModal({
    super.key,
    required this.selectedTags,
    required this.tags,
    required this.onConfirm,
  });

  @override
  State<TagsModal> createState() => _TagsModalState();
}

class _TagsModalState extends State<TagsModal> {
  late final List<String> _selectedTags;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _selectedTags = List<String>.of(widget.selectedTags);
  }

  void _toggleTag(String tag) {
    if (_finished) return;
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.removeWhere((selected) => selected == tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _cancel() {
    if (_finished) return;
    _finished = true;
    Navigator.pop(context);
  }

  void _confirm() {
    if (_finished) return;
    setState(() => _finished = true);
    // Give the caller its own list, including an empty one to clear all tags.
    widget.onConfirm(List<String>.of(_selectedTags));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    return AppleSheet(
      title: l.tags,
      leading: AppleIconBadge(icon: CupertinoIcons.tag, color: p.tint),
      trailing: IconButton(
        onPressed: _finished ? null : _cancel,
        tooltip: l.close,
        icon: Icon(CupertinoIcons.xmark, size: 20, color: p.label2),
      ),
      body: widget.tags.isEmpty
          ? AppleEmptyState(icon: CupertinoIcons.tag, title: l.noItems)
          : Material(
              color: Colors.transparent,
              child: AppleListSection(
                background: p.window,
                children: [
                  for (final tag in widget.tags)
                    Semantics(
                      checked: _selectedTags.contains(tag),
                      label: tag,
                      child: AppleListTile(
                        title: tag,
                        showChevron: false,
                        onTap: _finished ? null : () => _toggleTag(tag),
                        trailing: SizedBox(
                          width: 24,
                          child: _selectedTags.contains(tag)
                              ? Icon(CupertinoIcons.checkmark,
                                  size: 20, color: p.tint)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
      footer: SafeArea(
        top: false,
        child: AppleFormFooter(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          confirmLabel: l.confirm,
          confirmEnabled: !_finished,
          cancelEnabled: !_finished,
          onConfirm: _confirm,
          onCancel: _cancel,
        ),
      ),
    );
  }
}
