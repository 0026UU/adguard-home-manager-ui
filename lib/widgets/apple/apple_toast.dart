import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/widgets/apple/apple_widgets.dart';

/// A transient status pill floating above the tab bar, the Apple counterpart of
/// a Material [SnackBar].
///
/// Only one toast lives at a time: showing a new one replaces the visible toast
/// instead of stacking it, which is how the iOS standard UI behaves.
class AppleToast {
  const AppleToast._();

  static OverlayEntry? _entry;

  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Color? accent,
    Duration duration = const Duration(milliseconds: 1600),
  }) {
    hide();

    // Callers high in the tree — the app's global snack-bar helper, for
    // instance — have no overlay among their ancestors, so the root
    // navigator's overlay is used as the fallback. Either way the pill lands
    // in the root overlay and floats above pushed pages and sheets, like the
    // prototype's single top-level toast node.
    final OverlayState? overlay =
        Overlay.maybeOf(context, rootOverlay: true) ??
        globalNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (BuildContext context) => _AppleToastView(
        message: message,
        icon: icon,
        accent: accent,
        duration: duration,
        onDismissed: hide,
      ),
    );

    _entry = entry;
    overlay.insert(entry);
  }

  static void hide() {
    final OverlayEntry? entry = _entry;
    _entry = null;

    // Removing an entry twice, or one left over from a disposed overlay trips
    // an assertion inside OverlayEntry, so only a live entry is removed.
    if (entry == null || !entry.mounted) return;
    entry.remove();
  }
}

class _AppleToastView extends StatefulWidget {
  final String message;
  final IconData? icon;
  final Color? accent;
  final Duration duration;
  final VoidCallback onDismissed;

  const _AppleToastView({
    required this.message,
    required this.duration,
    required this.onDismissed,
    this.icon,
    this.accent,
  });

  @override
  State<_AppleToastView> createState() => _AppleToastViewState();
}

class _AppleToastViewState extends State<_AppleToastView>
    with SingleTickerProviderStateMixin {
  static const Curve _ease = Cubic(0.2, 0.9, 0.2, 1.0);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final CurvedAnimation _motion = CurvedAnimation(
    parent: _controller,
    curve: _ease,
  );
  Timer? _timer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;

    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _motion.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ApplePalette p = ApplePalette.of(context);
    final IconData icon = widget.icon ?? _iconFor(widget.accent);
    final Color accent = widget.accent ?? p.label;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 120),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              final double t = _motion.value.clamp(0.0, 1.0);

              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - t)),
                  child: child,
                ),
              );
            },
            child: Semantics(
              liveRegion: true,
              label: widget.message,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.88,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.label.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(icon, size: 16, color: accent),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: p.card,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Callers describe a result with a colour rather than an icon, so the glyph
  /// follows the hue: green confirms, red and amber warn, anything else informs.
  static IconData _iconFor(Color? color) {
    if (color == null) return CupertinoIcons.checkmark_circle;

    final HSVColor hsv = HSVColor.fromColor(color);
    final double hue = hsv.hue;
    final bool vivid = hsv.saturation > 0.4 && hsv.value > 0.4;

    if (!vivid) return CupertinoIcons.info_circle;
    if (hue >= 340 || hue < 70) {
      return hue < 45
          ? CupertinoIcons.xmark_circle
          : CupertinoIcons.exclamationmark_triangle;
    }
    if (hue < 200) return CupertinoIcons.checkmark_circle;

    return CupertinoIcons.info_circle;
  }
}
