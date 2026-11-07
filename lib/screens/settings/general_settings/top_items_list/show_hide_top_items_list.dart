import 'package:flutter/cupertino.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/constants/enums.dart';

/// The name the dashboard gives one of the rankings its card can show.
String topItemTitle(AppLocalizations l, HomeTopItems item) {
  switch (item) {
    case HomeTopItems.queriedDomains:
      return l.topQueriedDomains;
    case HomeTopItems.blockedDomains:
      return l.topBlockedDomains;
    case HomeTopItems.recurrentClients:
      return l.topClients;
  }
}

/// The badge the design layer puts in front of one of those rankings.
IconData topItemIcon(HomeTopItems item) {
  switch (item) {
    case HomeTopItems.queriedDomains:
      return CupertinoIcons.square_split_2x1_fill;
    case HomeTopItems.blockedDomains:
      return CupertinoIcons.slash_circle_fill;
    case HomeTopItems.recurrentClients:
      return CupertinoIcons.person_2_fill;
  }
}

/// Which of the dashboard's top lists the user wants to see.
///
/// Turning one off takes it out of the order rather than leaving a hole in it,
/// which is what the server's own setting is: one list of the items to show,
/// in the sequence to show them in.
class ShowHideTopItemsList extends StatelessWidget {
  final List<HomeTopItems> enabledHomeTopItems;
  final void Function(List<HomeTopItems>) setEnabledHomeTopItems;

  const ShowHideTopItemsList({
    super.key,
    required this.enabledHomeTopItems,
    required this.setEnabledHomeTopItems,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    void updateValue(HomeTopItems value, bool newStatus) {
      if (newStatus) {
        setEnabledHomeTopItems([...enabledHomeTopItems, value]);
      } else {
        setEnabledHomeTopItems(
          enabledHomeTopItems.where((e) => e != value).toList(),
        );
      }
    }

    return AppleListSection(
      title: l.showHide,
      children: [
        for (final item in HomeTopItems.values)
          AppleSwitchListTile(
            icon: topItemIcon(item),
            iconColor: enabledHomeTopItems.contains(item) ? p.tint : p.gray,
            title: topItemTitle(l, item),
            value: enabledHomeTopItems.contains(item),
            onChanged: (value) => updateValue(item, value),
          ),
      ],
    );
  }
}
