import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:adguard_home_manager/config/apple_colors.dart';

/// Convenience accessor for the Apple palette.
///
/// Screens should read colours through [ApplePalette.of] instead of touching
/// [Brightness] by hand, which keeps light/dark handling in one place.
class ApplePalette {
  final Brightness brightness;
  const ApplePalette(this.brightness);

  factory ApplePalette.of(BuildContext context) =>
      ApplePalette(ApplePalette.brightnessOf(context));

  static Brightness brightnessOf(BuildContext context) =>
      Theme.of(context).brightness;

  Brightness get b => brightness;

  Color get label => AppleColors.label(brightness);
  Color get label2 => AppleColors.label2(brightness);
  Color get label3 => AppleColors.label3(brightness);
  Color get label4 => AppleColors.label4(brightness);

  Color get window => AppleColors.systemGrouped(brightness);
  Color get card => AppleColors.groupedCard(brightness);
  Color get card2 => AppleColors.groupedCard2(brightness);
  Color get chrome => AppleColors.chrome(brightness);
  Color get chromeSolid => AppleColors.chromeSolid(brightness);
  Color get separator => AppleColors.separator(brightness);
  Color get separatorSoft => AppleColors.separatorSoft(brightness);
  Color get fill2 => AppleColors.fill2(brightness);
  Color get fill3 => AppleColors.fill3(brightness);

  Color get tint => AppleColors.tint(brightness);
  Color get green => AppleColors.green(brightness);
  Color get red => AppleColors.red(brightness);
  Color get orange => AppleColors.orange(brightness);
  Color get yellow => AppleColors.yellow(brightness);
  Color get indigo => AppleColors.indigo(brightness);
  Color get purple => AppleColors.purple(brightness);
  Color get pink => AppleColors.pink(brightness);
  Color get teal => AppleColors.teal(brightness);
  Color get gray => AppleColors.gray(brightness);

  Color pill(Color color) => AppleColors.pillBackground(brightness, color);

  /// Colour of a secondary "cancel / clear" affordance.
  Color get destructive => AppleColors.red(brightness);

  static const List<Color> _seedColors = [
    Color(0xFF0A84FF),
    Color(0xFF5E5CE6),
    Color(0xFFFF2D55),
    Color(0xFFFF9500),
    Color(0xFF30D158),
    Color(0xFF64D2FF),
    Color(0xFFBF5AF2),
    Color(0xFFFFD60A),
  ];

  /// Stable accent for an avatar/initial badge, like iOS contact colours.
  Color seeded(String seed) {
    if (seed.isEmpty) return gray;
    return _seedColors[_seedIndex(seed) % _seedColors.length];
  }

  /// Second accent of the pair, hashed separately so the two stops of the
  /// gradient do not land on the same colour.
  Color seededAlt(String seed) {
    if (seed.isEmpty) return gray;
    final first = _seedIndex(seed) % _seedColors.length;
    var second = _seedIndex(seed, 131) % _seedColors.length;
    if (second == first) second = (second + 3) % _seedColors.length;

    return _seedColors[second];
  }

  static int _seedIndex(String seed, [int multiplier = 31]) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * multiplier + unit) & 0x7fffffff;
    }
    return hash;
  }
}

/// Blurred translucent background used by bars and sheets (UIVisualEffect).
class AppleBlur extends StatelessWidget {
  final Widget? child;
  final Color color;
  final double sigma;

  const AppleBlur({
    super.key,
    this.child,
    required this.color,
    this.sigma = 24,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: ColoredBox(color: color, child: child),
      ),
    );
  }
}

/// Screen shell: collapsing large title + grouped body + pull to refresh.
///
/// Replaces the plain `Scaffold(body: SafeArea(...))` used by the main tabs.
/// [title] is shown large and pinned small, like `UINavigationItem.largeTitle`.
class AppleScreen extends StatelessWidget {
  final String title;
  final List<Widget> slivers;

  /// Trailing actions, shown in the collapsed bar.
  final List<Widget> actions;

  /// Optional widget (usually [AppleSearchField]) pinned under the title.
  final Widget? searchbar;

  /// Called by the iOS pull-to-refresh control.
  final Future<void> Function()? onRefresh;

  final Widget? floatingActionButton;

  /// Extra space kept free at the bottom of the scroll, e.g. when the screen
  /// owns a floating button.
  final double bottomSpacer;

