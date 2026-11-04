import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:adguard_home_manager/screens/clients/clients.dart';
import 'package:adguard_home_manager/screens/connect/connect.dart';
import 'package:adguard_home_manager/screens/filters/filters.dart';
import 'package:adguard_home_manager/screens/home/home.dart';
import 'package:adguard_home_manager/screens/logs/logs.dart';
import 'package:adguard_home_manager/screens/settings/settings.dart';

import 'package:adguard_home_manager/models/app_screen.dart';

List<AppScreen> screensSelectServer = [
  const AppScreen(
    name: "connect", 
    icon: Icons.link_rounded,
    appleIcon: CupertinoIcons.link,
    appleSelectedIcon: CupertinoIcons.link, 
    child: Connect()
  ),
  const AppScreen(
    name: "settings", 
    icon: Icons.settings_rounded,
    appleIcon: CupertinoIcons.settings,
    appleSelectedIcon: CupertinoIcons.settings_solid,
    child: Settings()
  )
];

List<AppScreen> screensServerConnected = [
  const AppScreen(
    name: "home", 
    icon: Icons.home_rounded,
    appleIcon: CupertinoIcons.house,
    appleSelectedIcon: CupertinoIcons.house_fill, 
    child: Home()
  ),
  const AppScreen(
    name: "clients", 
    icon: Icons.devices,
    appleIcon: CupertinoIcons.person_2,
    appleSelectedIcon: CupertinoIcons.person_2_fill, 
    child: Clients()
  ),
  const AppScreen(
    name: "logs", 
    icon: Icons.list_alt_rounded,
    appleIcon: CupertinoIcons.doc_text,
    appleSelectedIcon: CupertinoIcons.doc_text_fill, 
    child: Logs()
  ),
  const AppScreen(
    name: "filters", 
    icon: Icons.shield_rounded,
    appleIcon: CupertinoIcons.shield,
    appleSelectedIcon: CupertinoIcons.shield_fill, 
    child: Filters()
  ),
  const AppScreen(
    name: "settings", 
    icon: Icons.settings_rounded,
    appleIcon: CupertinoIcons.settings,
    appleSelectedIcon: CupertinoIcons.settings_solid,
    child: Settings()
  )
];