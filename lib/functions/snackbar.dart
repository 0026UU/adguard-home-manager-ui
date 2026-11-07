// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

void showSnackbar({
  required AppConfigProvider appConfigProvider,
  required String label,
  Color? color,
  Color? labelColor,
  GlobalKey<ScaffoldMessengerState>? key,
  Duration? duration,
}) async {
  // The shell has no bottom bar to clear, so a result is announced with the
  // floating pill instead of a Material snack bar. The context has to come
  // from below MaterialApp's theme, which the messenger key is not. A label
  // with no colour is a plain confirmation, so the pill carries no accent.
  final BuildContext? context = globalNavigatorKey.currentContext;
  if (context == null) return;

  // Callers still hand over Material's own palette — they predate the design
  // layer — and Material red/green are the wrong hue and weight against an
  // Apple card in either appearance. Translating it here fixes every pill at
  // once instead of at the hundred call sites.
  final ApplePalette palette = ApplePalette.of(context);
  Color? accent = color;
  if (color == Colors.red) accent = palette.red;
  if (color == Colors.green) accent = palette.green;
  if (color == Colors.orange) accent = palette.orange;
  if (color == Colors.blue) accent = palette.tint;

  AppleToast.show(
    context,
    message: label,
    accent: accent,
    duration: duration ?? const Duration(milliseconds: 1600),
  );
}