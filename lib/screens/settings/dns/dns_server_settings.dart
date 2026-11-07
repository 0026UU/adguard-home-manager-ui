// ignore_for_file: use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/settings/dns/rate_limit_allowlist_modal.dart';

import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/providers/dns_provider.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';

/// The server's own answers: how often a client may ask, what a blocked
/// request is answered with and how the server is told who asked.
///
/// Every field writes the single `/dns_config` payload this screen has always
/// sent, so nothing about the save or its validation changed on the way into
/// the design layer.
class DnsServerSettingsScreen extends StatefulWidget {
  const DnsServerSettingsScreen({super.key});

  @override
  State<DnsServerSettingsScreen> createState() => _DnsServerSettingsScreenState();
}

class _DnsServerSettingsScreenState extends State<DnsServerSettingsScreen> {
  final _limitRequestsController = TextEditingController();
  final _ipv4PrefixSubnetController = TextEditingController();
  String? _ipv4PrefixSubnetError;
  final _ipv6PrefixSubnetController = TextEditingController();
  String? _ipv6PrefixSubnetError;
  List<String> _rateLimitAllowlist = [];
  String? _limitRequestsError;

  // The rows under a switch are drawn only while it is on, the way the rest of
  // the design layer hides the option behind the choice that owns it, so the
  // switches themselves are the whole expandable state of this screen.
  bool _enableEdns = false;
  bool _useCustomIpEdns = false;
  final _customIpEdnsController = TextEditingController();
  String? _ednsIpError;
  bool _enableDnssec = false;
  bool _disableIpv6Resolving = false;

  String blockingMode = "default";

  final _ipv4controller = TextEditingController();
  String? _ipv4error;
  final _ipv6controller = TextEditingController();
  String? ipv6error;

  final _ttlController = TextEditingController();
  String? _ttlError;

  void validateIpv4(String value) {
    RegExp ipAddress = RegExp(r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$');
    if (ipAddress.hasMatch(value) == true) {
      setState(() => _ipv4error = null);
    }
    else {
      setState(() => _ipv4error = AppLocalizations.of(context)!.invalidIp);
    }
  }

  void validateEdns(String value) {
    RegExp ipAddress = RegExp(r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)(\.(?!$)|$)){4}$');
    if (ipAddress.hasMatch(value) == true) {
      setState(() => _ednsIpError = null);
    }
    else {
      setState(() => _ednsIpError = AppLocalizations.of(context)!.ipNotValid);
    }
  }

  void validateIpv6(String value) {
    RegExp ipAddress = RegExp(r'(?:^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}$)|(?:^(?:(?:[a-fA-F\d]{1,4}:){7}(?:[a-fA-F\d]{1,4}|:)|(?:[a-fA-F\d]{1,4}:){6}(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|:[a-fA-F\d]{1,4}|:)|(?:[a-fA-F\d]{1,4}:){5}(?::(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,2}|:)|(?:[a-fA-F\d]{1,4}:){4}(?:(?::[a-fA-F\d]{1,4}){0,1}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,3}|:)|(?:[a-fA-F\d]{1,4}:){3}(?:(?::[a-fA-F\d]{1,4}){0,2}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,4}|:)|(?:[a-fA-F\d]{1,4}:){2}(?:(?::[a-fA-F\d]{1,4}){0,3}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,5}|:)|(?:[a-fA-F\d]{1,4}:){1}(?:(?::[a-fA-F\d]{1,4}){0,4}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,6}|:)|(?::(?:(?::[a-fA-F\d]{1,4}){0,5}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,7}|:)))(?:%[0-9a-zA-Z]{1,})?$)');
    if (ipAddress.hasMatch(value) == true) {
      setState(() => ipv6error = null);
    }
    else {
      setState(() => ipv6error = AppLocalizations.of(context)!.invalidIp);
    }
  }

