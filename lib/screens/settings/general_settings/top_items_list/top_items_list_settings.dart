// ignore_for_file: use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/screens/settings/general_settings/top_items_list/reorderable_top_items_home.dart';
import 'package:adguard_home_manager/screens/settings/general_settings/top_items_list/show_hide_top_items_list.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';

/// Which of the dashboard's top lists are shown, and in what sequence.
///
/// Both halves edit the same stored list, so the page keeps one draft and
/// hands it to [AppConfigProvider.setHomeTopItemsOrder] once, from the
/// checkmark. Nothing is written while the user is still moving rows around.
class TopItemsListSettings extends StatefulWidget {
  const TopItemsListSettings({super.key});

  @override
  State<TopItemsListSettings> createState() => _TopItemsListSettingsState();
}

class _TopItemsListSettingsState extends State<TopItemsListSettings> {
  int _tab = 0;
  late List<HomeTopItems> _draft;

  @override
  void initState() {
    _draft = List<HomeTopItems>.from(
      Provider.of<AppConfigProvider>(context, listen: false).homeTopItemsOrder,
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final width = MediaQuery.of(context).size.width;
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    final saved = appConfigProvider.homeTopItemsOrder;
    final hasChanges = !listEquals(saved, _draft);

    Future<void> saveSettings() async {
      final stored = await appConfigProvider.setHomeTopItemsOrder(
        List<HomeTopItems>.from(_draft),
      );

      if (!mounted) return;

      if (stored) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.settingsSaved,
          color: p.green,
        );
      } else {
        // The preference did not make it to storage, so the draft goes back to
        // what is actually stored instead of holding a change that was lost.
        setState(
          () => _draft = List<HomeTopItems>.from(
            appConfigProvider.homeTopItemsOrder,
          ),
        );
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: l.settingsNotSaved,
          color: p.red,
        );
      }
    }

    return AppleScreen(
      title: l.topItemsOrder,
      subtitle: l.topItemsOrderDescription,
      leading: isDesktop(width)
          ? null
          : AppleBackButton(
              label: l.back,
              onPressed: () => Navigator.pop(context),
            ),
      header: AppleSegmented(
        labels: [l.reorder, l.showHide],
        selectedIndex: _tab,
        onChanged: (index) => setState(() => _tab = index),
      ),
      actions: [
        IconButton(
          onPressed: hasChanges ? saveSettings : null,
          tooltip: l.save,
          icon: const Icon(CupertinoIcons.checkmark),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _tab == 0
                ? ReorderableTopItemsHome(
                    persistHomeTopItems: _draft,
                    setPersistHomeTopItems: (value) =>
                        setState(() => _draft = value),
                  )
                : ShowHideTopItemsList(
                    enabledHomeTopItems: _draft,
                    setEnabledHomeTopItems: (value) =>
                        setState(() => _draft = value),
                  ),
          ),
        ),
      ],
    );
  }
}
