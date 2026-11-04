import 'package:flutter/cupertino.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/option_box.dart';

/// Picks how often the server should refresh the filter lists.
class UpdateIntervalListsModal extends StatefulWidget {
  final int interval;
  final void Function(int) onChange;
  final bool dialog;

  const UpdateIntervalListsModal(
      {super.key,
      required this.interval,
      required this.onChange,
      required this.dialog});

  @override
  State<UpdateIntervalListsModal> createState() =>
      _UpdateIntervalListsModalState();
}

class _UpdateIntervalListsModalState extends State<UpdateIntervalListsModal> {
  int? selectedOption;

  void _updateRadioValue(int value) {
    setState(() {
      selectedOption = value;
    });
  }

  @override
  void initState() {
    selectedOption = widget.interval;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AppleFormModal(
      title: l.updateFrequency,
      icon: CupertinoIcons.clock,
      dialog: widget.dialog,
      body: _Content(
        selectedOption: selectedOption,
        onUpdateValue: _updateRadioValue,
        onConfirm: () => widget.onChange(selectedOption!),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final int? selectedOption;
  final void Function(int) onUpdateValue;
  final void Function() onConfirm;

  const _Content({
    required this.selectedOption,
    required this.onUpdateValue,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Wrap(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    runSpacing: 16,
                    children: [
                      FractionallySizedBox(
                        widthFactor: 0.5,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: OptionBox(
                            optionsValue: selectedOption,
                            itemValue: 0,
                            onTap: (v) => onUpdateValue(v as int),
                            label: AppLocalizations.of(context)!.never,
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: 0.5,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: OptionBox(
                            optionsValue: selectedOption,
                            itemValue: 1,
                            onTap: (v) => onUpdateValue(v as int),
                            label: AppLocalizations.of(context)!.hour1,
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: 0.5,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: OptionBox(
                            optionsValue: selectedOption,
                            itemValue: 12,
                            onTap: (v) => onUpdateValue(v as int),
                            label: AppLocalizations.of(context)!.hours12,
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: 0.5,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: OptionBox(
                            optionsValue: selectedOption,
                            itemValue: 24,
                            onTap: (v) => onUpdateValue(v as int),
                            label: AppLocalizations.of(context)!.hours24,
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: 0.5,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: OptionBox(
                            optionsValue: selectedOption,
                            itemValue: 72,
                            onTap: (v) => onUpdateValue(v as int),
                            label: AppLocalizations.of(context)!.days3,
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: 0.5,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: OptionBox(
                            optionsValue: selectedOption,
                            itemValue: 168,
                            onTap: (v) => onUpdateValue(v as int),
                            label: AppLocalizations.of(context)!.days7,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
        AppleFormFooter(
          confirmLabel: AppLocalizations.of(context)!.confirm,
          confirmEnabled: selectedOption != null,
          onConfirm: () {
            Navigator.pop(context);
            onConfirm();
          },
        ),
      ],
    );
  }
}
