// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

void copyToClipboard({
  required String value,
  required String successMessage
}) async {
  final ScaffoldMessengerState? messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;

  await Clipboard.setData(
    ClipboardData(text: value)
  );

  // MaterialApp puts the theme below the messenger, so the style can only be
  // read from a context under the navigator.
  final BuildContext? context = globalNavigatorKey.currentContext;

  if (context != null && appleStyleOf(context)) {
    AppleToast.show(
      context,
      message: successMessage,
      icon: Icons.copy_rounded,
    );
    return;
  }

  messenger.showSnackBar(
    SnackBar(
      content: Text(successMessage),
      backgroundColor: Colors.green,
    )
  );
}