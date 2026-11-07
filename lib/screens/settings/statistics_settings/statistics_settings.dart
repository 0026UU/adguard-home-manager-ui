import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/constants/regexps.dart';
import 'package:adguard_home_manager/screens/settings/logs_settings/logs_settings.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/load_status_widgets.dart';

import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/models/statistics_config.dart';
import 'package:adguard_home_manager/constants/enums.dart';

class StatisticsSettings extends StatefulWidget {
  const StatisticsSettings({super.key});

  @override
  State<StatisticsSettings> createState() => _StatisticsSettingsState();
}

class _StatisticsSettingsState extends State<StatisticsSettings> {
  final Uuid uuid = const Uuid();
  LoadStatus _loadStatus = LoadStatus.loading;
  bool _generalSwitch = false;
  final List<String> _retentionItems = [
    "custom",
    "86400000",
    "604800000",
    "2592000000",
    "7776000000"
  ];
  final _customTimeController = TextEditingController();
  String? _customTimeError;
  String? _retentionTime;
  List<DomainListItemController> _ignoredDomainsControllers = [];

  void loadData() async {
    final serversProvider = Provider.of<ServersProvider>(context, listen: false);

    final result = await serversProvider.apiClient2!.getStatisticsConfig();

    if (!mounted) return;
    if (result.successful == true) {
      final data = result.content as StatisticsConfig;
      setState(() {
        _generalSwitch = data.enabled ?? false;
        if (_retentionItems.contains(data.interval.toString())) {
          _retentionTime = data.interval.toString();
        }
        else if (data.interval != null) {
          _retentionTime = "custom";
          _customTimeController.text = Duration(milliseconds: data.interval!).inHours.toString();
        }
        if (data.ignored != null) {
          _ignoredDomainsControllers = data.ignored!.map((e) => DomainListItemController(
            id: uuid.v4(), 
            controller: TextEditingController(text: e), 
            error: false
          )).toList();
        }
        _loadStatus = LoadStatus.loaded;
      });
    }
    else {
      setState(() => _loadStatus = LoadStatus.error);
    }
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

    final List<String> dropdownItemTranslation = [
      l.custom,
      l.hours24,
      l.days7,
      l.days30,
      l.days90,
    ];
    

    void validateDomain(String value, String id) {
      bool error = false;
      if (Regexps.domain.hasMatch(value)) {
        error = false;
      }
      else {
        error = true;
      }
      setState(() {
        _ignoredDomainsControllers = _ignoredDomainsControllers.map((entry) {
          if (entry.id != id) return entry;
          return DomainListItemController(
            id: id, 
            controller: entry.controller, 
            error: error
          );
        }).toList();
      });
    }

    void validateCustomTime(String v) {
      try {
        final regex = RegExp(r'^\d+$');
        final parsed = int.parse(v);
        if (!regex.hasMatch(v)) {
          setState(() => _customTimeError = l.invalidTime);
        }
        else if (parsed < 1) {
          setState(() => _customTimeError = l.notLess1Hour);
        }
        else {
          setState(() => _customTimeError = null);
        }
      } catch (_) {
        setState(() => _customTimeError = l.invalidTime);
      }
    }

    /// Milliseconds the server should keep statistics for, or null when the
    /// widgets have not settled on a number yet.
    int? readInterval() {
      if (_retentionTime == "custom") {
        final hours = int.tryParse(_customTimeController.text.trim());
        if (hours == null || hours < 1) return null;
        return Duration(hours: hours).inMilliseconds;
      }

      return int.tryParse(_retentionTime ?? "");
    }

    void updateConfig() async {
      // Reading the interval used to happen inside the request, after the
      // sheet had opened. A retention time that was not a number — which is
      // what the dropdown holds before the config has been read, since its
      // first entry is "custom" — threw, the sheet was never closed, and the
      // screen could not be dismissed at all.
      final interval = readInterval();
      if (interval == null) {
        setState(() => _customTimeError = l.invalidTime);
        return;
      }

      ProcessModal processModal = ProcessModal();
      processModal.open(l.updatingSettings);

      var saved = false;
      try {
        final result = await serversProvider.apiClient2!.updateStatisticsSettings(
          body: {
            "enabled": _generalSwitch,
            "interval": interval,
            "ignored": _ignoredDomainsControllers.map((e) => e.controller.text).toList()
          }
        );
        saved = result.successful == true;
      } finally {
        processModal.close();
      }

      if (!context.mounted) return;

      if (saved) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.statisticsConfigUpdated, 
          color: p.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.statisticsConfigNotUpdated, 
          color: p.red
        );
      }
    }

    // Nothing on this page is worth saving until the server has told us what
    // it already uses: saving over a failed load would push the defaults.
    final validValues = _loadStatus == LoadStatus.loaded &&
      _ignoredDomainsControllers.where(
        (d) =>  d.controller.text == "" || d.error == true
      ).isEmpty &&
      readInterval() != null;

    Widget fill(Widget child) => SliverFillRemaining(
      hasScrollBody: false,
      child: child,
    );

    return AppleScreen(
      title: l.statisticsSettings,
      actions: [
        IconButton(
          onPressed: validValues ? () => updateConfig() : null, 
          icon: const Icon(CupertinoIcons.checkmark),
          tooltip: l.save,
        ),
      ],
      slivers: [
        if (_loadStatus == LoadStatus.loading)
          fill(LoadingData(text: l.loadingStatisticsSettings)),

        if (_loadStatus == LoadStatus.error)
          fill(ErrorLoadData(
            text: l.statisticsSettingsLoadError,
            onRetry: () async {
              setState(() => _loadStatus = LoadStatus.loading);
              loadData();
            },
          )),

        if (_loadStatus == LoadStatus.loaded) ...[
          SliverToBoxAdapter(
            child: AppleListSection(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              children: [
                AppleSwitchListTile(
                  title: l.enableLog,
                  value: _generalSwitch,
                  onChanged: (v) => setState(() => _generalSwitch = v),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
              child: DropdownButtonFormField<String>(
                items: _retentionItems.asMap().entries.map((item) => DropdownMenuItem(
                  value: item.value,
                  child: Text(dropdownItemTranslation[item.key]),
                )).toList(),
                initialValue: _retentionTime,
                isExpanded: true,
                style: AppleInput.style(context),
                onChanged: (value) => setState(() {
                  if (value != null && value != "custom") {
                    _customTimeError = null;
                    _customTimeController.text = "";
                  }
                  _retentionTime = value;
                }),
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                decoration: AppleInput.decoration(context, label: l.retentionTime),
              ),
            ),
          ),
          if (_retentionTime == "custom") SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
              child: AppleTextField(
                controller: _customTimeController,
                onChanged: validateCustomTime,
                label: l.customTimeInHours,
                error: _customTimeError,
                icon: CupertinoIcons.clock,
                keyboardType: TextInputType.number,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AppleListSection(
              title: l.ignoredDomains,
              // The big empty state belongs to "the settings could not be
              // read", so an empty list gets the quieter caption below.
              footer: _ignoredDomainsControllers.isEmpty
                ? l.noIgnoredDomainsAdded
                : null,
              headerTrailing: AppleHeaderAction(
                label: l.addItem,
                onPressed: () => setState(() => _ignoredDomainsControllers = [
                  ..._ignoredDomainsControllers,
                  DomainListItemController(
                    id: uuid.v4(), 
                    controller: TextEditingController(),
                    error: false
                  ),
                ]),
              ),
              margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
              children: [
                for (final controller in _ignoredDomainsControllers)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: AppleTextField(
                            controller: controller.controller,
                            onChanged: (v) => validateDomain(v, controller.id),
                            label: l.domain,
                            icon: CupertinoIcons.link,
                            error: controller.error ? l.invalidDomain : null,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _ignoredDomainsControllers = _ignoredDomainsControllers.where((e) => e.id != controller.id).toList()),
                          icon: Icon(CupertinoIcons.minus_circle, size: 19, color: p.red),
                          tooltip: l.removeDomain,
                        )
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