  /// Pinned under the collapsing title, like a segmented control in a
  /// `UINavigationItem`.
  final Widget? header;

  /// Body for screens that bring their own scrolling content (tabbed lists).
  /// When set, the title bar collapses through a [NestedScrollView] and
  /// [slivers] is ignored.
  final Widget? body;

  /// Controller for the [NestedScrollView] used by [body], so screens can keep
  /// scroll-driven behaviour (e.g. hiding a button while scrolling down).
  final ScrollController? scrollController;

  /// Nav-bar leading item, e.g. a back button on a pushed route. Tab
  /// destinations leave this empty.
  final Widget? leading;

  /// Second line under the large title, like the status line the design layer
  /// puts below every page title. It scrolls away with the title.
  final String? subtitle;

  /// Colour of the status dot drawn in front of [subtitle].
  final Color? subtitleDot;

  const AppleScreen({
    super.key,
    required this.title,
    this.slivers = const [],
    this.actions = const [],
    this.searchbar,
    this.onRefresh,
    this.floatingActionButton,
    this.bottomSpacer = 24,
    this.header,
    this.body,
    this.scrollController,
    this.leading,
    this.subtitle,
    this.subtitleDot,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    final appbar = SliverAppBar.large(
      title: Text(title),
      titleSpacing: 20,
      centerTitle: true,
      leading: leading,
      automaticallyImplyLeading: false,
      actions: actions,
      bottom: header == null ? null : AppleHeaderBar(child: header!),
      pinned: true,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      foregroundColor: p.label,
      iconTheme: IconThemeData(color: p.label),
      actionsIconTheme: IconThemeData(color: p.tint),
      flexibleSpace: AppleLargeTitle(
        title: title,
        subtitle: subtitle,
        subtitleDot: subtitleDot,
        bottomHeight: header == null ? 0 : 44,
      ),
    );

    if (body != null) {
      return Scaffold(
        backgroundColor: p.window,
        floatingActionButton: floatingActionButton,
        body: NestedScrollView(
          controller: scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: appbar,
            ),
            if (searchbar != null) SliverToBoxAdapter(child: searchbar!),
          ],
          body: body!,
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.window,
      floatingActionButton: floatingActionButton,
      body: CustomScrollView(
        slivers: [
          appbar,
          if (searchbar != null)
            SliverToBoxAdapter(child: searchbar!),
          if (onRefresh != null)
            const CupertinoSliverRefreshControl(),
          ...slivers,
          SliverToBoxAdapter(child: SizedBox(height: bottomSpacer)),
        ],
      ),
    );
  }
}

/// The 34pt large title of a screen, drawn on the bar's blur.
///
/// `SliverAppBar.large` renders the expanded title *inside* its
/// `flexibleSpace`, so putting the blur there replaces the title. This widget
/// is the blur and the title together, with the metrics of the design layer:
/// the title stays pinned to the bottom of the collapsing area and is clipped
/// away as the bar shrinks to its 17pt inline title.
class AppleLargeTitle extends StatelessWidget {
  final String title;

  /// Height of the row pinned under the title, e.g. an [AppleHeaderBar].
  final double bottomHeight;

  /// Leading inset, 20pt like an iOS large title.
  final double leadingInset;

  /// Status line drawn under the title, 14pt like the design layer.
  final String? subtitle;

  /// Colour of the dot in front of [subtitle].
  final Color? subtitleDot;

  const AppleLargeTitle({
    super.key,
    required this.title,
    this.bottomHeight = 0,
    this.leadingInset = 20,
    this.subtitle,
    this.subtitleDot,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final settings =
        context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final minExtent = settings?.minExtent ?? kToolbarHeight;

    return AppleBlur(
      color: p.chrome,
      child: Column(
        children: [
          // Give the collapsed toolbar its own band, so the large title can
          // only ever be drawn under it.
          Padding(
            padding: EdgeInsets.only(
              top: (minExtent - bottomHeight).clamp(0.0, double.infinity),
            ),
          ),
          Flexible(
            child: ClipRect(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    leadingInset,
                    0,
                    16,
                    bottomHeight > 0 ? 4 : 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 34,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.1,
                          color: p.label,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (subtitleDot != null) ...[
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: subtitleDot,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: subtitleDot!.withValues(
                                          alpha: 0.22,
                                        ),
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 7),
                              ],
                              Flexible(
                                child: Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.25,
                                    color: p.label2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (bottomHeight > 0)
            Padding(padding: EdgeInsets.only(bottom: bottomHeight)),
        ],
      ),
    );
  }
}

/// Fixed height slot rendered under the large title by [AppleScreen].
class AppleHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget child;
  final double height;
  final EdgeInsets padding;

  const AppleHeaderBar({
    super.key,
    required this.child,
    this.height = 44,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 8),
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(padding: padding, child: Center(child: child)),
    );
  }
}

/// A grouped section: rounded card with hairlines inset from the text.
class AppleListSection extends StatelessWidget {
  final String? title;
  final String? footer;
  final List<Widget> children;

