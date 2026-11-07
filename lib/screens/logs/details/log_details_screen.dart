import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:adguard_home_manager/functions/copy_clipboard.dart';
import 'package:adguard_home_manager/functions/get_filtered_status.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';
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
  final l = AppLocalizations.of(context)!;
  final p = ApplePalette.of(context);
  final result = _resultOf(context, log);
  return showAppleSheet<void>(
    context,
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

  /// The web UI derives four statuses from the raw reason enum; the pill keeps
  /// the app's richer vocabulary, but this row has to read like AdGuard Home.
  String _statusValue(AppLocalizations l) {
    if (log.reason.startsWith('Rewrite')) return l.logStatusRewritten;
    if (isDomainBlocked(log.reason)) return l.queryBlocked;
    if (log.reason == 'NotFilteredWhiteList') return l.queryAllowed;
    return l.logStatusProcessed;
  }

  /// The reason phrase the web UI shows instead of the raw enum. Unknown enums
  /// fall back to the raw value so a newer server never renders an empty row.
  String? _reasonValue(AppLocalizations l) {
    switch (log.reason) {
      case 'FilteredBlackList':
        return l.logReasonBlockedByFilter;
      case 'FilteredSafeBrowsing':
        return l.logReasonBlockedThreats;
      case 'FilteredParental':
        return l.logReasonBlockedByParental;
      case 'FilteredSafeSearch':
        return l.logReasonSafeSearch;
      case 'FilteredBlockedService':
        return l.logReasonBlockedServices;
      case 'Rewrite':
      case 'RewriteRule':
        return l.logStatusRewritten;
      case 'RewriteEtcHosts':
        return l.logReasonRewrittenByHosts;
      case 'NotFilteredWhiteList':
        return l.logReasonAllowed;
      case 'NotFilteredNotFound':
      case 'NotFilteredError':
        return l.logStatusProcessed;
      default:
        return log.reason.isEmpty ? null : log.reason;
    }
  }

  /// Provenance the web UI calls "Source": the list that matched, or the
  /// engine behind a service/parental/safe-search block. Null hides the row.
  String? _sourceValue(AppLocalizations l, FilteringStatus? filtering) {
    switch (log.reason) {
      case 'FilteredBlackList':
      case 'NotFilteredWhiteList':
        if ((log.filterId ?? 0) == 0) return l.logSourceCustomRules;
        final lists = log.reason == 'NotFilteredWhiteList'
            ? filtering?.whitelistFilters
            : filtering?.filters;
        for (final filter in lists ?? const <Filter>[]) {
          if (filter.id == log.filterId) return filter.name;
        }
        // The list is gone or never loaded; the raw id is what the web shows.
        return '#${log.filterId}';
      case 'FilteredBlockedService':
        final service = log.serviceName;
        return service != null && service.isNotEmpty
            ? service
            : l.logReasonBlockedServices;
      case 'FilteredParental':
        return l.logSourceParentalControl;
      case 'FilteredSafeSearch':
        return l.logReasonSafeSearch;
      case 'FilteredSafeBrowsing':
        return l.logReasonBlockedThreats;
      default:
        return null;
    }
  }

  String _protocolValue(AppLocalizations l) {
    switch (log.clientProto ?? '') {
      case '':
        return l.logProtocolPlain;
      case 'doh':
        return l.logProtocolDoh;
      case 'dot':
        return l.logProtocolDot;
      case 'doq':
        return l.logProtocolDoq;
      default:
        return log.clientProto!;
    }
  }

  /// One answer per line, the way the web UI stacks the response records.
  String _answersText(List<Answer> answers) => answers
      .map((answer) => '${answer.type}  ${answer.value}  TTL ${answer.ttl}')
      .join('\n');

  /// The matched rules as a block; the legacy single `rule` string covers
  /// servers that do not send the `rules` array.
  String? _rulesText() {
    final texts = log.rules
        .map((rule) => rule.text)
        .where((text) => text.isNotEmpty)
        .toList();
    if (texts.isNotEmpty) return texts.join('\n');
    final legacy = log.rule;
    return legacy != null && legacy.isNotEmpty ? legacy : null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final filtering = context.watch<StatusProvider>().filteringStatus;
    final locale = Localizations.localeOf(context).toString();
    final localTime = log.time.toLocal();
    final elapsed = double.tryParse(log.elapsedMs);
    final clientName = log.clientInfo?.name;
    final whois = log.clientInfo?.whois;

    // Field set and order mirror the web UI's query log detail modal, so a
    // row read here reads the same on the server's own page.
    final queryRows = <Widget>[
      AppleDetailRow(
        label: l.time,
        value: DateFormat.Hms(locale).format(localTime),
        mono: true,
      ),
      AppleDetailRow(
        label: l.date,
        value: DateFormat.yMd(locale).format(localTime),
        mono: true,
      ),
      AppleDetailRow(label: l.domain, value: log.question.name ?? l.notAvailable),
      if (log.ecs?.isNotEmpty == true)
        AppleDetailRow(label: l.logDetailEcs, value: log.ecs!, mono: true),
      AppleDetailRow(label: l.type, value: log.question.type, mono: true),
      AppleDetailRow(label: l.logProtocol, value: _protocolValue(l)),
    ];

    final responseRows = <Widget>[
      if (log.answerDnssec == true)
        AppleDetailRow(
          label: l.logDetailDnssec,
          value: l.logDetailValidatedWithDnssec,
        ),
      AppleDetailRow(label: l.status, value: _statusValue(l)),
      if (_reasonValue(l) != null)
        AppleDetailRow(label: l.logReason, value: _reasonValue(l)!),
      if (_sourceValue(l, filtering) != null)
        AppleDetailRow(label: l.logDetailSource, value: _sourceValue(l, filtering)!),
      AppleDetailRow(
        label: l.logDetailServedFromCache,
        value: log.cached ? l.yes : l.no,
      ),
      if (log.upstream?.isNotEmpty == true)
        AppleDetailRow(label: l.dnsServer, value: log.upstream!, mono: true),
      if (elapsed != null && elapsed.isFinite)
        AppleDetailRow(
          label: l.elapsedTime,
          value: '${elapsed.toStringAsFixed(1)} ms',
          mono: true,
        ),
      if (log.status?.isNotEmpty == true)
        AppleDetailRow(label: l.responseCode, value: log.status!, mono: true),
      if (log.answer.isNotEmpty)
        AppleDetailRow(label: l.response, value: _answersText(log.answer), mono: true),
      if (log.serviceName?.isNotEmpty == true)
        AppleDetailRow(label: l.logDetailServiceName, value: log.serviceName!),
      if (_rulesText() != null)
        AppleDetailRow(label: l.logDetailRules, value: _rulesText()!, mono: true),
      if (log.originalAnswer?.isNotEmpty == true)
        AppleDetailRow(
          label: l.logDetailOriginalResponse,
          value: _answersText(log.originalAnswer!),
          mono: true,
        ),
    ];

    final clientRows = <Widget>[
      AppleDetailRow(label: l.logDetailAddress, value: log.client, mono: true),
      if (clientName?.isNotEmpty == true)
        AppleDetailRow(label: l.deviceName, value: clientName!),
      if (whois?.country?.isNotEmpty == true)
        AppleDetailRow(label: l.logDetailCountry, value: whois!.country!),
      if (whois?.orgname?.isNotEmpty == true)
        AppleDetailRow(label: l.logDetailNetwork, value: whois!.orgname!, mono: true),
    ];

    // The captions sit inside the content's own 16pt inset, so they borrow
    // only the vertical rhythm of [AppleFormGroupLabel].
    const captionPadding = EdgeInsets.fromLTRB(0, 20, 0, 8);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            log.question.name ?? l.notAvailable,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              height: 1.25,
              color: p.label,
            ),
          ),
          AppleFormGroupLabel(l.logQueryDetails, padding: captionPadding),
          AppleDetailCard(color: cardColor, rows: queryRows),
          AppleFormGroupLabel(l.logResponseDetails, padding: captionPadding),
          AppleDetailCard(color: cardColor, rows: responseRows),
          AppleFormGroupLabel(l.logClientDetails, padding: captionPadding),
          AppleDetailCard(color: cardColor, rows: clientRows),
          const SizedBox(height: 16),
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