  bool validateData() {
    if (
      (_limitRequestsController.text == "" || (_limitRequestsController.text != "" && _limitRequestsError == null)) &&
      (
        blockingMode != 'custom_ip' ||
        (
          blockingMode == 'custom_ip' && 
          _ipv4controller.text != '' &&
          _ipv4error == null &&
          _ipv6controller.text != '' &&
          ipv6error == null
        )
      ) == true && 
      _ednsIpError == null && 
      _ttlController.text != "" && _ttlError == null &&
      (_ipv4PrefixSubnetController.text == "" || (_ipv4PrefixSubnetController.text != "" && _ipv4PrefixSubnetError == null)) &&
      (_ipv6PrefixSubnetController.text == "" || (_ipv6PrefixSubnetController.text != "" && _ipv6PrefixSubnetError == null))
    ) {
      return true;
    }
    else {
      return false;
    }
  }

  String? validateTtl(String value) {
    if (value == "") return AppLocalizations.of(context)!.valueNotNumber;
    if (int.tryParse(value) != null) {
      return null;
    }
    else {
      return AppLocalizations.of(context)!.valueNotNumber;
    }
  }

  String? validateNumber(String value) {
    if (value == "") return null;
    if (int.tryParse(value) != null) {
      return null;
    }
    else {
      return AppLocalizations.of(context)!.valueNotNumber;
    }
  }