  /// Action placed on the section header line (e.g. "Edit").
  final Widget? headerTrailing;

  /// Pass false for full-bleed lists (logs, filter rules).
  final bool insetGrouped;

  /// Background of the card.
  final Color? background;

  final EdgeInsets? margin;

  const AppleListSection({
    super.key,
    this.title,
    this.footer,
    required this.children,
    this.headerTrailing,
    this.insetGrouped = true,
    this.background,
    this.margin,
  });

  static double _indentOf(Widget child) {
    if (child is AppleListTile) return child.separatorIndent;
    if (child is AppleSwitchListTile) return child.separatorIndent;
    return 16;
  }

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(
          AppleSeparator(indent: insetGrouped ? _indentOf(children[i]) : 16),
        );
      }
    }

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(insetGrouped ? 10 : 0),
      child: ColoredBox(
        color: background ?? p.card,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
      ),
    );

    final horizontal = insetGrouped ? 16.0 : 0.0;

    return Padding(
      padding: margin ?? EdgeInsets.only(bottom: 22, left: horizontal, right: horizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || headerTrailing != null)
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: title != null ? 7 : 0,
                top: 0,
              ),
              child: Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.08,
                          color: p.label2,
                          height: 1.25,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (headerTrailing != null) headerTrailing!,
                ],
              ),
            ),
          card,
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
              child: Text(
                footer!,
                style: TextStyle(
                  fontSize: 13,
                  color: p.label2,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The caption line the design layer puts above a group: a 13pt label on the
/// leading edge and, on the trailing edge, whatever the page counts there.
/// Use it when the group itself is a scrolling list, since
/// [AppleListSection] already draws its own header.
class AppleGroupHeader extends StatelessWidget {
  final String title;
  final String? trailing;

  /// Replaces [trailing] when the page needs something other than text.
  final Widget? trailingWidget;

  final EdgeInsets padding;

  const AppleGroupHeader({
    super.key,
    required this.title,
    this.trailing,
    this.trailingWidget,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 7),
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.08,
                color: p.label2,
                height: 1.25,
              ),
            ),
          ),
          if (trailingWidget != null)
            trailingWidget!
          else if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: p.label3,
              ),
            ),
        ],
      ),
    );
  }
}

/// The tappable word at the end of an [AppleGroupHeader] or
/// [AppleListSection] header, the way `UITableView` section indexes offer
/// "Edit" and the design layer offers "Add list" and "Clear all".
class AppleHeaderAction extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  /// Destructive actions read in red, as the design layer tints them.
  final bool destructive;

  const AppleHeaderAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: destructive ? p.red : p.tint,
          ),
        ),
      ),
    );
  }
}

/// A scrolling row list that reads as one inset-grouped card: 16pt side
/// margins, rounded caps at both ends and the card colour behind every row.
///
/// [AppleListSection] groups a fixed number of rows; this is the version for
/// a lazily built list that keeps scrolling inside its card, the way a
/// `UITableView` section does. Returns slivers, so the caller drops them into
/// its own [CustomScrollView].
class AppleListCard {
  const AppleListCard._();

  static List<Widget> slivers(
    BuildContext context, {
    required int itemsCount,
    required Widget? Function(int index) row,
  }) {
    final p = ApplePalette.of(context);

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverMainAxisGroup(
          slivers: [
            const SliverToBoxAdapter(child: AppleCardCap()),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final child = row(index);
                  if (child == null) return const SizedBox.shrink();
                  return ColoredBox(color: p.card, child: child);
                },
                childCount: itemsCount,
              ),
            ),
            const SliverToBoxAdapter(child: AppleCardCap(top: false)),
          ],
        ),
      ),
    ];
  }
}

