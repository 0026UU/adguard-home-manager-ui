import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/widgets/system_ui_overlay_style.dart';

import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/config/app_screens.dart';
import 'package:adguard_home_manager/config/sizes.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

class Layout extends StatefulWidget {
  const Layout({
    super.key, 
  });

  @override
  State<Layout> createState() => _LayoutState();
}

class _LayoutState extends State<Layout> with WidgetsBindingObserver {
  bool _drawerExpanded = true;

  void _goBranch(int index) {
    Provider.of<AppConfigProvider>(context, listen: false).setSelectedScreen(index);
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final serversProvider = Provider.of<ServersProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final screens = serversProvider.selectedServer != null && serversProvider.apiClient2 != null
      ? screensServerConnected
      : screensSelectServer;

    String translatedName(String key) {
      switch (key) {
        case 'home':
          return AppLocalizations.of(context)!.overview;

        case 'settings':
          return AppLocalizations.of(context)!.settings;

        case 'connect':
          return AppLocalizations.of(context)!.connect;

        case 'clients':
          return AppLocalizations.of(context)!.devices;

        case 'logs':
          return AppLocalizations.of(context)!.logs;

        case 'filters':
          return AppLocalizations.of(context)!.filters;

        default:
          return '';
      }
    }

    final bool updateAvailable = serversProvider.updateAvailable.data != null
      && serversProvider.updateAvailable.data!.canAutoupdate == true;

    if (width > desktopBreakpoint) {
      return OverlayStyle(
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.ease,
              width: _drawerExpanded ? 240 : 84,
              child: AppleSidebar(
                compact: !_drawerExpanded,
                currentIndex: appConfigProvider.selectedScreen < screens.length
                  ? appConfigProvider.selectedScreen
                  : 0,
                onChanged: _goBranch,
                header: _AppleSidebarHeader(
                  expanded: _drawerExpanded,
                  onToggle: () => setState(() => _drawerExpanded = !_drawerExpanded),
                  closeTooltip: AppLocalizations.of(context)!.closeMenu,
                  openTooltip: AppLocalizations.of(context)!.openMenu,
                ),
                items: screens.asMap().entries.map((s) => AppleSidebarItem(
                  icon: s.value.appleIcon ?? s.value.icon,
                  label: translatedName(s.value.name),
                  badge: s.value.name == 'settings' && updateAvailable,
                )).toList(),
              ),
            ),
            Expanded(
              child: PageTransitionSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (
                  (child, primaryAnimation, secondaryAnimation) => FadeThroughTransition(
                    animation: primaryAnimation,
                    secondaryAnimation: secondaryAnimation,
                    child: child,
                  )
                ),
                child: appConfigProvider.selectedScreen < screens.length
                  ? screens[appConfigProvider.selectedScreen].child
                  : screens[0].child,
              ),
            ),
          ],
        ),
      );
    }
    else {
      final currentIndex = (serversProvider.selectedServer == null || serversProvider.apiClient2 == null)
          && appConfigProvider.selectedScreen > 1
        ? 0
        : appConfigProvider.selectedScreen;

      return OverlayStyle(
        child: Scaffold(
          body: PageTransitionSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (
              (child, primaryAnimation, secondaryAnimation) => FadeThroughTransition(
                animation: primaryAnimation,
                secondaryAnimation: secondaryAnimation,
                child: child,
              )
            ),
            child: appConfigProvider.selectedScreen < screens.length
              ? screens[appConfigProvider.selectedScreen].child
              : screens[0].child,
          ),
          bottomNavigationBar: AppleTabBar(
            currentIndex: currentIndex < screens.length ? currentIndex : 0,
            onChanged: _goBranch,
            items: screens.asMap().entries.map((screen) => AppleTabItem(
              icon: screen.value.appleIcon ?? screen.value.icon,
              activeIcon: screen.value.appleSelectedIcon ?? screen.value.appleIcon ?? screen.value.icon,
              label: translatedName(screen.value.name),
              badge: screen.value.name == 'settings' && updateAvailable,
            )).toList(),
          ),
        ),
      );
    }
  }
}

/// Collapse control shown at the top of the desktop Apple sidebar.
class _AppleSidebarHeader extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final String closeTooltip;
  final String openTooltip;

  const _AppleSidebarHeader({
    required this.expanded,
    required this.onToggle,
    required this.closeTooltip,
    required this.openTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: onToggle,
            tooltip: expanded ? closeTooltip : openTooltip,
            icon: Icon(
              expanded
                  ? CupertinoIcons.line_horizontal_3_decrease
                  : CupertinoIcons.line_horizontal_3,
              color: p.label2,
            ),
          ),
          if (expanded)
            Expanded(
              child: Text(
                'AdGuard Home',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: p.label,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
