import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

class OverlayStyle extends StatelessWidget {
  final Widget child;

  const OverlayStyle({
    super.key,
    required this.child
  });

  @override
  Widget build(BuildContext context) {
    final systemGestureInsets = MediaQuery.of(context).systemGestureInsets;

    // The bars read from the Apple palette so light and dark stay in sync with
    // the rest of the chrome instead of the Material colour scheme.
    final p = ApplePalette.of(context);
    final bool light = p.brightness == Brightness.light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: light ? Brightness.light : Brightness.dark,
        statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: systemGestureInsets.left > 0  // If true gestures navigation
          ? Colors.transparent
          : p.chromeSolid,
        systemNavigationBarIconBrightness: light ? Brightness.dark : Brightness.light,
      ),
      child: child,
    );
  }
}
