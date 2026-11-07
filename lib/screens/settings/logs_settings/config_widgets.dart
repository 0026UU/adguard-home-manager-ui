import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/constants/regexps.dart';
import 'package:adguard_home_manager/screens/settings/logs_settings/logs_settings.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// The draftable sections of the query-log page.
///
/// Returned as slivers, because the page is one [AppleScreen] scroll rather
/// than a list of its own: the host owns the pull handle, the side margins and
/// the bottom spacer, and these sections have to fall into the same rhythm as
/// the rest of the settings hub.
class LogsConfigOptions extends StatelessWidget {
  final bool generalSwitch;
  final void Function(bool) updateGeneralSwitch;
  final bool anonymizeClientIp;
  final void Function(bool) updateAnonymizeClientIp;
  final List<String> retentionItems; 
  final String? retentionTime;
  final void Function(String?) updateRetentionTime;
  final void Function() onClear;
  final void Function() onConfirm;
  final List<DomainListItemController> ignoredDomainsControllers;
  final void Function(List<DomainListItemController>) updateIgnoredDomainsControllers;
  final TextEditingController customTimeController;
  final String? customTimeError;
  final void Function(String) validateCustomTime;

  const LogsConfigOptions({
    super.key,
    required this.generalSwitch,
    required this.updateGeneralSwitch,
    required this.anonymizeClientIp,
    required this.updateAnonymizeClientIp,
    required this.retentionItems,
    required this.retentionTime,
    required this.updateRetentionTime,
    required this.onClear,
    required this.onConfirm,
    required this.ignoredDomainsControllers,
    required this.updateIgnoredDomainsControllers,
    required this.customTimeController,
    required this.customTimeError,
    required this.validateCustomTime,
  });

  @override
  Widget build(BuildContext context) {
    const Uuid uuid = Uuid();
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    final List<String> dropdownItemTranslation = [
      l.custom,
      l.hours6,
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
      updateIgnoredDomainsControllers(
        ignoredDomainsControllers.map((entry) {
          if (entry.id != id) return entry;
          return DomainListItemController(
            id: id, 
            controller: entry.controller, 
            error: error
          );
        }).toList()
      );
    }

    return SliverList.list(
      children: [
        AppleListSection(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          children: [
            AppleSwitchListTile(
              title: l.enableLog,
              value: generalSwitch,
              onChanged: updateGeneralSwitch,
            ),
          ],
        ),
        AppleListSection(
          margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          children: [
            AppleSwitchListTile(
              title: l.anonymizeClientIp,
              value: anonymizeClientIp,
              onChanged: updateAnonymizeClientIp,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          child: DropdownButtonFormField<String>(
            items: retentionItems.asMap().entries.map((item) => DropdownMenuItem(
              value: item.value,
              child: Text(dropdownItemTranslation[item.key]),
            )).toList(),
            initialValue: retentionTime,
            isExpanded: true,
            style: AppleInput.style(context),
            onChanged: (value) => updateRetentionTime(value.toString()),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            decoration: AppleInput.decoration(context, label: l.retentionTime),
          ),
        ),
        if (retentionTime == "custom") Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          child: AppleTextField(
            controller: customTimeController,
            onChanged: validateCustomTime,
            label: l.customTimeInHours,
            error: customTimeError,
            icon: CupertinoIcons.clock,
            keyboardType: TextInputType.number,
            padding: EdgeInsets.zero,
          ),
        ),
        AppleListSection(
          title: l.ignoredDomains,
          // The page keeps its big empty state for "could not be read", so an
          // empty list gets the quieter caption under the card.
          footer:
              ignoredDomainsControllers.isEmpty ? l.noIgnoredDomainsAdded : null,
          headerTrailing: AppleHeaderAction(
            label: l.addItem,
            onPressed: () => updateIgnoredDomainsControllers([
              ...ignoredDomainsControllers,
              DomainListItemController(
                id: uuid.v4(),
                controller: TextEditingController(),
                error: false
              ),
            ]),
          ),
          margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          children: [
            for (final controller in ignoredDomainsControllers)
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
                      onPressed: () => updateIgnoredDomainsControllers(
                        ignoredDomainsControllers.where((e) => e.id != controller.id).toList()
                      ),
                      tooltip: l.removeDomain,
                      icon: Icon(CupertinoIcons.minus_circle, size: 19, color: p.red),
                    )
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
