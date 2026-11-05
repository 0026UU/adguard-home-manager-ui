// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

void showSnackbar({
  required AppConfigProvider appConfigProvider,
  required String label,
  required Color color,
  Color? labelColor,
  GlobalKey<ScaffoldMessengerState>? key,
  Duration? duration,
}) async {
  final GlobalKey<ScaffoldMessengerState> scaffoldKey = key ?? scaffoldMessengerKey;

  // The Apple shell has no bottom bar to clear, so a result is announced with
  // the floating pill instead of a Material snack bar. The context has to come
  // from below MaterialApp's theme, which the messenger key is not.
  if (appConfigProvider.useAppleStyle) {
    final BuildContext? context = globalNavigatorKey.currentContext;
    if (context == null) return;

    AppleToast.show(
      context,
      message: label,
      accent: color,
      duration: duration ?? const Duration(milliseconds: 1600),
    );
    return;
  }

  if (appConfigProvider.showingSnackbar == true) {
    scaffoldKey.currentState?.clearSnackBars();
    await Future.delayed(const Duration(milliseconds: 500));
  }
  appConfigProvider.setShowingSnackbar(true);

  final snackBar = SnackBar(
    content: Text(
      label,
      style: TextStyle(
        color: labelColor ?? Colors.white
      ),
    ),
    backgroundColor: color,
    // Leaving this null keeps the framework default of four seconds, which is
    // what every existing call relies on.
    duration: duration ?? const Duration(seconds: 4),
  );
  scaffoldKey.currentState?.showSnackBar(snackBar).closed.then(
    (value) => appConfigProvider.setShowingSnackbar(false)
  ); 
}