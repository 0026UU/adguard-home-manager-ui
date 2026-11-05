// ignore_for_file: use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/settings/encryption/reset_settings_modal.dart';
import 'package:adguard_home_manager/screens/settings/encryption/encryption_functions.dart';
import 'package:adguard_home_manager/screens/settings/encryption/error_message.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/models/encryption.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/functions/copy_clipboard.dart';
import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/functions/base64.dart';
import 'package:adguard_home_manager/functions/format_time.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';

/// The encrypted DNS of the server: which protocols it answers on which ports,
/// the certificate those ports serve and the key behind it.
///
/// The protocols are switched from the page, as the design layer draws them,
/// and every switch only moves the port it stands for inside the form the page
/// has always had, so a write still goes through the same validation and the
/// same save. The certificate rows read what `/tls/status` reported, or what
/// the server answered when a certificate was typed in, and nothing else.
class EncryptionSettings extends StatefulWidget {
  const EncryptionSettings({super.key});


  @override
  State<EncryptionSettings> createState() => _EncryptionSettingsState();
}

class _EncryptionSettingsState extends State<EncryptionSettings> {
  LoadStatus loadStatus = LoadStatus.loading;

  /// The settings as `/tls/status` answered them, kept so the summary rows can
  /// show the installed certificate instead of only what the form holds.
  EncryptionData? fetched;

  bool enabled = false;

  bool? _plainDns;

  final TextEditingController domainNameController = TextEditingController();
  String? domainError;

  bool redirectHttps = false;

  final TextEditingController httpsPortController = TextEditingController();
  String? httpsPortError;

  final TextEditingController tlsPortController = TextEditingController();
  String? tlsPortError;

  final TextEditingController dnsOverQuicPortController = TextEditingController();
  String? dnsOverQuicPortError;

  int certificateOption = 0;

  final TextEditingController certificatePathController = TextEditingController();
  String? certificatePathError;

  final TextEditingController certificateContentController = TextEditingController();
  String? certificateContentError;

  int privateKeyOption = 0;

  bool existsPreviousKey = false;
  bool usePreviouslySavedKey = false;

  final TextEditingController privateKeyPathController = TextEditingController();
  String? privateKeyPathError;

  final TextEditingController pastePrivateKeyController = TextEditingController();
  String? pastePrivateKeyError;

  bool localValidationValid = false;
  String? validDataError;
  bool _dataValidApi = true;

  EncryptionValidation? certKeyValid;
  String? encryptionResultMessage;

  bool formEdited = false;

  void fetchData({bool? showRefreshIndicator}) async {
    setState(() => loadStatus = LoadStatus.loading);

    final result = await Provider.of<ServersProvider>(context, listen: false).apiClient2!.getEncryptionSettings();
    if (!mounted) return;
    
    if (result.successful == true) {
      final data = result.content as EncryptionData;
      
      await checkValidDataApi(data: data.toJson());
      if (!mounted) return;

      setState(() {
        fetched = data;
        enabled = data.enabled;
        domainNameController.text = data.serverName ?? '';
        redirectHttps = data.forceHttps ?? false;
        httpsPortController.text = data.portHttps != null ? data.portHttps.toString() : '';
        tlsPortController.text = data.portDnsOverTls != null ? data.portDnsOverTls.toString() : '';
        dnsOverQuicPortController.text = data.portDnsOverQuic != null ? data.portDnsOverQuic.toString() : '';
        if (data.certificateChain != '') {
          certificateOption = 1;
          certificateContentController.text = decodeBase64(data.certificateChain);
        }
        else {
          certificateOption = 0;
          certificatePathController.text = data.certificatePath;
        }
        if (data.privateKey != '' || data.privateKeySaved == true) {
          privateKeyOption = 1;
        }
        else {
          privateKeyOption = 0;
          privateKeyPathController.text = data.privateKeyPath;
        }
        usePreviouslySavedKey = data.privateKeySaved;
        _plainDns = data.servePlainDns;
        loadStatus = LoadStatus.loaded;
      });
    }
    else {
      setState(() => loadStatus = LoadStatus.error);
    }
  }