  @override
  void initState() {
    final dnsProvider = Provider.of<DnsProvider>(context, listen: false);

    _limitRequestsController.text = dnsProvider.dnsInfo!.ratelimit.toString();
    _enableEdns = dnsProvider.dnsInfo!.ednsCsEnabled;
    _useCustomIpEdns = dnsProvider.dnsInfo!.ednsCsUseCustom ?? false;
    _customIpEdnsController.text = dnsProvider.dnsInfo!.ednsCsCustomIp ?? "";
    _enableDnssec = dnsProvider.dnsInfo!.dnssecEnabled;
    _disableIpv6Resolving = dnsProvider.dnsInfo!.disableIpv6;
    blockingMode = dnsProvider.dnsInfo!.blockingMode;
    _ipv4controller.text = dnsProvider.dnsInfo!.blockingIpv4;
    _ipv6controller.text = dnsProvider.dnsInfo!.blockingIpv6;
    _ttlController.text = dnsProvider.dnsInfo!.blockedResponseTtl != null
      ? dnsProvider.dnsInfo!.blockedResponseTtl.toString()
      : "";
    _ipv4PrefixSubnetController.text = dnsProvider.dnsInfo!.ratelimitSubnetLenIpv4 != null
      ? dnsProvider.dnsInfo!.ratelimitSubnetLenIpv4.toString()
      : "";
    _ipv6PrefixSubnetController.text = dnsProvider.dnsInfo!.ratelimitSubnetLenIpv6 != null
      ? dnsProvider.dnsInfo!.ratelimitSubnetLenIpv6.toString()
      : "";
    _rateLimitAllowlist = dnsProvider.dnsInfo!.ratelimitWhitelist ?? [];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final dnsProvider = Provider.of<DnsProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final width = MediaQuery.of(context).size.width;
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    void saveData() async {
      ProcessModal processModal = ProcessModal();
      processModal.open(l.savingConfig);

      final result = await dnsProvider.saveDnsServerConfig({
        "ratelimit": int.tryParse(_limitRequestsController.text),
        "edns_cs_enabled": _enableEdns,
        "edns_cs_use_custom": _useCustomIpEdns,
        "edns_cs_custom_ip": _customIpEdnsController.text,
        "dnssec_enabled": _enableDnssec,
        "disable_ipv6": _disableIpv6Resolving,
        "blocking_mode": blockingMode,
        "blocking_ipv4": _ipv4controller.text,
        "blocking_ipv6": _ipv6controller.text,
        "blocked_response_ttl": int.tryParse(_ttlController.text),
        "ratelimit_subnet_len_ipv4": int.tryParse(_ipv4PrefixSubnetController.text),
        "ratelimit_subnet_len_ipv6": int.tryParse(_ipv6PrefixSubnetController.text),
        "ratelimit_whitelist": _rateLimitAllowlist
      });

      processModal.close();

      if (result.successful == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.dnsConfigSaved, 
          color: p.green
        );
      }
      else if (result.successful == false && result.statusCode == 400) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.someValueNotValid, 
          color: p.red
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.dnsConfigNotSaved, 
          color: p.red
        );
      } 
    }

    void updateBlockingMode(String mode) {
      if (mode != 'custom_ip') {
        _ipv4controller.text = '';
        _ipv4error = null;
        _ipv6controller.text = '';
        ipv6error = null;
      }
      setState(() => blockingMode = mode);
      validateData();
    }

    final dataValid = validateData();

    // The blocking modes are one group of rows, one of which carries the mark
    // the iOS answer list puts on the choice in force.
    AppleListTile blockingRow(String value, String title, String description) =>
        AppleListTile(
          title: title,
          subtitle: description,
          showChevron: false,
          onTap: () => updateBlockingMode(value),
          trailing: blockingMode == value
            ? Icon(CupertinoIcons.checkmark, color: p.tint)
            : const SizedBox.shrink(),
        );

    return AppleScreen(
      title: l.dnsServerSettings,
      subtitle: l.dnsServerSettingsDescription,
      leading: isDesktop(width)
        ? null
        : AppleBackButton(
            label: l.back,
            onPressed: () => Navigator.pop(context),
          ),
      actions: [
        IconButton(
          onPressed: dataValid == true
            ? () => saveData()
            : null, 
          icon: const Icon(CupertinoIcons.checkmark),
          tooltip: l.save,
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: AppleFormGroupLabel(
            l.rateLimit,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 7),
          ),
        ),
        SliverToBoxAdapter(
          child: AppleTextField(
            controller: _limitRequestsController,
            onChanged: (v) => setState(() => _limitRequestsError = validateNumber(v)),
            icon: CupertinoIcons.number,
            label: l.limitRequestsSecond,
            error: _limitRequestsError,
            keyboardType: TextInputType.number,
          ),
        ),
        SliverToBoxAdapter(
          child: AppleTextField(
            controller: _ipv4PrefixSubnetController,
            onChanged: (v) => setState(() => _ipv4PrefixSubnetError = validateNumber(v)),
            icon: CupertinoIcons.square_split_2x1_fill,
            label: l.subnetPrefixLengthIpv4,
            error: _ipv4PrefixSubnetError,
            keyboardType: TextInputType.number,
          ),
        ),
        SliverToBoxAdapter(
          child: AppleTextField(
            controller: _ipv6PrefixSubnetController,
            onChanged: (v) => setState(() => _ipv6PrefixSubnetError = validateNumber(v)),
            icon: CupertinoIcons.square_split_2x1_fill,
            label: l.subnetPrefixLengthIpv6,
            error: _ipv6PrefixSubnetError,
            keyboardType: TextInputType.number,
          ),
        ),
        SliverToBoxAdapter(
          child: AppleListSection(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            children: [
              AppleListTile(
                title: l.rateLimitAllowlist,
                subtitle: l.rateLimitAllowlistDescription,
                icon: CupertinoIcons.list_bullet,
                iconColor: p.indigo,
                onTap: () => showDialog(
                  context: context, 
                  builder: (context) => RateLimitAllowlistModal(
                    values: _rateLimitAllowlist,
                    onConfirm: (ips) => setState(() => _rateLimitAllowlist = ips)
                  ),
                ),
                trailing: _rateLimitAllowlist.isNotEmpty
                  ? ApplePill(
                      label: _rateLimitAllowlist.length.toString(),
                      color: p.label2,
                    )
                  : null,
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(child: AppleFormGroupLabel(l.dnsOptions)),
        SliverToBoxAdapter(
          child: AppleListSection(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            children: [
              AppleSwitchListTile(
                icon: CupertinoIcons.bolt_fill,
                iconColor: p.purple,
                value: _enableEdns, 
                onChanged: (value) => setState(() {
                  _enableEdns = value;
                  if (value == false) {
                    _useCustomIpEdns = false;
                    _customIpEdnsController.text = "";
                    _ednsIpError = null;
                  }
                  validateData();
                }), 
                title: l.enableEdns,
                subtitle: l.enableEdnsDescription,
              ),
              // The rows that used to unfold under a switch are drawn only
              // while it is on, which is exactly what the unfold did.
              if (_enableEdns)
                AppleSwitchListTile(
                  icon: CupertinoIcons.location_fill,
                  iconColor: p.indigo,
                  value: _useCustomIpEdns, 
                  onChanged: (value) => setState(() {
                    _useCustomIpEdns = value;
                    if (_useCustomIpEdns == false) {
                      _customIpEdnsController.text = "";
                      _ednsIpError = null;
                    }
                    validateData();
                  }), 
                  title: l.useCustomIpEdns,
                  subtitle: l.useCustomIpEdnsDescription,
                ),
              AppleSwitchListTile(
                icon: CupertinoIcons.lock_shield,
                iconColor: p.green,
                value: _enableDnssec, 
                onChanged: (value) => setState(() => _enableDnssec = value), 
                title: l.enableDnssec,
                subtitle: l.enableDnssecDescription,
              ),
              AppleSwitchListTile(
                icon: CupertinoIcons.number,
                iconColor: p.gray,
                value: _disableIpv6Resolving, 
                onChanged: (value) => setState(() => _disableIpv6Resolving = value), 
                title: l.disableResolvingIpv6,
                subtitle: l.disableResolvingIpv6Description,
              ),
            ],
          ),
        ),
        if (_enableEdns && _useCustomIpEdns)
          SliverToBoxAdapter(
            child: AppleTextField(
              controller: _customIpEdnsController,
              onChanged: validateEdns,
              icon: CupertinoIcons.link,
              label: l.ipAddress,
              error: _ednsIpError,
            ),
          ),
        SliverToBoxAdapter(child: AppleFormGroupLabel(l.blockingMode)),
        SliverToBoxAdapter(
          child: AppleListSection(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            children: [
              blockingRow('default', l.defaultMode, l.defaultDescription),
              blockingRow('refused', 'REFUSED', l.refusedDescription),
              blockingRow('nxdomain', 'NXDOMAIN', l.nxdomainDescription),
              blockingRow('null_ip', l.nullIp, l.nullIpDescription),
              blockingRow('custom_ip', l.customIp, l.customIpDescription),
            ],
          ),
        ),
        if (blockingMode == 'custom_ip') ...[
          SliverToBoxAdapter(
            child: AppleTextField(
              controller: _ipv4controller,
              onChanged: validateIpv4,
              icon: CupertinoIcons.link,
              helper: l.blockingIpv4Description,
              helperMaxLines: 10,
              label: l.blockingIpv4,
              error: _ipv4error,
              keyboardType: TextInputType.number,
            ),
          ),
          SliverToBoxAdapter(
            child: AppleTextField(
              controller: _ipv6controller,
              onChanged: validateIpv6,
              icon: CupertinoIcons.link,
              helper: l.blockingIpv6Description,
              helperMaxLines: 10,
              label: l.blockingIpv6,
              error: ipv6error,
              keyboardType: TextInputType.number,
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: AppleTextField(
            controller: _ttlController,
            onChanged: (v) => setState(() => _ttlError = validateTtl(v)),
            icon: CupertinoIcons.timer,
            label: l.blockedResponseTtl,
            helper: l.blockedResponseTtlDescription,
            helperMaxLines: 2,
            error: _ttlError,
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }
}