import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

Map<String, dynamic> getFilteredStatus(BuildContext context, AppConfigProvider appConfigProvider, String filterKey, bool isRow) {
  final palette = ApplePalette.of(context);

  switch (filterKey) {
    case 'NotFilteredNotFound':
      return {
        'filtered': false,
        'label': isRow == true
          ? AppLocalizations.of(context)!.processedRow
          : AppLocalizations.of(context)!.processed,
        'color': appConfigProvider.useThemeColorForStatus == true
            ? palette.tint
            : Colors.green,
        'icon': CupertinoIcons.checkmark_shield,
      };

    case 'NotFilteredWhiteList':
      return {
        'filtered': false,
        'label': isRow == true
          ? AppLocalizations.of(context)!.processedWhitelistRow
          : AppLocalizations.of(context)!.processedWhitelist,
        'color': appConfigProvider.useThemeColorForStatus == true
          ? palette.tint
          : Colors.green,
        'icon': CupertinoIcons.checkmark_shield,
      };

    case 'NotFilteredError':
      return {
        'filtered': false,
        'label': isRow == true 
          ? AppLocalizations.of(context)!.processedErrorRow
          : AppLocalizations.of(context)!.processedError,
        'color': appConfigProvider.useThemeColorForStatus == true
          ? palette.tint
          : Colors.green,
        'icon': CupertinoIcons.checkmark_shield,
      };

    case 'FilteredBlackList':
      return {
        'filtered': true,
        'label': isRow == true
          ? AppLocalizations.of(context)!.blockedBlacklistRow
          : AppLocalizations.of(context)!.blockedBlacklist,
        'color': appConfigProvider.useThemeColorForStatus == true
          ? palette.gray
          : palette.red,
        'icon': CupertinoIcons.shield_slash,
      };

    case 'FilteredSafeBrowsing':
      return {
        'filtered': true,
        'label': isRow == true
          ? AppLocalizations.of(context)!.blockedSafeBrowsingRow
          : AppLocalizations.of(context)!.blockedSafeBrowsing,
        'color': appConfigProvider.useThemeColorForStatus == true
          ? palette.gray
          : palette.red,
        'icon': CupertinoIcons.shield_slash,
      };

    case 'FilteredParental':
      return {
        'filtered': true,
        'label': isRow == true
          ? AppLocalizations.of(context)!.blockedParentalRow
          : AppLocalizations.of(context)!.blockedParental,
        'color': appConfigProvider.useThemeColorForStatus == true
          ? palette.gray
          : palette.red,
        'icon': CupertinoIcons.shield_slash,
      };

    case 'FilteredInvalid':
      return {
        'filtered': true,
        'label': isRow == true
          ? AppLocalizations.of(context)!.blockedInvalidRow
          : AppLocalizations.of(context)!.blockedInvalid,
        'color': appConfigProvider.useThemeColorForStatus == true
          ? palette.gray
          : palette.red,
        'icon': CupertinoIcons.shield_slash,
      };

    case 'FilteredSafeSearch':
      return {
        'filtered': true,
        'label': isRow == true 
          ? AppLocalizations.of(context)!.blockedSafeSearchRow
          : AppLocalizations.of(context)!.blockedSafeSearch,
        'color': appConfigProvider.useThemeColorForStatus == true
          ? palette.gray
          : palette.red,
        'icon': CupertinoIcons.shield_slash,
      };

    case 'FilteredBlockedService':
      return {
        'filtered': true,
        'label': isRow == true
          ? AppLocalizations.of(context)!.blockedServiceRow
          : AppLocalizations.of(context)!.blockedService,
        'color': appConfigProvider.useThemeColorForStatus == true
          ? palette.gray
          : palette.red,
        'icon': CupertinoIcons.shield_slash,
      };

    case 'Rewrite':
    case 'RewriteEtcHosts':
    case 'RewriteRule':
      return {
        'filtered': true,
        'label': AppLocalizations.of(context)!.rewrite,
        'color': palette.tint,
        'icon': CupertinoIcons.shield,
      };

    default:
      return {
        'filtered': null,
        'label': AppLocalizations.of(context)!.unknownResult,
      };
  }
}

bool isDomainBlocked(String filterKey) {
  switch (filterKey) {
    case 'NotFilteredNotFound':
      return false;

    case 'NotFilteredWhiteList':
      return false;

    case 'NotFilteredError':
      return false;

    case 'FilteredBlackList':
      return true;

    case 'FilteredSafeBrowsing':
      return true;

    case 'FilteredParental':
      return true;

    case 'FilteredInvalid':
      return true;

    case 'FilteredSafeSearch':
      return true;

    case 'FilteredBlockedService':
      return true;

    case 'Rewrite':
    case 'RewriteEtcHosts':
    case 'RewriteRule':
      return false;

    default:
      return false;
  }
}