  Future checkValidDataApi({Map<String, dynamic>? data}) async {
    final result = await Provider.of<ServersProvider>(context, listen: false).apiClient2!.checkEncryptionSettings(
      data: data ?? {
        "enabled": enabled,
        "server_name": domainNameController.text,
        "force_https": redirectHttps,
        "port_https": httpsPortController.text != '' ? int.parse(httpsPortController.text) : null,
        "port_dns_over_tls": tlsPortController.text != '' ? int.parse(tlsPortController.text) : null,
        "port_dns_over_quic": dnsOverQuicPortController.text != '' ? int.parse(dnsOverQuicPortController.text) : null,
        if (certificateOption == 1) "certificate_chain": encodeBase64(certificateContentController.text),
        if (privateKeyOption == 1 && usePreviouslySavedKey == false) "private_key": encodeBase64(pastePrivateKeyController.text),
        "private_key_saved": usePreviouslySavedKey,
        if (certificateOption == 0) "certificate_path": certificatePathController.text,
        if (privateKeyOption == 0) "private_key_path": privateKeyPathController.text,
      }
    );

    if (!mounted) return;
    if (result.successful == true) {
      final data = result.content as EncryptionValidationResult;
      if (data.isObject == true) {
        final object = data.encryptionValidation!;
        final hasWarning = object.warningValidation != null && object.warningValidation != '';
        // A message that arrives while the certificate itself checks out is
        // advice, not a failure. The web interface makes the same distinction
        // before deciding how loudly to present it.
        final certificateIsSound = object.validCert == true &&
          object.validKey == true &&
          object.validPair == true;
        setState(() {
          if (hasWarning && !certificateIsSound) {
            _dataValidApi = false;
            validDataError = object.warningValidation;
          }
          else {
            _dataValidApi = true;
            validDataError = null;
          }
          certKeyValid = object;
        });
        if (hasWarning && certificateIsSound) {
          showSnackbar(
            appConfigProvider: Provider.of<AppConfigProvider>(context, listen: false),
            label: object.warningValidation!,
            color: ApplePalette.of(context).red,
            duration: const Duration(seconds: 6),
          );
        }
      }
      else {
        setState(() {
          encryptionResultMessage = data.message;
          _dataValidApi = false;
        });
      }
    }
  }

  bool checkcertKeyValid() {
    // A protocol with no port is not served at all, which is what the switches
    // of the page write, so an empty port is a valid answer and not an error.
    if (
      domainNameController.text != '' && 
      domainError == null && 
      httpsPortError == null &&
      tlsPortError == null &&
      dnsOverQuicPortError == null 
    ) {
      setState(() => localValidationValid = true);
      return true;
    }
    else {
      setState(() => localValidationValid = false);
      return false;
    }
  }

  void onEditValidate() {
    setState(() => formEdited = true);
    final res = checkcertKeyValid();
    if (res == true) {
      checkValidDataApi();
    }
  }

  @override
  void initState() {
    fetchData();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final width = MediaQuery.of(context).size.width;
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    void saveData() async {
      ProcessModal processModal = ProcessModal();
      processModal.open(l.savingConfig);

      final result = await serversProvider.apiClient2!.saveEncryptionSettings(
        data: {
          "enabled": enabled,
          "server_name": domainNameController.text,
          "force_https": redirectHttps,
          "port_https": int.tryParse(httpsPortController.text),
          "port_dns_over_tls": int.tryParse(tlsPortController.text),
          "port_dns_over_quic": int.tryParse(dnsOverQuicPortController.text),
          "certificate_chain": encodeBase64(certificateContentController.text),
          "private_key": encodeBase64(pastePrivateKeyController.text),
          "private_key_saved": usePreviouslySavedKey,
          "certificate_path": certificatePathController.text,
          "private_key_path": privateKeyPathController.text,
          "serve_plain_dns": _plainDns
        }
      );

      processModal.close();

      if (result.successful == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.encryptionConfigSaved, 
          color: p.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.encryptionConfigNotSaved, 
          color: p.red
        );

        if (result.content != null) {
          showDialog(
            context: context, 
            builder: (context) => ErrorMessageEncryption(
              errorMessage: result.content
            )
          );
        }
      }
    }

