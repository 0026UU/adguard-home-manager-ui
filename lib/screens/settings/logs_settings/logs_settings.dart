import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/screens/settings/logs_settings/config_widgets.dart';
import 'package:adguard_home_manager/widgets/load_status_widgets.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/models/querylog_config.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';

class DomainListItemController {
  final String id;
  final TextEditingController controller;
  bool error;

  DomainListItemController({
    required this.id,
    required this.controller,
    required this.error
  });
}

class LogsSettings extends StatefulWidget {
  const LogsSettings({super.key});

  @override
  State<LogsSettings> createState() => _LogsSettingsState();
}

class _LogsSettingsState extends State<LogsSettings> {
  final Uuid uuid = const Uuid();

  bool generalSwitch = false;
  bool anonymizeClientIp = false;
  String? retentionTime;
  List<DomainListItemController> _ignoredDomainsControllers = [];
  final _customTimeController = TextEditingController();
  String? _customTimeError;

  List<String> retentionItems = [
    "custom",
    "21600000",
    "86400000",
    "604800000",
    "2592000000",
    "7776000000"
  ];

  LoadStatus loadStatus = LoadStatus.loading;

  void loadData() async {
    final serversProvider = Provider.of<ServersProvider>(context, listen: false);

    final result = await serversProvider.apiClient2!.getQueryLogInfo();

    if (!mounted) return;
    if (result.successful == true) {
      final data = result.content as QueryLogConfig;
      setState(() {
        generalSwitch = data.enabled ?? false;
        anonymizeClientIp = data.anonymizeClientIp ?? false;
        retentionTime = retentionItems.contains(data.interval.toString()) ? data.interval.toString() : "custom";
        if (data.interval != null && !retentionItems.contains(data.interval.toString())) {
          _customTimeController.text = (data.interval!/3.6e+6).toInt().toString();
        }
        if (data.ignored != null) {
          _ignoredDomainsControllers = data.ignored!.map((e) => DomainListItemController(
            id: uuid.v4(), 
            controller: TextEditingController(text: e), 
            error: false
          )).toList();
        }
        loadStatus = LoadStatus.loaded;
      });
    }
    else {
      setState(() => loadStatus = LoadStatus.error);
    }
  }

  void validateCustomTime(String value) {
    try {
      final regex = RegExp(r'^\d+$');
      final parsed = int.parse(value);
      if (!regex.hasMatch(value)) {
        setState(() => _customTimeError = AppLocalizations.of(context)!.invalidTime);
      }
      else if (parsed < 1) {
        setState(() => _customTimeError = AppLocalizations.of(context)!.notLess1Hour);
      }
      else {
        setState(() => _customTimeError = null);
      }
    } catch (_) {
      setState(() => _customTimeError = AppLocalizations.of(context)!.invalidTime);
    }
  }

  bool checkValidValues() {
    if (_ignoredDomainsControllers.where((d) =>  d.controller.text == "" || d.error == true).isNotEmpty) {
      return false;
    }
    if (retentionTime == "custom" && (_customTimeError != null || _customTimeController.text == "")) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    loadData();
    super.initState();
  }
  
  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final width = MediaQuery.sizeOf(context).width;

    final validValues = checkValidValues();

    void clearQueries() async {
      ProcessModal processModal = ProcessModal();
      processModal.open(AppLocalizations.of(context)!.updatingSettings);

      final result = await serversProvider.apiClient2!.clearLogs();

      processModal.close();

      if (!context.mounted) return;

      if (result.successful == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.logsCleared, 
          color: p.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.logsNotCleared, 
          color: p.red
        );
      }
    }

    void updateConfig() async {
      ProcessModal processModal = ProcessModal();
      processModal.open(AppLocalizations.of(context)!.updatingSettings);

      final result = await serversProvider.apiClient2!.updateQueryLogParameters(
        data: {
          "enabled": generalSwitch,
          "interval": retentionTime == "custom" ? int.parse(_customTimeController.text)*3.6e+6 : int.parse(retentionTime!) ,
          "anonymize_client_ip": anonymizeClientIp,
          "ignored": _ignoredDomainsControllers.map((e) => e.controller.text).toList()
        }
      );
      
      processModal.close();

      if (!context.mounted) return;

      if (result.successful == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.logsConfigUpdated, 
          color: p.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.logsConfigNotUpdated, 
          color: p.red
        );
      }
    }

    return AppleScreen(
      title: l.logsSettings,
      leading: isDesktop(width)
        ? null
        : AppleBackButton(
            label: l.back,
            onPressed: () => Navigator.pop(context),
          ),
      actions: [
        if (loadStatus == LoadStatus.loaded) IconButton(
          onPressed: validValues ? () => updateConfig() : null, 
          icon: const Icon(CupertinoIcons.checkmark),
          tooltip: l.save,
        ),
        if (loadStatus == LoadStatus.loaded) IconButton(
          // The server has no undo and no trash for these rows, so the tap
          // that asks to clear them is not the tap that empties them.
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => AppleAlertDialog(
              title: AppLocalizations.of(ctx)!.clearLogs,
              message: AppLocalizations.of(ctx)!.clearLogsConfirm,
              actions: [
                AppleSheetAction(label: AppLocalizations.of(ctx)!.cancel),
                AppleSheetAction(
                  label: AppLocalizations.of(ctx)!.clearLogs,
                  color: p.red,
                  destructive: true,
                  onTap: clearQueries,
                ),
              ],
            ),
          ),
          icon: Icon(CupertinoIcons.trash, color: p.red),
          tooltip: l.clearLogs,
        ),
      ],
      slivers: [
        if (loadStatus == LoadStatus.loading)
          SliverFillRemaining(
            hasScrollBody: false,
            child: LoadingData(text: l.loadingLogsSettings),
          ),

        if (loadStatus == LoadStatus.loaded)
          LogsConfigOptions(
            generalSwitch: generalSwitch, 
            updateGeneralSwitch: (v) => setState(() => generalSwitch = v), 
            anonymizeClientIp: anonymizeClientIp, 
            updateAnonymizeClientIp: (v) => setState(() => anonymizeClientIp = v), 
            retentionItems: retentionItems, 
            retentionTime: retentionTime, 
            updateRetentionTime: (v) => setState(() => retentionTime = v), 
            onClear: clearQueries, 
            onConfirm: updateConfig,
            ignoredDomainsControllers: _ignoredDomainsControllers,
            updateIgnoredDomainsControllers: (v) => setState(() => _ignoredDomainsControllers = v),
            customTimeController: _customTimeController,
            customTimeError: _customTimeError,
            validateCustomTime: validateCustomTime,
          ),

        if (loadStatus == LoadStatus.error)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorLoadData(
              text: l.logSettingsNotLoaded,
              onRetry: () async {
                setState(() => loadStatus = LoadStatus.loading);
                loadData();
              },
            ),
          ),
      ],
    );
  }
}