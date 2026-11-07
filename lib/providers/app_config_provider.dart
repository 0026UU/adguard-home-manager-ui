
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:adguard_home_manager/classes/http_override.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/constants/languages.dart';
import 'package:adguard_home_manager/services/platform_locale.dart';
import 'package:adguard_home_manager/config/home_top_items_default_order.dart';
import 'package:adguard_home_manager/models/app_log.dart';

class AppConfigProvider with ChangeNotifier {
  final SharedPreferences sharedPreferencesInstance;

  AppConfigProvider({
    required this.sharedPreferencesInstance
  });

  PackageInfo? _appInfo;

  int _selectedScreen = 0;

  int? _selectedSettingsScreen;

  bool _showingSnackbar = false;

  int _selectedTheme = 0;

  /// BCP 47 tag, or null to follow the system language.
  String? _selectedLanguage;
  bool _useThemeColorForStatus = false;

  int _selectedClientsTab = 0;

  List<HomeTopItems> _homeTopItemsOrder = homeTopItemsDefaultOrder;

  bool _hideServerAddress = false;

  final List<AppLog> _logs = [];

  bool _overrideSslCheck = false;

  bool _hideZeroValues = false;

  /// Whether the live view keeps pulling the query log on its own.
  bool _autoRefreshLiveLogs = true;

  PackageInfo? get getAppInfo {
    return _appInfo;
  }

  ThemeMode get selectedTheme {
    switch (_selectedTheme) {
      case 0:
        return SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.light 
          ? ThemeMode.light 
          : ThemeMode.dark;

      case 1:
        return ThemeMode.light;

      case 2:
        return ThemeMode.dark;

      default:
        return ThemeMode.light;
    }
  }

  int get selectedThemeNumber {
    return _selectedTheme;
  }

  String? get selectedLanguage {
    return _selectedLanguage;
  }

  /// Null lets MaterialApp resolve the system language itself.
  Locale? get selectedLocale {
    return languageFromTag(_selectedLanguage)?.locale;
  }

  int get selectedClientsTab {
    return _selectedClientsTab;
  }

  List<AppLog> get logs {
    return _logs;
  }

  bool get overrideSslCheck {
    return _overrideSslCheck;
  }

  bool get hideZeroValues {
    return _hideZeroValues;
  }

  int get selectedScreen {
    return _selectedScreen;
  }

  bool get showingSnackbar {
    return _showingSnackbar;
  }

  bool get useThemeColorForStatus {
    return _useThemeColorForStatus;
  }

  bool get autoRefreshLiveLogs {
    return _autoRefreshLiveLogs;
  }

  int? get selectedSettingsScreen {
    return _selectedSettingsScreen;
  }

  List<HomeTopItems> get homeTopItemsOrder {
    return _homeTopItemsOrder;
  }

  bool get hideServerAddress {
    return _hideServerAddress;
  }

  void setAppInfo(PackageInfo appInfo) {
    _appInfo = appInfo;
  }

  void setSelectedClientsTab(int tab) {
    _selectedClientsTab = tab;
    notifyListeners();
  }

  void addLog(AppLog log) {
    _logs.add(log);
    notifyListeners();
  }

  void setSelectedScreen(int screen) {
    _selectedScreen = screen;
    notifyListeners();
  }

  void setShowingSnackbar(bool status) async {
    _showingSnackbar = status;
    notifyListeners();
  }

  void setSelectedSettingsScreen({required int? screen, bool? notify}) {
    _selectedSettingsScreen = screen;
    if (notify == true) {
      notifyListeners();
    }
  }

