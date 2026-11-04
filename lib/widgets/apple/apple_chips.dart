import 'package:flutter/cupertino.dart';

import 'package:adguard_home_manager/widgets/apple/apple_widgets.dart';

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

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        decoration: BoxDecoration(
          color: p.pill(tint),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: tint),
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
                  fontWeight: FontWeight.w500,
                  color: tint,
                ),
              ),
            ),
            if (onDeleted != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDeleted,
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 16,
                  color: p.label3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
