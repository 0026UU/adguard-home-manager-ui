// ignore_for_file: use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/constants/regexps.dart';
import 'package:adguard_home_manager/functions/get_filtered_status.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Asks the server whether one host would be blocked by the current filters.
class CheckHostModal extends StatelessWidget {
  final bool dialog;

  const CheckHostModal({super.key, required this.dialog});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AppleFormModal(
      title: l.checkHostFiltered,
      icon: CupertinoIcons.shield,
      dialog: dialog,
      body: const _Content(),
    );
  }
}

class _Content extends StatefulWidget {
  const _Content();

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  final TextEditingController domainController = TextEditingController();
  String? domainError;

  Widget? resultWidget;

  void validateDomain(String value) {
    if (Regexps.domain.hasMatch(value)) {
      setState(() => domainError = null);
    } else {
      setState(
          () => domainError = AppLocalizations.of(context)!.domainNotValid);
    }
  }

  Widget checking() {
    return SizedBox(
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CupertinoActivityIndicator(radius: 9),
          const SizedBox(width: 14),
          Text(
            AppLocalizations.of(context)!.checkingHost,
            style:
                TextStyle(fontSize: 15, color: ApplePalette.of(context).label2),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    void checkHost() async {
      setState(() => resultWidget = checking());

      final result = await serversProvider.apiClient2!
          .checkHostFiltered(host: domainController.text);
      if (!mounted) return;

      if (result.successful == true) {
        final status = getFilteredStatus(
            context, appConfigProvider, result.content['reason'], true);
        final p = ApplePalette.of(context);
        final statusColor = status['filtered'] == true
            ? (appConfigProvider.useThemeColorForStatus == true
                ? p.label3
                : p.red)
            : (appConfigProvider.useThemeColorForStatus == true
                ? p.tint
                : p.green);
        if (mounted) {
          setState(() => resultWidget = Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    status['icon'],
                    size: 18,
                    color: statusColor,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    status['label'],
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  )
                ],
              ));
        }
      } else {
        setState(() => resultWidget = Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.nosign,
                  size: 18,
                  color: ApplePalette.of(context).red,
                ),
                const SizedBox(width: 10),
                Text(
                  AppLocalizations.of(context)!.check,
                  style: TextStyle(
                    color: ApplePalette.of(context).red,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                )
              ],
            ));
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Wrap(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextFormField(
                    controller: domainController,
                    style: AppleInput.style(context),
                    onChanged: validateDomain,
                    decoration: AppleInput.decoration(
                      context,
                      icon: CupertinoIcons.globe,
                      error: domainError,
                      label: AppLocalizations.of(context)!.domain,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Center(
                    child: resultWidget ??
                        Text(
                          AppLocalizations.of(context)!.insertDomain,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: ApplePalette.of(context).label2,
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        AppleFormFooter(
          confirmLabel: AppLocalizations.of(context)!.check,
          cancelLabel: AppLocalizations.of(context)!.close,
          confirmEnabled: domainController.text != '' && domainError == null,
          onConfirm: () => checkHost(),
        ),
      ],
    );
  }
}