/// One rounded end of an [AppleListCard].
class AppleCardCap extends StatelessWidget {
  final bool top;
  final double radius;

  const AppleCardCap({super.key, this.top = true, this.radius = 10});

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return Container(
      height: radius,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(top ? radius : 0),
          bottom: Radius.circular(top ? 0 : radius),
        ),
      ),
    );
  }
}

/// 0.5pt hairline, inset from the row text like `UITableView`.
class AppleSeparator extends StatelessWidget {
  final double indent;
  final double endIndent;
  final Color? color;
  final double thickness;

  const AppleSeparator({
    super.key,
    this.indent = 16,
    this.endIndent = 0,
    this.color,
    this.thickness = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    return SizedBox(
      height: thickness,
      child: Divider(
        height: thickness,
        thickness: thickness,
        indent: indent,
        endIndent: endIndent,
        color: color ?? p.separator,
      ),
    );
  }
}

/// iOS style disclosure indicator.
class AppleChevron extends StatelessWidget {
  final Color? color;
  final double size;
  const AppleChevron({super.key, this.color, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    return Icon(
      CupertinoIcons.chevron_right,
      size: size,
      color: color ?? p.label3,
    );
  }
}

/// Rounded tinted square behind a leading icon (Settings app style).
class AppleIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  const AppleIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 29,
    this.iconSize = 19,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(
        child: Icon(icon, size: iconSize, color: color),
      ),
    );
  }
}

/// Standard grouped row.
class AppleListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;

  /// Right aligned value text (e.g. "Enabled", "3.4 ms").
  final String? value;

  /// Colour of [value], for rows whose value carries the state (a paused
  /// protection reads in the accent colour).
  final Color? valueColor;

  final Widget? trailing;
  final Widget? leading;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onHover;

  /// Set false to hide the disclosure indicator on tappable rows.
  final bool showChevron;
  final bool enabled;

  /// Row highlight for master/detail lists on wide layouts.
  final bool selected;
  final int? subtitleMaxLines;
  final double? titleMaxWidth;
  final EdgeInsets padding;

  /// Width of [leading], so the hairline under the row can start at the text.
  final double? leadingWidth;

  /// Set true for rows whose title is code (filter rules, addresses), which
  /// the design layer draws in a monospaced face.
  final bool mono;

  const AppleListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.value,
    this.valueColor,
    this.trailing,
    this.leading,
    this.icon,
    this.iconColor,
    this.onTap,
    this.onLongPress,
    this.onHover,
    this.showChevron = true,
    this.enabled = true,
    this.selected = false,
    this.subtitleMaxLines,
    this.titleMaxWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    this.leadingWidth,
    this.mono = false,
  });

  double get separatorIndent {
    if (leading != null) return padding.left + (leadingWidth ?? 29) + 12;
    if (icon != null) return padding.left + 29 + 12;
    return padding.left;
  }

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final textColor = enabled ? p.label : p.label3;

    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ] else if (icon != null) ...[
            AppleIconBadge(icon: icon!, color: iconColor ?? p.tint),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: titleMaxWidth ?? double.infinity),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: mono ? 13.5 : 17,
                      height: mono ? 1.35 : 1.25,
                      fontFamily: mono ? 'monospace' : null,
                      fontWeight: FontWeight.w400,
                      color: textColor,
                    ),
                  ),
                  if (subtitle != null || subtitleWidget != null) ...[
                    const SizedBox(height: 2),
                    if (subtitleWidget != null)
                      DefaultTextStyle.merge(
                        style: TextStyle(fontSize: 13.5, height: 1.25, color: p.label2),
                        child: subtitleWidget!,
                      )
                    else
                      Text(
                        subtitle!,
                        maxLines: subtitleMaxLines ?? 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.25,
                          color: p.label2,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (value != null)
            Flexible(
              child: Text(
                value!,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.25,
                  color: valueColor ?? p.label2,
                ),
              ),
            ),
          if (trailing != null) trailing!,
          // A row can carry both a value and a disclosure, the way the design
          // layer draws "1.2k ›"; only a trailing control replaces it.
          if (trailing == null && showChevron && onTap != null)
            AppleChevron(color: enabled ? null : p.label4),
        ],
      ),
    );

    return InkWell(
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      onHover: onHover,
      splashColor: Colors.transparent,
      highlightColor: p.fill3,
      child: Container(
        decoration: selected
            ? BoxDecoration(
                color: p.fill2,
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Opacity(opacity: enabled ? 1 : 0.6, child: row),
      ),
    );
  }
}

