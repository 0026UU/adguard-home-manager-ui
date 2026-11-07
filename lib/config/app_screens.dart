import 'package:flutter/cupertino.dart';

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
    icon: CupertinoIcons.link,
    appleIcon: CupertinoIcons.link,
    appleSelectedIcon: CupertinoIcons.link, 
    child: Connect()
  ),
  const AppScreen(
    name: "settings", 
    icon: CupertinoIcons.settings,
    appleIcon: CupertinoIcons.settings,
    appleSelectedIcon: CupertinoIcons.settings_solid,
    child: Settings()
  )
];

List<AppScreen> screensServerConnected = [
  const AppScreen(
    name: "home", 
    icon: CupertinoIcons.house,
    appleIcon: CupertinoIcons.house,
    appleSelectedIcon: CupertinoIcons.house_fill, 
    child: Home()
  ),
  const AppScreen(
    name: "clients", 
    icon: CupertinoIcons.person_2,
    appleIcon: CupertinoIcons.person_2,
    appleSelectedIcon: CupertinoIcons.person_2_fill, 
    child: Clients()
  ),
  const AppScreen(
    name: "logs", 
    icon: CupertinoIcons.doc_text,
    appleIcon: CupertinoIcons.doc_text,
    appleSelectedIcon: CupertinoIcons.doc_text_fill, 
    child: Logs()
  ),
  const AppScreen(
    name: "filters", 
    icon: CupertinoIcons.shield,
    appleIcon: CupertinoIcons.shield,
    appleSelectedIcon: CupertinoIcons.shield_fill, 
    child: Filters()
  ),
  const AppScreen(
    name: "settings", 
    icon: CupertinoIcons.settings,
    appleIcon: CupertinoIcons.settings,
    appleSelectedIcon: CupertinoIcons.settings_solid,
    child: Settings()
  )
];