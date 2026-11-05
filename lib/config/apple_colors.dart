import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Apple HIG system palette.
///
/// Values follow the published iOS system colour list (light / dark pairs) so
/// that the UI reads as native rather than as a Material re-skin.
class AppleColors {
  const AppleColors._();

  // ---------------------------------------------------------------- labels
  static Color label(Brightness b) =>
      b == Brightness.light ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

  static Color label2(Brightness b) => b == Brightness.light
      ? const Color(0x9E3C3C43) // rgba(60,60,67,.62)
      : const Color(0xE598989D);

  static Color label3(Brightness b) => b == Brightness.light
      ? const Color(0x5C3C3C43) // rgba(60,60,67,.36)
      : const Color(0x8098989D);

  static Color label4(Brightness b) => b == Brightness.light
      ? const Color(0x393C3C43)
      : const Color(0x5198989D);

  // ---------------------------------------------------------- backgrounds
  /// Window background of a grouped screen.
  static Color systemGrouped(Brightness b) => b == Brightness.light
      ? const Color(0xFFF2F2F7)
      : const Color(0xFF000000);

  /// Background of the first-level grouped card.
  static Color groupedCard(Brightness b) =>
      b == Brightness.light ? const Color(0xFFFFFFFF) : const Color(0xFF1C1C1E);

  /// Background of nested / elevated content.
  static Color groupedCard2(Brightness b) =>
      b == Brightness.light ? const Color(0xFFFFFFFF) : const Color(0xFF2C2C2E);

  /// Plain window background (lists without grouping).
  static Color system(Brightness b) =>
      b == Brightness.light ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

  /// Bar (nav / tab / toolbar) background, meant to sit over a blur.
  static Color chrome(Brightness b) => b == Brightness.light
      ? const Color(0xB8F9F9F9) // rgba(249,249,249,.72)
      : const Color(0xB81C1C1E);

  static Color chromeSolid(Brightness b) =>
      b == Brightness.light ? const Color(0xFFF9F9F9) : const Color(0xFF1C1C1E);

  /// Hairline separator between rows.
  static Color separator(Brightness b) => b == Brightness.light
      ? const Color(0x2E3C3C43)
      : const Color(0xA6545458);

  static Color separatorSoft(Brightness b) => b == Brightness.light
      ? const Color(0x1A3C3C43)
      : const Color(0x59545458);

  /// Grey fills used by chips, search fields and unselected segments.
  static Color fill2(Brightness b) => b == Brightness.light
      ? const Color(0x29787880)
      : const Color(0x3D96969B);

  static Color fill3(Brightness b) => b == Brightness.light
      ? const Color(0x1E767680)
      : const Color(0x2996969B);

  // ------------------------------------------------------------ accents
  static Color tint(Brightness b) =>
      b == Brightness.light ? const Color(0xFF007AFF) : const Color(0xFF0A84FF);

  static Color green(Brightness b) =>
      b == Brightness.light ? const Color(0xFF34C759) : const Color(0xFF30D158);

  static Color red(Brightness b) =>
      b == Brightness.light ? const Color(0xFFFF3B30) : const Color(0xFFFF453A);

  static Color orange(Brightness b) =>
      b == Brightness.light ? const Color(0xFFFF9500) : const Color(0xFFFF9F0A);

  static Color yellow(Brightness b) =>
      b == Brightness.light ? const Color(0xFFFFCC00) : const Color(0xFFFFD60A);

  static Color indigo(Brightness b) =>
      b == Brightness.light ? const Color(0xFF5856D6) : const Color(0xFF5E5CE6);

  static Color purple(Brightness b) =>
      b == Brightness.light ? const Color(0xFFAF52DE) : const Color(0xFFBF5AF2);

  static Color pink(Brightness b) =>
      b == Brightness.light ? const Color(0xFFFF2D55) : const Color(0xFFFF375F);

  static Color teal(Brightness b) =>
      b == Brightness.light ? const Color(0xFF5AC8FA) : const Color(0xFF64D2FF);

  static Color gray(Brightness b) =>
      b == Brightness.light ? const Color(0xFF8E8E93) : const Color(0xFF98989D);

  // ------------------------------------------------------- DNS semantics
  // The prototype maps query outcomes onto system colours instead of the
  // Material "primary/grey/red" blocks the app used before.

  /// Blocked query.
  static Color blocked(Brightness b) => red(b);

  /// Allowed query.
  static Color allowed(Brightness b) => green(b);

  /// Resolved upstream / informational.
  static Color upstream(Brightness b) => tint(b);

  /// Warning (safe browsing / parental replacements).
  static Color warning(Brightness b) => orange(b);

  /// Tint of a protection switch: green when the protection is running,
  /// neutral grey when it is off.
  static Color protection(Brightness b, bool enabled) =>
      enabled ? green(b) : fill2(b);

  /// Soft background for a status pill.
  static Color pillBackground(Brightness b, Color color) =>
      color.withValues(alpha: b == Brightness.light ? 0.14 : 0.20);
}