/// Grouped row with an iOS switch.
class AppleSwitchListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? leading;
  final IconData? icon;
  final Color? iconColor;
  final EdgeInsets padding;

  const AppleSwitchListTile({
    super.key,
    required this.title,
    required this.value,
    this.onChanged,
    this.subtitle,
    this.subtitleWidget,
    this.leading,
    this.icon,
    this.iconColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
  });

  double get separatorIndent {
    if (leading != null || icon != null) return padding.left + 29 + 12;
    return padding.left;
  }

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final enabled = onChanged != null;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ] else if (icon != null) ...[
            AppleIconBadge(icon: icon!, color: iconColor ?? p.tint),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.25,
                    color: enabled ? p.label : p.label3,
                  ),
                ),
                if (subtitleWidget != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(fontSize: 13.5, height: 1.25, color: p.label2),
                      child: subtitleWidget!,
                    ),
                  )
                else if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: TextStyle(fontSize: 13.5, height: 1.25, color: p.label2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppleColors.green(p.b),
          ),
        ],
      ),
    );
  }
}

/// A bare iOS switch, for rows that are tappable as a whole.
class AppleSwitch extends StatelessWidget {
  final bool value;
  final VoidCallback? onChanged;

  const AppleSwitch({
    super.key,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return CupertinoSwitch(
      value: value,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
      activeTrackColor: AppleColors.green(p.b),
    );
  }
}

/// UISegmentedControl with a sliding white capsule.
class AppleSegmented extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double height;
  final bool scrollable;

  const AppleSegmented({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 32,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    final children = <Widget>[];
    for (var i = 0; i < labels.length; i++) {
      final selected = i == selectedIndex;
      final segment = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.symmetric(
            horizontal: selected ? 0 : 2,
            vertical: 2,
          ),
          // A scrollable control shrink-wraps its segments, so each one needs
          // its own breathing room.
          padding: EdgeInsets.symmetric(horizontal: scrollable ? 14 : 0),
          decoration: BoxDecoration(
            color: selected ? p.card : Colors.transparent,
            borderRadius: BorderRadius.circular(height / 2 - 2),
            boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0x0F000000).withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
          ),
          alignment: Alignment.center,
          child: Text(
            labels[i],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? p.label : p.label2,
            ),
          ),
        ),
      );

      // Expanded is illegal inside an unbounded horizontal viewport.
      children.add(scrollable ? segment : Expanded(child: segment));
    }

    final control = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: height,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: p.fill2,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Row(children: children),
    );

    if (!scrollable) return control;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 32),
        child: control,
      ),
    );
  }
}

/// Small status capsule (blocked / allowed / enabled ...).
class ApplePill extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final double fontSize;

  const ApplePill({
    super.key,
    required this.label,
    required this.color,
    this.filled = true,
    this.fontSize = 11.5,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? p.pill(color) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: filled ? null : Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          height: 1.2,
          color: color,
        ),
      ),
    );
  }
}

/// A query log entry: the status pill, the domain and the time on the first
/// line, the details as dot separated runs underneath.
class AppleLogRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? time;
  final List<String> details;
  final bool selected;
  final VoidCallback? onTap;

  /// Hairlines between entries stop short of the card edge, unlike list rows.
  static const double separatorInset = 14;

  const AppleLogRow({
    super.key,
    required this.leading,
    required this.title,
    this.time,
    this.details = const [],
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: p.fill3,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        color: selected ? p.fill2 : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                leading,
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: p.label,
                    ),
                  ),
                ),
                if (time != null) ...[
                  const SizedBox(width: 9),
                  SizedBox(
                    width: 52,
                    child: Text(
                      time!,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: 12,
                        color: p.label3,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  for (var i = 0; i < details.length; i++) ...[
                    if (i > 0) ...[
                      const SizedBox(width: 7),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: p.label3,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                    ],
                    Flexible(
                      child: Text(
                        details[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: p.label2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rounded text field used for search and inline filters.
class AppleSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmit;
  final VoidCallback? onTap;
  final Widget? suffix;

  /// For the floating search field, which appears on its own and must be ready
  /// to type in.
  final bool autofocus;

  const AppleSearchField({
    super.key,
    this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmit,
    this.onTap,
    this.suffix,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: p.fill2,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Icon(CupertinoIcons.search, size: 16, color: p.label3),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
                onTap: onTap,
                autofocus: autofocus,
                textAlignVertical: TextAlignVertical.center,
                cursorRadius: const Radius.circular(2),
                style: TextStyle(fontSize: 16, color: p.label),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintMaxLines: 1,
                  hintText: hint,
                  hintStyle: TextStyle(fontSize: 16, color: p.label3),
                ),
              ),
            ),
            if (controller != null)
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller!,
                builder: (context, value, _) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        controller!.clear();
                        onChanged?.call('');
                      },
                      child: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        size: 18,
                        color: p.label3,
                      ),
                    ),
                  );
                },
              ),
            if (suffix != null) suffix!,
          ],
        ),
      ),
    );
  }
}

