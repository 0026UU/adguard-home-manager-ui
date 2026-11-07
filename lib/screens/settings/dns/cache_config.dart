// ignore_for_file: use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/settings/dns/clear_dns_cache_dialog.dart';

import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/dns_provider.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/functions/clear_dns_cache.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';

class CacheConfigDnsScreen extends StatefulWidget {
  const CacheConfigDnsScreen({super.key});

  @override
  State<CacheConfigDnsScreen> createState() => _CacheConfigDnsScreenState();
}

class _CacheConfigDnsScreenState extends State<CacheConfigDnsScreen> {
  final TextEditingController cacheSizeController = TextEditingController();
  String? cacheSizeError;

  final TextEditingController overrideMinTtlController = TextEditingController();
  String? overrideMinTtlError;

  final TextEditingController overrideMaxTtlController = TextEditingController();
  String? overrideMaxTtlError;

  bool optimisticCache = false;

  bool validData = false;

  void checkValidData() {
    if (
      cacheSizeController.text != '' &&
      cacheSizeError == null &&
      overrideMinTtlController.text != '' && 
      overrideMinTtlError == null && 
      overrideMaxTtlController.text != '' && 
      overrideMaxTtlError == null
    ) {
      setState(() => validData = true);
    }
    else {
      setState(() => validData = false);
    }
  }

  @override
  void initState() {
    final dnsProvider = Provider.of<DnsProvider>(context, listen: false);

    cacheSizeController.text = dnsProvider.dnsInfo!.cacheSize.toString();
    overrideMinTtlController.text = dnsProvider.dnsInfo!.cacheTtlMin.toString();
    overrideMaxTtlController.text = dnsProvider.dnsInfo!.cacheTtlMax.toString();
    optimisticCache = dnsProvider.dnsInfo!.cacheOptimistic ?? false;
    validData = true;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final dnsProvider = Provider.of<DnsProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final width = MediaQuery.of(context).size.width;
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    void saveData() async {
      ProcessModal processModal = ProcessModal();
      processModal.open(l.savingConfig);

      final result = await dnsProvider.saveCacheCacheConfig({
        "cache_size": int.parse(cacheSizeController.text),
        "cache_ttl_min": int.parse(overrideMinTtlController.text),
        "cache_ttl_max": int.parse(overrideMaxTtlController.text),
        "cache_optimistic": optimisticCache
      });

      processModal.close();

      if (result.successful == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.dnsConfigSaved, 
          color: p.green
        );
      }
      else if (result.successful== false && result.statusCode == 400) {
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
    Widget numericField({
      required TextEditingController controller,
      required String label,
      required IconData icon,
      String? helper,
      String? error,
      required void Function(String) onChanged,
    }) {
      return SliverToBoxAdapter(
        child: AppleTextField(
          controller: controller,
          onChanged: onChanged,
          icon: icon,
          helper: helper,
          helperMaxLines: 10,
          label: label,
          error: error,
          keyboardType: TextInputType.number,
        ),
      );
    }

    void clearCache() async {
      final result = await clearDnsCache(context, serversProvider.selectedServer!);
      if (result.successful == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider, 
          label: l.dnsCacheCleared, 
          color: p.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider, 
          label: l.dnsCacheNotCleared, 
          color: p.red
        );
      }
    }

    return AppleScreen(
      title: l.dnsCacheConfig,
      subtitle: l.dnsCacheConfigDescription,
      leading: isDesktop(width)
        ? null
        : AppleBackButton(
            label: l.back,
            onPressed: () => Navigator.pop(context),
          ),
      actions: [
        IconButton(
          onPressed: validData == true
            ? () => saveData()
            : null, 
          icon: const Icon(CupertinoIcons.checkmark),
          tooltip: l.save,
        ),
      ],
      slivers: [
        numericField(
          controller: cacheSizeController, 
          label: l.cacheSize, 
          icon: CupertinoIcons.number,
          helper: l.inBytes, 
          error: cacheSizeError, 
          onChanged: (value) {
            if (int.tryParse(value) != null) {
              setState(() => cacheSizeError = null);
            }
            else {
              setState(() => cacheSizeError = l.valueNotNumber);
            }
            checkValidData();
          }
        ),
        numericField(
          controller: overrideMinTtlController, 
          label: l.overrideMinimumTtl, 
          icon: CupertinoIcons.timer,
          helper: l.overrideMinimumTtlDescription, 
          error: overrideMinTtlError, 
          onChanged: (value) {
            if (int.tryParse(value) != null) {
              setState(() => overrideMinTtlError = null);
            }
            else {
              setState(() => overrideMinTtlError = l.valueNotNumber);
            }
            checkValidData();
          }
        ),
        numericField(
          controller: overrideMaxTtlController, 
          label: l.overrideMaximumTtl, 
          icon: CupertinoIcons.timer,
          helper: l.overrideMaximumTtlDescription, 
          error: overrideMaxTtlError, 
          onChanged: (value) {
            if (int.tryParse(value) != null) {
              setState(() => overrideMaxTtlError = null);
            }
            else {
              setState(() => overrideMaxTtlError = l.valueNotNumber);
            }
            checkValidData();
          }
        ),
        SliverToBoxAdapter(
          child: AppleListSection(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            children: [
              AppleSwitchListTile(
                icon: CupertinoIcons.arrow_2_circlepath,
                iconColor: p.orange,
                value: optimisticCache, 
                onChanged: (value) => setState(() => optimisticCache = value), 
                title: l.optimisticCaching,
                subtitle: l.optimisticCachingDescription,
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              // Emptied the way everything else here is emptied: a button in
              // the colour of what it gives up, opening the same question.
              child: AppleFormButton(
                label: l.clearDnsCache,
                background: p.red,
                foreground: Colors.white,
                onPressed: () => showDialog(
                  context: context, 
                  builder: (context) => ClearDnsCacheDialog(
                    onConfirm: clearCache
                  )
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}