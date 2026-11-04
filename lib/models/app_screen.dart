import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppScreen {
  final String name;
  final IconData icon;

  /// Cupertino glyphs used by the Apple shell ([AppConfigProvider.useAppleStyle]).
  final IconData? appleIcon;
  final IconData? appleSelectedIcon;

  final PreferredSizeWidget? appBar;
  final Widget? fab;
  final Widget child;

  const AppScreen({
    required this.name,
    required this.icon,
    this.appleIcon,
    this.appleSelectedIcon,
    this.appBar,
    this.fab,
    required this.child,
  });
}