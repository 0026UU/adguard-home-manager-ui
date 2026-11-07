import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/safe_search.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Safe search picker for a single device: a master switch plus one row per
/// search engine.
///
/// The engines are only reachable while the master switch is on, which is how
/// AdGuard Home reads the setting: an engine ticked under a disabled safe
/// search has no effect.
class SafeSearchModal extends StatefulWidget {
  final SafeSearch safeSearch;
  final void Function(SafeSearch) onConfirm;
  final bool dialog;

  const SafeSearchModal({
    super.key,
    required this.safeSearch,
    required this.onConfirm,
    required this.dialog,
  });

  @override
  State<SafeSearchModal> createState() => _SafeSearchModalState();
}

class _SafeSearchModalState extends State<SafeSearchModal> {
  late final SafeSearch _draft;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final source = widget.safeSearch;
    _draft = SafeSearch(
      enabled: source.enabled,
      bing: source.bing,
      duckduckgo: source.duckduckgo,
      ecosia: source.ecosia,
      google: source.google,
      pixabay: source.pixabay,
      yandex: source.yandex,
      youtube: source.youtube,
    );
  }

  void _set(void Function(SafeSearch) change) {
    if (_finished) return;
    setState(() => change(_draft));
  }

  void _cancel() {
    if (_finished) return;
    _finished = true;
    Navigator.pop(context);
  }

  void _confirm() {
    if (_finished) return;
    _finished = true;
    widget.onConfirm(
      SafeSearch(
        enabled: _draft.enabled,
        bing: _draft.bing,
        duckduckgo: _draft.duckduckgo,
        ecosia: _draft.ecosia,
        google: _draft.google,
        pixabay: _draft.pixabay,
        yandex: _draft.yandex,
        youtube: _draft.youtube,
      )
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    Widget engine(String label, bool value, ValueChanged<bool> onChanged) {
      final locked = !_draft.enabled;

      return AppleListTile(
        title: label,
        showChevron: false,
        enabled: !locked,
        // Under a disabled safe search the row neither dims its tick nor
        // takes the tap: an engine ticked there has no effect server-side.
        onTap: locked ? null : () => onChanged(!value),
        trailing: SizedBox(
          width: 24,
          child: value
              ? Icon(CupertinoIcons.checkmark, size: 20, color: p.tint)
              : null,
        ),
      );
    }

    return AppleFormModal(
      title: l.safeSearch,
      icon: CupertinoIcons.search,
      dialog: widget.dialog,
      maxWidth: 420,
      trailing: IconButton(
        onPressed: _finished ? null : _cancel,
        tooltip: l.close,
        icon: Icon(CupertinoIcons.xmark, size: 20, color: p.label2),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppleListSection(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    children: [
                      AppleSwitchListTile(
                        title: l.enable,
                        subtitle: l.safeSearchHelper,
                        value: _draft.enabled,
                        onChanged: _finished
                            ? null
                            : (value) => _set((s) => s.enabled = value),
                      ),
                    ],
                  ),
                  AppleGroupHeader(
                    title: l.safeSearchSettings,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 9),
                  ),
                  AppleListSection(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      engine("Bing", _draft.bing, (v) => _set((s) => s.bing = v)),
                      engine(
                        "DuckDuckGo",
                        _draft.duckduckgo,
                        (v) => _set((s) => s.duckduckgo = v),
                      ),
                      engine("Ecosia", _draft.ecosia, (v) => _set((s) => s.ecosia = v)),
                      engine("Google", _draft.google, (v) => _set((s) => s.google = v)),
                      engine(
                        "Pixabay",
                        _draft.pixabay,
                        (v) => _set((s) => s.pixabay = v),
                      ),
                      engine("Yandex", _draft.yandex, (v) => _set((s) => s.yandex = v)),
                      engine(
                        "YouTube",
                        _draft.youtube,
                        (v) => _set((s) => s.youtube = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AppleFormFooter(
            confirmLabel: l.confirm,
            confirmEnabled: !_finished,
            cancelEnabled: !_finished,
            onConfirm: _confirm,
            onCancel: _cancel,
          ),
        ],
      ),
    );
  }
}
