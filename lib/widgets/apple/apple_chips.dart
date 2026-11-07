import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:adguard_home_manager/widgets/apple/apple_widgets.dart';

/// Text and glyphs sitting on a solid [tint].  White only survives on the dark
/// half of the ramp, so the foreground follows the hue: the dark-mode greens
/// and yellows are bright enough to swallow white text at about 2:1.
Color onTint(Color tint) =>
    tint.computeLuminance() > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

/// Removable capsule used for active filters under a title bar.
class AppleFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onDeleted;

  const AppleFilterChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final tint = color ?? p.label;
    final Color on = onTint(tint);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: on),
              const SizedBox(width: 5),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: on,
                ),
              ),
            ),
            if (onDeleted != null) ...[
              // The gap and the glyph together used to be the whole target.
              // The box now covers them both and a little more, with the glyph
              // still painted exactly where it was.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDeleted,
                child: SizedBox(
                  width: 26,
                  height: 20,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      size: 16,
                      color: on.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Selectable capsule of the log filter sheet: outlined while off, solid tint
/// while on, the way the prototype's `.chip` and `.chip.on` read.
class AppleToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? activeColor;

  const AppleToggleChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final active = activeColor ?? p.tint;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // The capsule is drawn about 31pt tall, which is what it has always
        // measured; the box that takes the tap is now the 44pt the rest of the
        // layer holds itself to, so the chip reads the same and answers to a
        // thumb.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          // The factor keeps the box as wide as the capsule: without it the
          // chip fills the row, and a wrap of chips becomes a stack of bars.
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? active : p.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  width: 0.5,
                  color: selected ? Colors.transparent : p.separator,
                ),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: selected ? onTint(active) : p.label2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