/// Large stat used on the overview hero card.
class AppleStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final Color? valueColor;
  final Widget? trailing;

  const AppleStatCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: p.label2, height: 1.2),
        ),
        const SizedBox(height: 3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  height: 1.1,
                  color: valueColor ?? p.label,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        if (caption != null)
          Text(
            caption!,
            style: TextStyle(fontSize: 11.5, color: p.label3, height: 1.3),
          ),
      ],
    );
  }
}

/// Card container with the grouped radius.
class AppleCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BorderRadius? radius;

  const AppleCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.card,
        borderRadius: radius ?? BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

/// Status card at the top of the overview: a tinted wash, a soft glow in the
/// corner, a round action on the leading edge, the state and the actions
/// underneath. The wash and the glow follow [active], green when the server is
/// protecting and red when it is not.
class AppleHero extends StatelessWidget {
  final bool active;
  final IconData icon;

  /// Title of the card, e.g. the protection state.
  final String title;

  /// Second line under the title.
  final String? description;

  /// Round button on the leading edge.
  final VoidCallback? onTapIcon;

  /// Ring progress at the trailing edge.
  final Widget? trailing;

  /// Buttons along the bottom edge, laid out side by side.
  final List<Widget> actions;

  const AppleHero({
    super.key,
    required this.active,
    required this.icon,
    required this.title,
    this.description,
    this.onTapIcon,
    this.trailing,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final Color accent = active ? p.green : p.red;

    return Container(
      padding: const EdgeInsets.all(18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(accent.withValues(alpha: 0.16), p.card),
            p.card,
          ],
          stops: const [0.0, 0.62],
        ),
      ),
      child: Stack(
        children: [
          // The glow sits outside the card and is cut by its corner radius.
          Positioned(
            right: -70,
            top: -90,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.34),
                    accent.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: onTapIcon,
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(icon, size: 30, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: p.label,
                          ),
                        ),
                        if (description != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              description!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: p.label2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: actions[i]),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The oversized card that heads the settings page: a gradient icon tile, the
/// server name, one line of detail, a status pill, and underneath the card the
/// action that opens what it describes.
class AppleBigRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? colorTo;
  final String title;
  final String? details;
  final String? status;
  final Color? statusColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppleBigRow({
    super.key,
    required this.icon,
    required this.color,
    this.colorTo,
    required this.title,
    this.details,
    this.status,
    this.statusColor,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppleCard(
          padding: const EdgeInsets.all(14),
          radius: BorderRadius.circular(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment(-0.7, -0.7),
                    end: Alignment(0.7, 0.7),
                    colors: [color, colorTo ?? color],
                  ),
                ),
                child: Icon(icon, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: p.label,
                      ),
                    ),
                    if (details != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        details!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, height: 1.25, color: p.label2),
                      ),
                    ],
                  ],
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: 8),
                ApplePill(
                  label: status!,
                  color: statusColor ?? p.green,
                  fontSize: 12,
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: AppleButton.secondary(
              label: actionLabel!,
              onPressed: onAction,
            ),
          ),
        ],
      ],
    );
  }
}

/// One tile of the statistics grid: caption, big number, optional note and an
/// optional sparkline pinned to the top right corner of the tile.
class AppleStatTile extends StatelessWidget {
  final String label;
  final String value;

  /// Unit shown after the number, smaller and grey.
  final String? unit;