    void resetSettings() async {
      ProcessModal processModal = ProcessModal();
      processModal.open(l.resettingConfig);

      final result = await serversProvider.apiClient2!.saveEncryptionSettings(
        data: {
          "enabled": false,
          "server_name": "",
          "force_https": false,
          "port_https": 443,
          "port_dns_over_tls": 853,
          "port_dns_over_quic": 853,
          "certificate_chain": "",
          "private_key": "",
          "private_key_saved": false,
          "certificate_path": "",
          "private_key_path": "",
          "serve_plain_dns": true
        }
      );
      if (!mounted) return;

      processModal.close();

      if (result.successful == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.configurationResetSuccessfully, 
          color: p.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.configurationResetError, 
          color: p.red
        );
      }
    }

    // The ports the page draws are the ones the form holds, so a switch shows
    // what the save would write and the field below it says the same thing.
    final httpsPort = int.tryParse(httpsPortController.text);
    final tlsPort = int.tryParse(tlsPortController.text);
    final quicPort = int.tryParse(dnsOverQuicPortController.text);

    // A protocol without a port is not served. Switching it back on offers the
    // number the server reported for it, or the one this page already writes
    // when the configuration is reset, so no port is ever invented.
    void movePort({
      required TextEditingController controller,
      required bool on,
      required int? reported,
      required int fallback,
    }) {
      setState(() => controller.text = on ? (reported ?? fallback).toString() : '');
      onEditValidate();
    }

    String protocolPort(int? port) =>
        port == null ? l.portNotConfigured : l.portNumber(port);

    // The certificate the page reports: the live answer of the validation call
    // while something is typed in the form, the installed one the rest of the
    // time.
    final typedCertificate = certificateContentController.text != '' ||
      certificatePathController.text != '';
    final validation = certKeyValid;
    final subject = (typedCertificate ? validation?.subject : null) ??
      fetched?.subject;
    final issuer = (typedCertificate ? validation?.issuer : null) ??
      fetched?.issuer;
    final notAfter = (typedCertificate ? validation?.notAfter : null) ??
      fetched?.notAfter;
    final hostNames = (typedCertificate ? validation?.dnsNames : null) ??
      fetched?.dnsNames ??
      const <String>[];
    final keyType = validation?.keyType ?? fetched?.keyType;
    final fingerprint = formatFingerprint(
      (typedCertificate ? validation?.fingerprintSha256 : null) ??
        fetched?.fingerprintSha256,
    );

    Widget check(bool selected) => selected
      ? Icon(CupertinoIcons.checkmark, color: p.tint)
      : const SizedBox.shrink();

    Widget statusRow(bool valid, String label) => AppleListTile(
      title: label,
      showChevron: false,
      trailing: Icon(
        valid ? CupertinoIcons.checkmark_circle : CupertinoIcons.xmark_circle,
        color: valid ? p.green : p.red,
      ),
    );

    return AppleScreen(
      title: l.encryptionSettings,
      subtitle: l.encryptionSettingsDescription,
      leading: isDesktop(width)
        ? null
        : AppleBackButton(
            label: l.back,
            onPressed: () => Navigator.pop(context),
          ),
      actions: [
        IconButton(
          onPressed: localValidationValid ? saveData : null,
          icon: const Icon(CupertinoIcons.checkmark),
          tooltip: l.save,
        ),
        const SizedBox(width: 6),
      ],
      onRefresh: () async => fetchData(),
      slivers: [
        if (loadStatus == LoadStatus.loading)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppleLoading(label: l.loadingEncryptionSettings),
          ),

        if (loadStatus == LoadStatus.error)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppleEmptyState(
              icon: CupertinoIcons.exclamationmark_triangle,
              title: l.encryptionSettingsNotLoaded,
              color: p.red,
            ),
          ),

        if (loadStatus == LoadStatus.loaded) ...[
          if (_dataValidApi == false && (validDataError != null || encryptionResultMessage != null))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: AppleCard(
                  color: p.pill(p.red),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        color: p.red,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          validDataError ?? encryptionResultMessage ?? l.unknownError,
                          style: TextStyle(fontSize: 15, height: 1.3, color: p.label),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: AppleListSection(
              title: l.enabledProtocols,
              margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              children: [
                AppleSwitchListTile(
                  icon: CupertinoIcons.lock_shield,
                  iconColor: p.tint,
                  title: l.enableEncryption,
                  subtitle: l.enableEncryptionTypes,
                  value: enabled,
                  onChanged: (value) {
                    setState(() => enabled = value);
                    onEditValidate();
                  },
                ),
                AppleSwitchListTile(
                  icon: CupertinoIcons.lock,
                  iconColor: p.green,
                  title: l.dnsOverTls,
                  subtitle: '${protocolPort(tlsPort)} · '
                    '${fetched?.validCert == true ? l.certificateValid : l.certificateInvalid}',
                  value: enabled && tlsPort != null,
                  // A protocol of a server that does not serve anything at all
                  // cannot be moved, the same rule the fields of the form follow.
                  onChanged: enabled
                    ? (value) => movePort(
                        controller: tlsPortController,
                        on: value,
                        reported: fetched?.portDnsOverTls,
                        fallback: 853,
                      )
                    : null,
                ),
                AppleSwitchListTile(
                  icon: CupertinoIcons.lock,
                  iconColor: p.teal,
                  title: l.dnsOverHttps,
                  subtitle: protocolPort(httpsPort),
                  value: enabled && httpsPort != null,
                  onChanged: enabled
                    ? (value) => movePort(
                        controller: httpsPortController,
                        on: value,
                        reported: fetched?.portHttps,
                        fallback: 443,
                      )
                    : null,
                ),
                AppleSwitchListTile(
                  icon: CupertinoIcons.lock,
                  iconColor: p.indigo,
                  title: l.dnsOverQuic,
                  subtitle: protocolPort(quicPort),
                  value: enabled && quicPort != null,
                  onChanged: enabled
                    ? (value) => movePort(
                        controller: dnsOverQuicPortController,
                        on: value,
                        reported: fetched?.portDnsOverQuic,
                        fallback: 853,
                      )
                    : null,
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: AppleListSection(
              title: l.certificates,
              children: [
                if (subject != null)
                  AppleListTile(
                    title: l.subject,
                    value: subject,
                    showChevron: false,
                    onTap: () => copyToClipboard(
                      value: subject,
                      successMessage: l.copiedClipboard,
                    ),
                  ),
                if (issuer != null)
                  AppleListTile(
                    title: l.issuer,
                    value: issuer,
                    showChevron: false,
                    onTap: () => copyToClipboard(
                      value: issuer,
                      successMessage: l.copiedClipboard,
                    ),
                  ),
                if (fingerprint != null)
                  AppleListTile(
                    title: l.sha256Fingerprint,
                    value: shortenFingerprint(fingerprint),
                    showChevron: false,
                    onTap: () => copyToClipboard(
                      value: fingerprint,
                      successMessage: l.copiedClipboard,
                    ),
                  ),
                if (notAfter != null)
                  AppleListTile(
                    title: l.expirationDate,
                    value: convertTimestampLocalTimezone(notAfter, 'yyyy-MM-dd'),
                    showChevron: false,
                  ),
                if (hostNames.isNotEmpty)
                  AppleListTile(
                    title: l.hostNames,
                    value: hostNames.join(' · '),
                    showChevron: false,
                  ),
                if (typedCertificate && validation?.validChain != null)
                  statusRow(
                    validation!.validChain ?? false,
                    validation.validChain == true
                      ? l.validCertificateChain
                      : l.invalidCertificateChain,
                  ),
                AppleListTile(
                  title: l.resetSettings,
                  icon: CupertinoIcons.arrow_2_circlepath,
                  iconColor: p.orange,
                  onTap: () => showDialog(
                    context: context,
                    builder: (ctx) => ResetSettingsModal(onConfirm: resetSettings),
                  ),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(child: AppleFormGroupLabel(l.serverConfiguration)),
          SliverToBoxAdapter(
            child: AppleTextField(
              label: l.domainName,
              helper: l.domainNameDescription,
              helperMaxLines: 4,
              icon: CupertinoIcons.link,
              controller: domainNameController,
              error: domainError,
              enabled: enabled,
              onChanged: (value) {
                setState(() => domainError = validateDomain(context, value));
                onEditValidate();
              },
            ),
          ),
          SliverToBoxAdapter(
            child: AppleTextField(
              label: l.httpsPort,
              icon: CupertinoIcons.number,
              controller: httpsPortController,
              error: httpsPortError,
              enabled: enabled,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() => httpsPortError = validatePort(context, value));
                onEditValidate();
              },
            ),
          ),
          SliverToBoxAdapter(
            child: AppleTextField(
              label: l.tlsPort,
              icon: CupertinoIcons.number,
              controller: tlsPortController,
              error: tlsPortError,
              enabled: enabled,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() => tlsPortError = validatePort(context, value));
                onEditValidate();
              },
            ),
          ),
          SliverToBoxAdapter(
            child: AppleTextField(
              label: l.dnsOverQuicPort,
              icon: CupertinoIcons.number,
              controller: dnsOverQuicPortController,
              error: dnsOverQuicPortError,
              enabled: enabled,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() => dnsOverQuicPortError = validatePort(context, value));
                onEditValidate();
              },
            ),
          ),
          SliverToBoxAdapter(
            child: AppleListSection(
              children: [
                AppleSwitchListTile(
                  title: l.redirectHttps,
                  value: redirectHttps,
                  onChanged: enabled
                    ? (value) {
                        setState(() => redirectHttps = value);
                        onEditValidate();
                      }
                    : null,
                ),
                if (_plainDns != null)
                  AppleSwitchListTile(
                    title: l.enablePlainDns,
                    subtitle: l.enablePlainDnsDescription,
                    value: _plainDns!,
                    onChanged: enabled
                      ? (value) => setState(() => _plainDns = value)
                      : null,
                  ),
              ],
            ),
          ),

          SliverToBoxAdapter(child: AppleFormGroupLabel(l.certificateSource)),
          SliverToBoxAdapter(
            child: AppleListSection(
              footer: l.certificatesDescription,
              children: [
                AppleListTile(
                  title: l.certificateFilePath,
                  enabled: enabled,
                  showChevron: false,
                  onTap: enabled
                    ? () {
                        setState(() => certificateOption = 0);
                        onEditValidate();
                      }
                    : null,
                  trailing: check(certificateOption == 0),
                ),
                AppleListTile(
                  title: l.pasteCertificateContent,
                  enabled: enabled,
                  showChevron: false,
                  onTap: enabled
                    ? () {
                        setState(() => certificateOption = 1);
                        onEditValidate();
                      }
                    : null,
                  trailing: check(certificateOption == 1),
                ),
              ],
            ),
          ),
          if (certificateOption == 0)
            SliverToBoxAdapter(
              child: AppleTextField(
                label: l.certificatePath,
                icon: CupertinoIcons.doc_text,
                controller: certificatePathController,
                error: certificatePathError,
                enabled: enabled,
                onChanged: (value) {
                  setState(() => certificatePathError = validatePath(context, value));
                  onEditValidate();
                },
              ),
            ),
          if (certificateOption == 1)
            SliverToBoxAdapter(
              child: AppleTextField(
                label: l.certificateContent,
                helper: l.enterOnlyCertificate,
                helperMaxLines: 2,
                icon: CupertinoIcons.doc_text,
                controller: certificateContentController,
                error: certificateContentError,
                enabled: enabled,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                onChanged: (value) {
                  setState(() =>
                    certificateContentError = validateCertificate(context, value));
                  onEditValidate();
                },
              ),
            ),

          SliverToBoxAdapter(child: AppleFormGroupLabel(l.privateKey)),
          SliverToBoxAdapter(
            child: AppleListSection(
              children: [
                AppleListTile(
                  title: l.privateKeyFile,
                  enabled: enabled,
                  showChevron: false,
                  onTap: enabled
                    ? () {
                        setState(() => privateKeyOption = 0);
                        onEditValidate();
                      }
                    : null,
                  trailing: check(privateKeyOption == 0),
                ),
                AppleListTile(
                  title: l.pastePrivateKey,
                  enabled: enabled,
                  showChevron: false,
                  onTap: enabled
                    ? () {
                        setState(() => privateKeyOption = 1);
                        onEditValidate();
                      }
                    : null,
                  trailing: check(privateKeyOption == 1),
                ),
                if (privateKeyOption == 1)
                  AppleSwitchListTile(
                    title: l.usePreviousKey,
                    value: usePreviouslySavedKey,
                    onChanged: (value) {
                      setState(() => usePreviouslySavedKey = value);
                      onEditValidate();
                    },
                  ),
              ],
            ),
          ),
          if (privateKeyOption == 0)
            SliverToBoxAdapter(
              child: AppleTextField(
                label: l.privateKeyPath,
                icon: CupertinoIcons.doc_text,
                controller: privateKeyPathController,
                error: privateKeyPathError,
                enabled: enabled,
                onChanged: (value) {
                  setState(() => privateKeyPathError = validatePath(context, value));
                  onEditValidate();
                },
              ),
            ),
          if (privateKeyOption == 1)
            SliverToBoxAdapter(
              child: AppleTextField(
                label: l.pastePrivateKey,
                helper: l.enterOnlyPrivateKey,
                helperMaxLines: 2,
                icon: CupertinoIcons.doc_text,
                controller: pastePrivateKeyController,
                error: pastePrivateKeyError,
                enabled: enabled ? !usePreviouslySavedKey : false,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                onChanged: (value) {
                  setState(() =>
                    pastePrivateKeyError = validatePrivateKey(context, value));
                  onEditValidate();
                },
              ),
            ),
          if (certKeyValid != null &&
            (privateKeyPathController.text != '' ||
              pastePrivateKeyController.text != '' ||
              usePreviouslySavedKey == true))
            SliverToBoxAdapter(
              child: AppleListSection(
                children: [
                  if (certKeyValid!.validKey != null)
                    statusRow(
                      certKeyValid!.validKey ?? false,
                      certKeyValid!.validKey == true
                        ? l.validPrivateKey
                        : l.invalidPrivateKey,
                    ),
                  if (certKeyValid!.validPair != null &&
                    certKeyValid!.validPair == false)
                    statusRow(false, l.keysNotMatch),
                  if (keyType != null)
                    AppleListTile(
                      title: l.keyType,
                      value: keyType,
                      showChevron: false,
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// The fingerprint the server reports as plain hex, in the colon-separated
/// uppercase form a certificate is read by. Null when the server sent none,
/// which a stock AdGuard Home always does.
String? formatFingerprint(String? hex) {
  if (hex == null || hex.isEmpty) return null;

  final pairs = <String>[];
  for (var i = 0; i + 2 <= hex.length; i += 2) {
    pairs.add(hex.substring(i, i + 2).toUpperCase());
  }
  return pairs.join(':');
}

/// The fingerprint shortened the way the design layer draws it: the first two
/// pairs and the last one, since the middle of a hash carries nothing a person
/// compares by eye. The row copies the whole value.
String shortenFingerprint(String formatted) =>
    formatted.length <= 8
      ? formatted
      : '${formatted.substring(0, 5)}:…:${formatted.substring(formatted.length - 2)}';
