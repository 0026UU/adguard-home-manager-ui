import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:adguard_home_manager/widgets/apple/apple_widgets.dart';

/// One destination of the iOS tab bar.
class AppleTabItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  /// Draws the small red dot in the top-right of the icon.
  final bool badge;

  const AppleTabItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.badge = false,
  });
}

/// Translucent blurred tab bar (`UITabBar`).
///
/// Pass it as `bottomNavigationBar` together with `Scaffold.extendBody = true`
/// so the lists scroll behind the blur.
class AppleTabBar extends StatelessWidget {
  final List<AppleTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final double height;

  const AppleTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    this.height = 49,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: ColoredBox(
          color: p.chrome,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 0.5, child: ColoredBox(color: p.separator)),
              SizedBox(
                height: height,
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: _AppleTabButton(
                          item: items[i],
                          selected: i == currentIndex,
                          onTap: () => onChanged(i),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: bottomInset),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppleTabButton extends StatelessWidget {
  final AppleTabItem item;
  final bool selected;
  final VoidCallback onTap;

  const _AppleTabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final color = selected ? p.tint : p.label2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                selected ? (item.activeIcon ?? item.icon) : item.icon,
                size: 24,
                color: color,
              ),
              if (item.badge)
                Positioned(
                  top: 0,
                  right: -5,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: p.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.chromeSolid, width: 1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              height: 1.1,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sidebar destination used on desktop / tablet widths.
class AppleSidebarItem {
  final IconData icon;
  final String label;
  final bool badge;

  const AppleSidebarItem({required this.icon, required this.label, this.badge = false});
}

/// macOS / iPadOS style sidebar: tinted capsules on the selected row.
class AppleSidebar extends StatelessWidget {
  final List<AppleSidebarItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final Widget? header;
  final Widget? footer;

  /// Icon-only rail, used when the desktop sidebar is collapsed.
  final bool compact;

  /// Sidebar width. Leave null to fill the parent, which lets the shell
  /// animate the width itself.
  final double? width;

  const AppleSidebar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    this.header,
    this.footer,
    this.compact = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    final Widget content = ColoredBox(
      color: p.window,
      child: SafeArea(
        right: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) header!,
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _AppleSidebarRow(
                        item: items[i],
                        selected: i == currentIndex,
                        compact: compact,
                        onTap: () => onChanged(i),
                      ),
                    ),
                ],
              ),
            ),
            if (footer != null) footer!,
          ],
        ),
      ),
    );

    return width == null ? content : SizedBox(width: width, child: content);
  }
}

class _AppleSidebarRow extends StatelessWidget {
  final AppleSidebarItem item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _AppleSidebarRow({
    required this.item,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return Material(
      color: selected ? p.tint.withValues(alpha: 0.16) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        splashColor: Colors.transparent,
        highlightColor: p.fill3,
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: compact
            ? Tooltip(
                message: item.label,
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(item.icon, size: 21, color: selected ? p.tint : p.label2),
                      if (item.badge)
                        Positioned(
                          top: -1,
                          right: -6,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: p.red, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            : Row(
                children: [
                  Icon(item.icon, size: 19, color: selected ? p.tint : p.label2),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: p.label,
                      ),
                    ),
                  ),
                  if (item.badge)
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: p.red, shape: BoxShape.circle),
                    ),
                ],
              ),
        ),
      ),
    );
  }
}

/// Inline (non-collapsing) top bar with blur, for screens that already own
/// their `Scaffold` and only need the iOS chrome.
class AppleTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;
  final Widget? leading;

  const AppleTopBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: ColoredBox(
          color: p.chrome,
          child: Container(
            height: 44 + topInset,
            padding: EdgeInsets.only(top: topInset),
            child: Row(
              children: [
                if (leading != null) leading!,
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: p.label,
                    ),
                  ),
                ),
                ...actions,
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
