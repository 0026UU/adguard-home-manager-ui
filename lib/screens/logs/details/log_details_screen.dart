import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:adguard_home_manager/functions/copy_clipboard.dart';
import 'package:adguard_home_manager/functions/get_filtered_status.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

class _QueryResult {
  final String label;
  final Color color;

  const _QueryResult({required this.label, required this.color});
}

_QueryResult _resultOf(BuildContext context, Log log) {
  final l = AppLocalizations.of(context)!;
  final p = ApplePalette.of(context);
  if (log.reason.startsWith('Rewrite')) {
    return _QueryResult(label: l.rewrite, color: p.tint);
  }
  if (isDomainBlocked(log.reason)) {
    return _QueryResult(label: l.queryBlocked, color: p.red);
  }
  if (log.reason == 'NotFilteredNotFound' &&
      !log.cached &&
      log.upstream?.isNotEmpty == true) {
    return _QueryResult(label: l.queryUpstream, color: p.tint);
  }
  if (log.reason == 'NotFilteredNotFound' ||
      log.reason == 'NotFilteredWhiteList') {
    return _QueryResult(label: l.queryAllowed, color: p.green);
  }
  if (log.reason == 'NotFilteredError') {
    return _QueryResult(label: l.processedErrorRow, color: p.orange);
  }
  return _QueryResult(label: l.unknownResult, color: p.label3);
}

Future<void> showLogDetails(BuildContext context, {required Log log}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierColor: const Color(0x66000000),
    backgroundColor: Colors.transparent,
    builder: (context) {
      final l = AppLocalizations.of(context)!;
      final p = ApplePalette.of(context);
      final result = _resultOf(context, log);
      return AppleSheet(
        leading: ApplePill(label: result.label, color: result.color),
        trailing: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(CupertinoIcons.xmark, color: p.label2, size: 20),
          tooltip: l.close,
        ),
        initialFraction: 0.78,
        body: _Content(log: log),
        footer: _Actions(log: log, closeOnSave: true),
      );
    },
  );
}

class _Actions extends StatefulWidget {
  final Log log;
  final bool closeOnSave;

  const _Actions({required this.log, required this.closeOnSave});

  @override
  State<_Actions> createState() => _ActionsState();
}

class _ActionsState extends State<_Actions> {
  bool _saving = false;

  Future<void> _block() async {
    if (_saving) return;
    final l = AppLocalizations.of(context)!;
    final config = context.read<AppConfigProvider>();
    final status = context.read<StatusProvider>();
    setState(() => _saving = true);
    var success = false;
    try {
      success = await status.blockUnblockDomain(
        domain: widget.log.question.name!,
        newStatus: 'block',
      );
    } catch (_) {
      success = false;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (success && widget.closeOnSave) Navigator.pop(context);
    showSnackbar(
      appConfigProvider: config,
      label: success ? l.addedToBlockList : l.userFilteringRulesNotUpdated,
      color: success ? null : ApplePalette.of(context).red,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final status = context.watch<StatusProvider>();
    final domain = widget.log.question.name;
    final hasDomain = domain?.isNotEmpty == true;
    return SafeArea(
      top: false,
      child: AppleFormFooter(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        cancelLabel: l.copyDomain,
        cancelEnabled: hasDomain,
        onCancel: () => copyToClipboard(
          value: domain!,
          successMessage: l.domainCopiedClipboard,
        ),
        confirmLabel: _saving ? l.savingUserFilters : l.addToBlockList,
        confirmEnabled: hasDomain && status.filteringStatus != null && !_saving,
        onConfirm: _block,
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final Log log;
  final Color? cardColor;

  const _Content({required this.log, this.cardColor});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final result = _resultOf(context, log);
    final clientName = log.clientInfo?.name;
    final elapsed = double.tryParse(log.elapsedMs);
    final ttl = log.answer.map((answer) => answer.ttl).toSet();
    final locale = Localizations.localeOf(context).toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            log.question.name ?? l.notAvailable,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.25,
              color: p.label,
            ),
          ),
          const SizedBox(height: 12),
          AppleDetailCard(
            color: cardColor,
            rows: [
              AppleDetailRow(label: l.status, value: result.label),
              AppleDetailRow(
                label: l.logReason,
                value: log.reason.isEmpty ? '—' : log.reason,
              ),
              AppleDetailRow(
                label: l.client,
                value: clientName?.isNotEmpty == true ? clientName! : log.client,
              ),
              AppleDetailRow(label: l.sourceIp, value: log.client, mono: true),
              AppleDetailRow(
                label: l.elapsedTime,
                value: elapsed == null || !elapsed.isFinite
                    ? '—'
                    : '${elapsed.toStringAsFixed(1)} ms',
                mono: true,
              ),
              AppleDetailRow(label: l.type, value: log.question.type, mono: true),
              AppleDetailRow(
                label: l.responseSize,
                value: log.size == null ? '—' : '${log.size} B',
                mono: true,
              ),
              AppleDetailRow(
                label: l.ttl,
                value: isDomainBlocked(log.reason) || ttl.isEmpty
                    ? '—'
                    : ttl.map((value) => '$value s').join(', '),
                mono: true,
              ),
              AppleDetailRow(
                label: l.time,
                value: DateFormat.yMd(locale).add_Hms().format(log.time.toLocal()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LogDetailsScreen extends StatelessWidget {
  final Log log;
  final bool twoColumns;

  const LogDetailsScreen({
    super.key,
    required this.log,
    required this.twoColumns,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    return AppleScreen(
      title: l.logDetails,
      leading: twoColumns
          ? null
          : IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(CupertinoIcons.back, color: p.tint, size: 28),
            ),
      slivers: [
        SliverToBoxAdapter(child: _Content(log: log, cardColor: p.card)),
        SliverToBoxAdapter(child: _Actions(log: log, closeOnSave: false)),
      ],
    );
  }
}
