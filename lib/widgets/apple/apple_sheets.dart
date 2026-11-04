import 'package:flutter/material.dart';

import 'package:adguard_home_manager/widgets/apple/apple_widgets.dart';

/// Action line inside [AppleSheet] / [showAppleActionSheet].
class AppleSheetAction {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;

  /// Destructive rows are tinted red and pushed to the bottom of a cancel
  /// separated group by [showAppleActionSheet].
  final bool destructive;

  /// Rendered as a strikethrough / grey "disabled" row.
  final bool disabled;

  const AppleSheetAction({
    required this.label,
    this.onTap,
    this.icon,
    this.color,
    this.destructive = false,
    this.disabled = false,
  });
}

/// Content of an iOS modal sheet: grabber, title row, scrollable body, footer.
class AppleSheet extends StatelessWidget {
  final String? title;
  final Widget? body;
  final List<Widget> actions;
  final Widget? trailing;

  /// Buttons rendered in the head row (e.g. a segmented control).
  final Widget? headTrailingWidget;

  final double initialFraction;
  final double maxFraction;

  const AppleSheet({
    super.key,
    this.title,
    this.body,
    this.actions = const [],
    this.trailing,
    this.headTrailingWidget,
    this.initialFraction = 0.6,
    this.maxFraction = 0.95,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return DraggableScrollableSheet(
      initialChildSize: initialFraction,
      minChildSize: 0.4,
      maxChildSize: maxFraction,
      expand: false,
      snap: true,
      builder: (context, controller) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          child: ColoredBox(
            color: p.window,
            child: Column(
              children: [
                // Grabber + title
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: p.fill2,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (title != null || trailing != null || headTrailingWidget != null)
                        Row(
                          children: [
                            if (title != null)
                              Expanded(
                                child: Text(
                                  title!,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: p.label,
                                  ),
                                ),
                              )
                            else
                              const Spacer(),
                            if (headTrailingWidget != null) headTrailingWidget!,
                            if (trailing != null) ...[
                              const SizedBox(width: 8),
                              trailing!,
                            ],
                          ],
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                // Actions (fixed, above the scrollable list)
                if (actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: AppleListSection(
                      margin: EdgeInsets.zero,
                      children: actions,
                    ),
                  ),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.only(bottom: 30),
                    children: [
                      if (body != null) body!,
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Show a grouped iOS sheet.
Future<T?> showAppleSheet<T>(
  BuildContext context, {
  String? title,
  Widget? body,
  List<Widget> actions = const [],
  Widget? trailing,
  Widget? headTrailingWidget,
  double initialFraction = 0.6,
  double maxFraction = 0.95,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    barrierColor: const Color(0x66000000),
    backgroundColor: Colors.transparent,
    builder: (context) => AppleSheet(
      title: title,
      body: body,
      actions: actions,
      trailing: trailing,
      headTrailingWidget: headTrailingWidget,
      initialFraction: initialFraction,
      maxFraction: maxFraction,
    ),
  );
}

/// A single button inside an action sheet, matching `UIAlertController`.
class _AppleActionTile extends StatelessWidget {
  final AppleSheetAction action;
  final bool last;

  const _AppleActionTile({required this.action, required this.last});

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final color = action.disabled
      ? p.label3
      : (action.color ?? (action.destructive ? p.red : p.tint));

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: action.disabled ? null : action.onTap,
            child: SizedBox(
              width: double.infinity,
              height: 57,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (action.icon != null) ...[
                    Icon(action.icon, size: 20, color: color),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      action.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.2,
                        fontWeight: FontWeight.w400,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!last)
          SizedBox(
            height: 0.5,
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              indent: 16,
              color: p.separator,
            ),
          ),
      ],
    );
  }
}

/// `UIAlertController` with `.actionSheet` style.
Future<void> showAppleActionSheet(
  BuildContext context, {
  String? title,
  String? message,
  required List<AppleSheetAction> actions,
  String? cancelLabel,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final p = ApplePalette.of(sheetContext);
      final cancel = cancelLabel ?? MaterialLocalizations.of(sheetContext).cancelButtonLabel;
      final grouped = actions
          .where((a) => !a.destructive)
          .toList(growable: false);
      final destructive = actions
          .where((a) => a.destructive)
          .toList(growable: false);

      Widget card(List<AppleSheetAction> items) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: p.chromeSolid,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++)
                _AppleActionTile(action: items[i], last: i == items.length - 1),
            ],
          ),
        ),
      );

      final hasHeader = title != null || message != null;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasHeader)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ColoredBox(
                      color: p.chromeSolid,
                      child: Column(
                        children: [
                          if (title != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: p.label2,
                                ),
                              ),
                            ),
                          if (message != null)
                            Padding(
                              padding: EdgeInsets.fromLTRB(16, hasHeader && title == null ? 16 : 0, 16, 14),
                              child: Text(
                                message,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, height: 1.3, color: p.label2),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (grouped.isNotEmpty) card(grouped),
              if (grouped.isNotEmpty && destructive.isNotEmpty)
                const SizedBox(height: 8),
              if (destructive.isNotEmpty) card(destructive),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ColoredBox(
                  color: p.chromeSolid,
                  child: SizedBox(
                    width: double.infinity,
                    height: 57,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(sheetContext).pop(),
                        child: Center(
                          child: Text(
                            cancel,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: p.tint,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