  /// Note under the number, e.g. a percentage.
  final String? caption;
  final Color? captionColor;

  /// Series drawn behind the number, e.g. an `AppleSparkline`.
  final Widget? sparkline;

  final VoidCallback? onTap;

  const AppleStatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.caption,
    this.captionColor,
    this.sparkline,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: p.label2,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                          height: 1.05,
                          color: p.label,
                        ),
                      ),
                    ),
                    if (unit != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          unit!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: p.label2,
                          ),
                        ),
                      ),
                  ],
                ),
                if (caption != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: captionColor ?? p.label3,
                        height: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
            if (sparkline != null)
              Positioned(
                right: 8,
                top: 10,
                child: Opacity(opacity: 0.42, child: sparkline!),
              ),
          ],
        ),
      ),
    );
  }
}

/// Statistics laid out as the design layer does: two columns of tiles.
class AppleStatGrid extends StatelessWidget {
  final List<Widget> tiles;
  final EdgeInsetsGeometry padding;

  const AppleStatGrid({
    super.key,
    required this.tiles,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      // IntrinsicHeight keeps the two tiles of a row the same height, which is
      // what the grid does in the design layer.
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[i]),
              if (i + 1 < tiles.length) ...[
                const SizedBox(width: 10),
                Expanded(child: tiles[i + 1]),
              ] else
                const SizedBox(width: 10),
            ],
          ),
        ),
      );
      if (i + 2 < tiles.length) {
        rows.add(const SizedBox(height: 10));
      }
    }

    return Padding(
      padding: padding,
      child: Column(children: rows),
    );
  }
}

/// Leading circle with the initial of a client / domain.
class AppleAvatar extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  final IconData? icon;

  /// When set, the badge is filled with a 140° gradient to this colour and the
  /// initial turns white, the way the design layer paints device avatars.
  final Color? gradientTo;

  const AppleAvatar({
    super.key,
    required this.text,
    required this.color,
    this.size = 34,
    this.icon,
    this.gradientTo,
  });

  @override
  Widget build(BuildContext context) {
    final bool gradient = gradientTo != null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient
          ? LinearGradient(
              begin: Alignment(-0.76, -0.64),
              end: Alignment(0.76, 0.64),
              colors: [color, gradientTo!],
            )
          : null,
        color: gradient ? null : color.withValues(alpha: 0.16),
      ),
      alignment: Alignment.center,
      child: icon != null
        ? Icon(icon, size: size * 0.5, color: color)
        : Text(
            text.isEmpty ? '?' : text.characters.first.toUpperCase(),
            style: TextStyle(
              fontSize: gradient ? size * 0.375 : size * 0.42,
              fontWeight: gradient ? FontWeight.w700 : FontWeight.w600,
              color: gradient ? Colors.white : color,
            ),
          ),
    );
  }
}

/// Full width blue capsule button.
class AppleButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool filled;
  final IconData? icon;
  final bool busy;

  const AppleButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
    this.filled = true,
    this.icon,
    this.busy = false,
  });

  const AppleButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
    this.icon,
    this.busy = false,
  }) : filled = false;

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final base = color ?? p.tint;
    final enabled = onPressed != null && !busy;

    // The design layer fills a secondary button with the light grey and keeps
    // the label in the text colour; only the primary one takes the accent.
    final background = filled ? base : p.fill2;
    final foreground = filled ? Colors.white : p.label;

    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.transparent,
          highlightColor: base.withValues(alpha: 0.12),
          onTap: enabled ? onPressed : null,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            child: busy
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: foreground,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 19, color: foreground),
                      const SizedBox(width: 7),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

/// Empty / error placeholder shown where a list would be.
class AppleEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color? color;

  const AppleEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final tint = color ?? p.label3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 44),
      child: Column(
        children: [
          Icon(icon, size: 42, color: tint),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: p.label,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.35, color: p.label2),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Centered spinner, used while a screen or a tab body is loading.
class AppleLoading extends StatelessWidget {
  final String? label;

  const AppleLoading({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(radius: 14),
          if (label != null) ...[
            const SizedBox(height: 18),
            Text(
              label!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.3, color: p.label2),
            ),
          ],
        ],
      ),
    );
  }
}

/// Grey caption line used between sections.
class AppleCaption extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  const AppleCaption(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 8)});

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: p.label2, height: 1.3),
      ),
    );
  }
}
