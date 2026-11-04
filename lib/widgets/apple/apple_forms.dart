import 'package:flutter/material.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/widgets/apple/apple_widgets.dart';

/// Shell for the add/edit forms: a centred 14pt card on wide layouts, an
/// iOS sheet with a grabber on phones. Both keep the same title row, so the
/// form body only has to be written once.
class AppleFormModal extends StatelessWidget {
  final String title;

  /// Chosen by the caller, which already knows the available width and the
  /// platform: true shows the dialog, false the sheet.
  final bool dialog;
  final Widget body;
  final IconData? icon;
  final Color? iconColor;
  final double maxWidth;

  /// Trailing affordance in the title row (e.g. a help or delete action).
  final Widget? trailing;

  const AppleFormModal({
    super.key,
    required this.title,
    required this.dialog,
    required this.body,
    this.icon,
    this.iconColor,
    this.maxWidth = 400,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final size = MediaQuery.sizeOf(context);

    final leading =
        icon == null ? null : Icon(icon, size: 20, color: iconColor ?? p.tint);

    final header = Padding(
      padding: EdgeInsets.fromLTRB(20, dialog ? 20 : 6, 20, 10),
      child: Row(
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 10)],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: p.label,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );

    // One column for both shapes: the body is the flexible child, so a form
    // taller than the screen scrolls instead of overflowing.
    final form = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!dialog)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: p.fill2,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        header,
        Flexible(child: body),
      ],
    );

    if (dialog) {
      return Dialog(
        backgroundColor: p.chromeSolid,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: size.height * 0.85,
          ),
          child: form,
        ),
      );
    }

    return Padding(
      padding: MediaQuery.viewInsetsOf(context),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.9),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          child: ColoredBox(
            color: p.chromeSolid,
            child: SafeArea(top: false, child: form),
          ),
        ),
      ),
    );
  }
}

/// Action row at the bottom of an [AppleFormModal]: a right-aligned cancel
/// and confirm pair, the confirm disabled while the form is incomplete.
class AppleFormFooter extends StatelessWidget {
  final String confirmLabel;
  final VoidCallback? onConfirm;
  final bool confirmEnabled;
  final VoidCallback? onCancel;
  final String? cancelLabel;

  /// Rendered on the leading edge, e.g. a delete action.
  final Widget? leading;

  /// Colours the confirm button red, for actions that cannot be undone.
  final bool destructive;

  const AppleFormFooter({
    super.key,
    required this.confirmLabel,
    required this.onConfirm,
    this.confirmEnabled = true,
    this.cancelLabel,
    this.onCancel,
    this.leading,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    final cancel = onCancel ?? () => Navigator.pop(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const Spacer()],
          AppleFormButton(
            label: cancelLabel ?? l.cancel,
            background: p.fill2,
            foreground: p.label,
            onPressed: cancel,
          ),
          const SizedBox(width: 10),
          AppleFormButton(
            label: confirmLabel,
            background: destructive ? p.red : p.tint,
            foreground: Colors.white,
            onPressed: confirmEnabled ? onConfirm : null,
          ),
        ],
      ),
    );
  }
}

class AppleFormButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  final double? width;

  const AppleFormButton({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filled, rounded field chrome so the forms match the rest of the Apple
/// layer instead of the Material outline boxes.
class AppleInput {
  const AppleInput._();

  static InputDecoration decoration(
    BuildContext context, {
    String? label,
    String? hint,
    String? helper,
    int? helperMaxLines,
    String? error,
    IconData? icon,
  }) {
    final p = ApplePalette.of(context);

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: p.fill2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      prefixIcon: icon == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: Icon(icon, size: 18, color: p.label3),
            ),
      labelText: label,
      labelStyle: TextStyle(color: p.label2),
      floatingLabelStyle: TextStyle(color: p.tint, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: p.label3),
      hintText: hint,
      helperStyle: TextStyle(color: p.label3, fontSize: 12),
      helperText: helper,
      helperMaxLines: helperMaxLines,
      errorText: error,
      errorStyle: TextStyle(color: p.red, fontSize: 12),
      errorBorder: border(p.red, 1.5),
      focusedErrorBorder: border(p.red, 1.5),
      enabledBorder: border(p.separatorSoft, 1),
      focusedBorder: border(p.tint, 1.5),
      border: border(p.separatorSoft, 1),
    );
  }

  /// Text style for the fields, kept in one place for light and dark.
  static TextStyle style(BuildContext context) => TextStyle(
        fontSize: 15,
        color: ApplePalette.of(context).label,
      );
}

/// Caption above a block of fields, using the same metrics as the
/// [AppleListSection] title so both read as one inset-grouped form.
class AppleFormGroupLabel extends StatelessWidget {
  final String label;
  final EdgeInsetsGeometry padding;

  const AppleFormGroupLabel(
    this.label, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 7),
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return Padding(
      padding: padding,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.08,
          color: p.label2,
          height: 1.25,
        ),
      ),
    );
  }
}

/// One labelled field of an Apple form: the [AppleInput] chrome plus the
/// spacing the forms share, so a form is a list of these and nothing else.
class AppleTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final ValueChanged<String>? onChanged;
  final String? error;
  final String? hint;
  final String? helper;
  final int? helperMaxLines;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool enabled;
  final EdgeInsetsGeometry padding;

  const AppleTextField({
    super.key,
    required this.label,
    required this.controller,
    this.icon,
    this.onChanged,
    this.error,
    this.hint,
    this.helper,
    this.helperMaxLines,
    this.keyboardType,
    this.obscure = false,
    this.enabled = true,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: TextFormField(
        controller: controller,
        style: AppleInput.style(context),
        enabled: enabled,
        obscureText: obscure,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: AppleInput.decoration(
          context,
          label: label,
          icon: icon,
          error: error,
          hint: hint,
          helper: helper,
          helperMaxLines: helperMaxLines,
        ),
      ),
    );
  }
}
