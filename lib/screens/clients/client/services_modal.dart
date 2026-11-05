import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/custom_checkbox_list_tile.dart';

/// Services a single device blocks.
///
/// The picker edits its own copy of the caller's list, so leaving it without
/// confirming changes nothing, and confirming with nothing ticked clears every
/// service the device had.
class ServicesModal extends StatefulWidget {
  final List<String> blockedServices;
  final void Function(List<String>) onConfirm;
  final bool dialog;

  const ServicesModal({
    super.key,
    required this.blockedServices,
    required this.onConfirm,
    required this.dialog,
  });

  @override
  State<ServicesModal> createState() => _ServicesModalState();
}

class _ServicesModalState extends State<ServicesModal> {
  late final List<String> _selected;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _selected = List.of(widget.blockedServices);

    final filtering = Provider.of<FilteringProvider>(context, listen: false);
    if (filtering.blockedServicesLoadStatus != LoadStatus.loaded) {
      // Without the loader flag a failed request leaves the status on
      // "loading", so the sheet would spin forever instead of offering a retry.
      filtering.getBlockedServices(showLoader: true);
    }
  }

  void _toggle(String id, bool value) {
    if (_finished) return;
    setState(() {
      if (value) {
        if (!_selected.contains(id)) _selected.add(id);
      } else {
        _selected.removeWhere((service) => service == id);
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
    _finished = true;
    widget.onConfirm(List.of(_selected));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final filtering = Provider.of<FilteringProvider>(context);
    final loaded = filtering.blockedServicesLoadStatus == LoadStatus.loaded;

    Widget body() {
      switch (filtering.blockedServicesLoadStatus) {
        case LoadStatus.loading:
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                const CupertinoActivityIndicator(radius: 12),
                const SizedBox(height: 14),
                Text(
                  l.loadingBlockedServicesList,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: p.label2),
                ),
              ],
            ),
          );

        case LoadStatus.loaded:
          final services = filtering.blockedServices!.services;
          if (services.isEmpty) {
            return AppleEmptyState(icon: CupertinoIcons.globe, title: l.noItems);
          }
          return AppleListSection(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            children: [
              for (final service in services)
                CustomCheckboxListTile(
                  title: service.name,
                  value: _selected.contains(service.id),
                  onChanged: (value) => _toggle(service.id, value),
                ),
            ],
          );

        case LoadStatus.error:
          return AppleEmptyState(
            icon: CupertinoIcons.exclamationmark_triangle,
            color: p.red,
            title: l.blockedServicesListNotLoaded,
            action: AppleFormButton(
              label: l.refresh,
              background: p.tint,
              foreground: Colors.white,
              onPressed: () => filtering.getBlockedServices(showLoader: true),
            ),
          );
      }
    }

    return AppleFormModal(
      title: l.services,
      icon: CupertinoIcons.globe,
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
          Flexible(child: SingleChildScrollView(child: body())),
          AppleFormFooter(
            confirmLabel: l.confirm,
            confirmEnabled: loaded && !_finished,
            cancelEnabled: !_finished,
            onConfirm: _confirm,
            onCancel: _cancel,
          ),
        ],
      ),
    );
  }
}
