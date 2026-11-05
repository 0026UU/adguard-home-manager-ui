// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/models/applied_filters.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/logs/filters/clients_modal.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// How many devices the sheet lists before offering the full picker.
const _inlineClientLimit = 5;

/// Query-log filters: status chips, devices and the lookback window.
///
/// The sheet edits a draft and only hands it to [LogsProvider] on "apply", so
/// closing it any other way leaves the running search alone.
class LogsFiltersModal extends StatefulWidget {
  final bool dialog;

  const LogsFiltersModal({super.key, required this.dialog});

  @override
  State<LogsFiltersModal> createState() => _LogsFiltersModalState();
}

class _LogsFiltersModalState extends State<LogsFiltersModal> {
  List<LogStatus> _statuses = [];
  List<String> _clients = [];
  LogTimeRange _timeRange = LogTimeRange.twentyFourHours;

  @override
  void initState() {
    final applied = Provider.of<LogsProvider>(context, listen: false)
        .appliedFilters;
    _statuses = List.of(applied.statuses);
    _clients = List.of(applied.clients);
    _timeRange = applied.timeRange;

    super.initState();
  }

  void _toggleStatus(LogStatus status) {
    setState(() {
      if (_statuses.contains(status)) {
        _statuses.remove(status);
      } else {
        _statuses.add(status);
      }
    });
  }

  void _toggleClient(String id) {
    setState(() {
      if (_clients.contains(id)) {
        _clients.remove(id);
      } else {
        _clients.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final logsProvider = Provider.of<LogsProvider>(context);
    final clientsProvider = Provider.of<ClientsProvider>(context);
    final statusProvider = Provider.of<StatusProvider>(context);
    final width = MediaQuery.of(context).size.width;

    void apply() {
      logsProvider.setSelectedStatuses(_statuses);
      logsProvider.setSelectedClients(_clients);
      logsProvider.setTimeRange(_timeRange);
      Navigator.pop(context);
      logsProvider.filterLogs();
    }

    void reset() {
      Navigator.pop(context);
      logsProvider.requestResetFilters();
    }

    Future<void> openAllClients() async {
      // The picker edits the provider's draft, so hand it the current one and
      // take the result back when it closes.
      logsProvider.setSelectedStatuses(_statuses);
      logsProvider.setSelectedClients(_clients);
      logsProvider.setTimeRange(_timeRange);

      final asDialog = width > 700 || !(Platform.isAndroid || Platform.isIOS);
      if (asDialog) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const ClientsModal(dialog: true),
        );
      } else {
        await showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const ClientsModal(dialog: false),
        );
      }

      if (!mounted) return;
      setState(() => _clients = List.of(logsProvider.selectedClients));
    }

    final List<AutoClient> knownClients =
        clientsProvider.loadStatus == LoadStatus.loaded
            ? clientsProvider.clients!.autoClients
            : const [];

    String? nameOf(String ip) {
      try {
        return statusProvider.serverStatus!.clients
            .firstWhere((c) => c.ids.contains(ip))
            .name;
      } catch (e) {
        return null;
      }
    }

    final inline = knownClients.take(_inlineClientLimit).toList();
    final palette = ApplePalette.of(context);

    return AppleFormModal(
      title: l.filterLogs,
      icon: CupertinoIcons.slider_horizontal_3,
      dialog: widget.dialog,
      maxWidth: 420,
      // The prototype keeps an × next to the title; on the dialog, which the
      // app opens with a non-dismissible barrier, it is the only plain exit.
      trailing: IconButton(
        onPressed: () => Navigator.pop(context),
        tooltip: l.close,
        icon: Icon(CupertinoIcons.xmark, size: 20, color: palette.label2),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppleGroupHeader(
                    title: l.status,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 9),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final status in LogStatus.values)
                          AppleToggleChip(
                            label: logStatusLabel(l, status),
                            selected: _statuses.contains(status),
                            activeColor: logStatusColor(palette, status),
                            onTap: () => _toggleStatus(status),
                          ),
                      ],
                    ),
                  ),
                  AppleGroupHeader(
                    title: l.clients,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 9),
                  ),
                  if (clientsProvider.loadStatus == LoadStatus.loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: CupertinoActivityIndicator(radius: 10)),
                    )
                  else
                    AppleListSection(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final auto in inline)
                          _clientRow(auto, nameOf(auto.ip)),
                        if (knownClients.length > _inlineClientLimit)
                          AppleListTile(
                            title: l.allClients,
                            value: "${knownClients.length - _inlineClientLimit}",
                            onTap: openAllClients,
                          ),
                      ],
                    ),
                  AppleGroupHeader(
                    title: l.timeRange,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 9),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: AppleSegmented(
                      labels: [
                        l.lastHour,
                        l.lastSixHours,
                        l.lastTwentyFourHours,
                        l.lastSevenDays,
                      ],
                      selectedIndex: _timeRange.index,
                      large: true,
                      onChanged: (index) =>
                          setState(() => _timeRange = LogTimeRange.values[index]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppleFormFooter(
            confirmLabel: l.apply,
            cancelLabel: l.resetFilters,
            onCancel: reset,
            onConfirm: apply,
          ),
        ],
      ),
    );
  }

  Widget _clientRow(AutoClient auto, String? addedName) {
    final palette = ApplePalette.of(context);
    final ip = auto.ip;
    // The name a device is known by, from reverse DNS or from the devices the
    // user added; without either, the row shows the address itself.
    final name = auto.name ?? addedName;
    final seed = name ?? ip;

    // The prototype wraps the switch in a label, so the whole row toggles; the
    // switch itself keeps winning the arena where it is hit.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleClient(ip),
      child: AppleSwitchListTile(
        leading: AppleAvatar(
          text: seed,
          size: 30,
          color: palette.seeded(seed),
          gradientTo: palette.seededAlt(seed),
        ),
        title: seed,
        subtitle: name == null ? null : ip,
        value: _clients.contains(ip),
        onChanged: (_) => _toggleClient(ip),
      ),
    );
  }
}

/// Label of a status chip, matching the pill wording of the log rows.
String logStatusLabel(AppLocalizations l, LogStatus status) {
  switch (status) {
    case LogStatus.blocked:
      return l.queryBlocked;
    case LogStatus.allowed:
      return l.queryAllowed;
    case LogStatus.upstream:
      return l.queryUpstream;
  }
}

/// Accent of a status chip: red for blocked, green for allowed, accent for the
/// ones the upstream answered.
Color logStatusColor(ApplePalette p, LogStatus status) {
  switch (status) {
    case LogStatus.blocked:
      return p.red;
    case LogStatus.allowed:
      return p.green;
    case LogStatus.upstream:
      return p.tint;
  }
}
