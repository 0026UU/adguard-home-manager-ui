import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:adguard_home_manager/config/apple_colors.dart';

/// Typography that follows the iOS text styles (large title 34 / title3 22 /
/// body 17 / footnote 13 / caption 12) with Apple's negative tracking on the
/// display sizes.
///
/// No font family is forced: on iOS/macOS this resolves to the real SF Pro,
/// elsewhere to the platform default. Shipping SF Pro would be an Apple
/// licensing problem, so the layout carries the style instead.
TextTheme appleTextTheme(Brightness b) {
  final Color primary = AppleColors.label(b);
  final Color secondary = AppleColors.label2(b);
  final Color tertiary = AppleColors.label3(b);

  TextStyle s(double size, double height, FontWeight w, Color c, {double tracking = 0}) =>
      TextStyle(
        fontSize: size,
        height: height,
        fontWeight: w,
        color: c,
        letterSpacing: tracking,
      );

  return TextTheme(
    displayLarge: s(34, 1.15, FontWeight.w800, primary, tracking: -0.8),
    displayMedium: s(28, 1.15, FontWeight.w700, primary, tracking: -0.6),
    headlineMedium: s(22, 1.2, FontWeight.w700, primary, tracking: -0.4),
    headlineSmall: s(17, 1.2, FontWeight.w600, primary, tracking: -0.4),
    titleLarge: s(17, 1.2, FontWeight.w600, primary, tracking: -0.4),
    titleMedium: s(16, 1.25, FontWeight.w600, primary, tracking: -0.2),
    titleSmall: s(15, 1.25, FontWeight.w600, primary, tracking: -0.2),
    bodyLarge: s(17, 1.3, FontWeight.w400, primary, tracking: -0.4),
    bodyMedium: s(15, 1.35, FontWeight.w400, primary, tracking: -0.2),
    bodySmall: s(13, 1.4, FontWeight.w400, secondary, tracking: -0.08),
    labelLarge: s(15, 1.2, FontWeight.w600, primary, tracking: -0.2),
    labelMedium: s(13, 1.3, FontWeight.w600, secondary, tracking: 0.1),
    labelSmall: s(11, 1.3, FontWeight.w600, tertiary, tracking: 0.3),
  );
}

ColorScheme _scheme(Brightness b) {
  final bool light = b == Brightness.light;
  return ColorScheme(
    brightness: b,
    primary: AppleColors.tint(b),
    onPrimary: Colors.white,
    primaryContainer: light ? const Color(0xFFD6E4FF) : const Color(0xFF003A7A),
    onPrimaryContainer: AppleColors.label(b),
    secondary: AppleColors.gray(b),
    onSecondary: Colors.white,
    secondaryContainer: AppleColors.fill2(b),
    onSecondaryContainer: AppleColors.label(b),
    tertiary: AppleColors.indigo(b),
    onTertiary: Colors.white,
    tertiaryContainer: AppleColors.fill3(b),
    onTertiaryContainer: AppleColors.label(b),
    error: AppleColors.red(b),
    onError: Colors.white,
    errorContainer: light ? const Color(0xFFFFE0DE) : const Color(0xFF3D1714),
    onErrorContainer: AppleColors.label(b),
    surface: AppleColors.systemGrouped(b),
    onSurface: AppleColors.label(b),
    onSurfaceVariant: AppleColors.label2(b),
    surfaceContainerLowest: AppleColors.system(b),
    surfaceContainerLow: AppleColors.groupedCard(b),
    surfaceContainer: AppleColors.groupedCard(b),
    surfaceContainerHigh: AppleColors.groupedCard2(b),
    surfaceContainerHighest: AppleColors.groupedCard2(b),
    surfaceBright: AppleColors.groupedCard2(b),
    surfaceDim: AppleColors.systemGrouped(b),
    outline: AppleColors.gray(b),
    outlineVariant: AppleColors.separator(b),
    shadow: light ? Colors.black : Colors.black,
    scrim: const Color(0x52000000),
    inverseSurface: AppleColors.label(b),
    onInverseSurface: AppleColors.system(b),
    inversePrimary: AppleColors.tint(b),
  );
}

/// iOS-flavoured [ThemeData]. Material widgets keep working (so the untouched
/// screens do not break), but colours, metrics and transitions are Apple's.
ThemeData appleTheme(Brightness brightness) {
  final ColorScheme scheme = _scheme(brightness);
  final TextTheme text = appleTextTheme(brightness);
  final Color card = AppleColors.groupedCard(brightness);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppleColors.systemGrouped(brightness),
    canvasColor: AppleColors.systemGrouped(brightness),
    cardColor: card,
    dividerColor: AppleColors.separator(brightness),
    textTheme: text,
    primaryTextTheme: text,
    // No ink ripple anywhere: iOS flashes a grey highlight instead.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    // iOS push transition on every platform.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppleColors.chromeSolid(brightness),
      foregroundColor: AppleColors.label(brightness),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      systemOverlayStyle: brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppleColors.chromeSolid(brightness),
      selectedItemColor: AppleColors.tint(brightness),
      unselectedItemColor: AppleColors.label2(brightness),
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: text.labelSmall,
      unselectedLabelStyle: text.labelSmall,
      elevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppleColors.systemGrouped(brightness),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      showDragHandle: false,
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titleTextStyle: text.headlineMedium,
      contentTextStyle: text.bodyMedium,
      barrierColor: const Color(0x52000000),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppleColors.label(brightness).withValues(alpha: 0.9),
      contentTextStyle: text.labelLarge?.copyWith(
        color: AppleColors.system(brightness),
      ),
      shape: const StadiumBorder(),
      elevation: 0,
      actionTextColor: AppleColors.tint(brightness),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppleColors.label2(brightness),
      textColor: AppleColors.label(brightness),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    dividerTheme: DividerThemeData(
      color: AppleColors.separator(brightness),
      thickness: 0.5,
      space: 0.5,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppleColors.fill3(brightness),
      hintStyle: text.bodyLarge?.copyWith(color: AppleColors.label3(brightness)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppleColors.tint(brightness), width: 2),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppleColors.tint(brightness),
      linearTrackColor: AppleColors.fill3(brightness),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppleColors.green(brightness)
            : AppleColors.fill2(brightness),
      ),
      thumbColor: WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStatePropertyAll(AppleColors.tint(brightness)),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStatePropertyAll(AppleColors.tint(brightness)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppleColors.tint(brightness),
      inactiveTrackColor: AppleColors.fill2(brightness),
      thumbColor: Colors.white,
      trackHeight: 3,
      overlayColor: AppleColors.tint(brightness).withValues(alpha: 0.12),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppleColors.groupedCard(brightness),
      selectedColor: AppleColors.tint(brightness),
      side: BorderSide(color: AppleColors.separator(brightness)),
      labelStyle: text.labelLarge,
      shape: const StadiumBorder(),
      showCheckmark: false,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppleColors.label(brightness),
      unselectedLabelColor: AppleColors.label2(brightness),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelStyle: text.titleMedium,
      unselectedLabelStyle: text.titleMedium,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppleColors.label(brightness).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: text.bodySmall?.copyWith(color: AppleColors.system(brightness)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: text.bodyMedium,
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: AppleColors.tint(brightness),
      applyThemeToAll: true,
    ),
  );
}

ThemeData appleLightTheme() => appleTheme(Brightness.light);

ThemeData appleDarkTheme() => appleTheme(Brightness.dark);