  Future<bool> setOverrideSslCheck(bool status) async {
    try {
      sharedPreferencesInstance.setBool('overrideSslCheck', status);
      _overrideSslCheck = status;
      // [main] installs this override once, at startup. Reassigning it here is
      // what makes the switch bite on the next request instead of only after
      // the app has been restarted, which is the case a self-signed server
      // needs it for.
      HttpOverrides.global = status ? MyHttpOverrides() : null;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> setHideZeroValues(bool status) async {
    try {
      sharedPreferencesInstance.setBool('hideZeroValues', status);
      _hideZeroValues = status;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> setSelectedTheme(int value) async {
    try {
      sharedPreferencesInstance.setInt('selectedTheme', value);
      _selectedTheme = value;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> setSelectedLanguage(String? value) async {
    try {
      if (value == null) {
        sharedPreferencesInstance.remove('selectedLanguage');
      }
      else {
        sharedPreferencesInstance.setString('selectedLanguage', value);
      }
      _selectedLanguage = value;
      await PlatformLocaleService.setApplicationLocale(value);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      return false;
    }
  }

  /// The system entry wins, since it can be changed while the app is closed.
  Future<void> syncLanguageWithSystem() async {
    try {
      final systemTag = await PlatformLocaleService.getApplicationLocale();
      final resolved = languageFromTag(systemTag)?.tag;
      if (resolved == _selectedLanguage) return;
      if (systemTag == null && _selectedLanguage != null) {
        await PlatformLocaleService.setApplicationLocale(_selectedLanguage);
        return;
      }
      _selectedLanguage = resolved;
      if (resolved == null) {
        sharedPreferencesInstance.remove('selectedLanguage');
      }
      else {
        sharedPreferencesInstance.setString('selectedLanguage', resolved);
      }
      notifyListeners();
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  Future<bool> setAutoRefreshLiveLogs(bool value) async {
    try {
      sharedPreferencesInstance.setBool('autoRefreshLiveLogs', value);
      _autoRefreshLiveLogs = value;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> setUseThemeColorForStatus(bool value) async {
    try {
      sharedPreferencesInstance.setBool('useThemeColorForStatus', value);
      _useThemeColorForStatus = value;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> setHomeTopItemsOrder(List<HomeTopItems> order) async {
    try {
      sharedPreferencesInstance.setStringList('homeTopItemsOrder', List<String>.from(order.map((e) => e.name)));
      _homeTopItemsOrder = order;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> setHideServerAddress(bool value) async {
    try {
      sharedPreferencesInstance.setBool('hideServerAddress', value);
      _hideServerAddress = value;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      return false;
    }
  }

  void saveFromSharedPreferences() {
    _selectedTheme = sharedPreferencesInstance.getInt('selectedTheme') ?? 0;
    _selectedLanguage = sharedPreferencesInstance.getString('selectedLanguage');
    _overrideSslCheck = sharedPreferencesInstance.getBool('overrideSslCheck') ?? false;
    _hideZeroValues = sharedPreferencesInstance.getBool('hideZeroValues') ?? false;
    _useThemeColorForStatus =
        sharedPreferencesInstance.getBool('useThemeColorForStatus') ?? false;
    _autoRefreshLiveLogs =
        sharedPreferencesInstance.getBool('autoRefreshLiveLogs') ?? true;
    _hideServerAddress = sharedPreferencesInstance.getBool('hideServerAddress') ?? false;
    if (sharedPreferencesInstance.getStringList('homeTopItemsOrder') != null) {
      try {
        _homeTopItemsOrder = List<HomeTopItems>.from(
          List<String>.from(sharedPreferencesInstance.getStringList('homeTopItemsOrder')!).map((e) {
            switch (e) {
              case 'queriedDomains':
                return HomeTopItems.queriedDomains;

              case 'blockedDomains':
                return HomeTopItems.blockedDomains;

              case 'recurrentClients':
                return HomeTopItems.recurrentClients;

              // A stored order can still carry the names of rankings an older
              // build put on the dashboard. They have no segment to show now,
              // so they drop out here rather than reaching the card.
              default:
                return null;
            }
          }).where((e) => e != null).toList()
        );
      } catch (e) {
        Sentry.captureException(e);
        _homeTopItemsOrder = homeTopItemsDefaultOrder;
      }
    }
  }
}