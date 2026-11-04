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
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _seedColors[hash % _seedColors.length];
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
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    final appbar = SliverAppBar.large(
      title: Text(title),
      titleSpacing: 20,
      leading: null,
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
      flexibleSpace: AppleBlur(color: p.chrome),
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

  const AppleListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.value,
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
  });

  double get separatorIndent {
    if (leading != null) return padding.left + 29 + 12;
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
                      fontSize: 17,
                      height: 1.25,
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
                style: TextStyle(fontSize: 17, height: 1.25, color: p.label3),
              ),
            ),
          if (trailing != null) trailing!,
          if (trailing == null && value == null && showChevron && onTap != null)
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
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: color,
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
        height: 36,
        decoration: BoxDecoration(
          color: p.fill2,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
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

/// Leading circle with the initial of a client / domain.
class AppleAvatar extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  final IconData? icon;

  const AppleAvatar({
    super.key,
    required this.text,
    required this.color,
    this.size = 34,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: icon != null
        ? Icon(icon, size: size * 0.5, color: color)
        : Text(
            text.isEmpty ? '?' : text.characters.first.toUpperCase(),
            style: TextStyle(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w600,
              color: color,
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

    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: filled ? base : p.card,
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
                    color: filled ? Colors.white : base,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 19, color: filled ? Colors.white : base),
                      const SizedBox(width: 7),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: filled ? Colors.white : base,
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
