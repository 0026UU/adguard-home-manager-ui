// ignore_for_file: use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';

/// The engines `/status` reports a safe search for, with the key each one is
/// written back under.
class _Engine {
  final String key;
  final String name;

  const _Engine(this.key, this.name);
}

const List<_Engine> _engines = [
  _Engine('bing', 'Bing'),
  _Engine('duckduckgo', 'DuckDuckGo'),
  _Engine('ecosia', 'Ecosia'),
  _Engine('google', 'Google'),
  _Engine('pixabay', 'Pixabay'),
  _Engine('yandex', 'Yandex'),
  _Engine('youtube', 'YouTube'),
];

/// Per-engine safe search, the screen the Apple shell had dropped.
///
/// The switches are a draft: `/safe_search/configure` takes all eight flags at
/// once, so a single tap of the checkmark is the one write, exactly as before.
/// A write the server refused puts the switches back where the server says
/// they are instead of leaving the page claiming a state it does not have.
class SafeSearchSettingsScreen extends StatefulWidget {
  const SafeSearchSettingsScreen({super.key});

  @override
  State<SafeSearchSettingsScreen> createState() =>
      _SafeSearchSettingsScreenState();
}

class _SafeSearchSettingsScreenState extends State<SafeSearchSettingsScreen> {
  bool _generalEnabled = false;
  Map<String, bool> _values = {for (final e in _engines) e.key: false};

  Future<void> requestSafeSearchSettings() async {
    final result = await Provider.of<StatusProvider>(context, listen: false)
        .getServerStatus();
    if (!mounted || result == false) return;

    _readFromServer();
  }

  void _readFromServer() {
    final status = Provider.of<StatusProvider>(context, listen: false)
        .serverStatus;
    if (status == null) return;

    setState(() {
      _generalEnabled = status.safeSearchEnabled;
      _values = {
        'bing': status.safeSeachBing ?? false,
        'duckduckgo': status.safeSearchDuckduckgo ?? false,
        'ecosia': status.safeSearchEcosia ?? false,
        'google': status.safeSearchGoogle ?? false,
        'pixabay': status.safeSearchPixabay ?? false,
        'yandex': status.safeSearchYandex ?? false,
        'youtube': status.safeSearchYoutube ?? false,
      };
    });
  }

  @override
  void initState() {
    final statusProvider =
        Provider.of<StatusProvider>(context, listen: false);

    if (statusProvider.loadStatus == LoadStatus.loaded) {
      _readFromServer();
    } else {
      requestSafeSearchSettings();
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<StatusProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final width = MediaQuery.of(context).size.width;
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    Future<void> saveConfig() async {
      final body = <String, bool>{
        'enabled': _generalEnabled,
        ..._values,
      };

      final result = await statusProvider.updateSafeSearchConfig(body);

      if (!result && mounted) {
        // The server kept what it had, so the page keeps what it had too.
        _readFromServer();
      }

      if (!mounted) return;

      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: result
            ? l.settingsUpdatedSuccessfully
            : l.settingsNotSaved,
        color: result ? p.green : p.red,
      );
    }

    List<Widget> content() {
      if (statusProvider.loadStatus == LoadStatus.loading) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppleLoading(label: l.loadingSafeSearchSettings),
          ),
        ];
      }

      if (statusProvider.loadStatus == LoadStatus.error ||
          statusProvider.serverStatus == null) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppleEmptyState(
              icon: CupertinoIcons.exclamationmark_triangle,
              title: l.safeSearchSettingsNotLoaded,
              // The pull handle belongs to the list of switches, and the list
              // is what did not arrive, so the card carries the retry.
              action: AppleButton(
                label: l.refresh,
                onPressed: requestSafeSearchSettings,
              ),
              color: p.red,
            ),
          ),
        ];
      }

      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppleListSection(
              children: [
                AppleSwitchListTile(
                  icon: CupertinoIcons.checkmark_shield,
                  iconColor: _generalEnabled ? p.green : p.gray,
                  title: l.enableSafeSearch,
                  subtitle: l.safeSearchHelper,
                  value: _generalEnabled,
                  onChanged: (value) =>
                      setState(() => _generalEnabled = value),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: AppleListSection(
            title: l.safeSearch,
            children: [
              for (final engine in _engines)
                AppleSwitchListTile(
                  title: engine.name,
                  // The server ignores the per-engine flags while the general
                  // one is down, so the rows go dead rather than offering a
                  // write that would change nothing.
                  value: _values[engine.key] ?? false,
                  onChanged: _generalEnabled
                      ? (value) => setState(
                            () => _values[engine.key] = value,
                          )
                      : null,
                ),
            ],
          ),
        ),
      ];
    }

    return AppleScreen(
      title: l.safeSearchSettings,
      subtitle: l.safeSearchHelper,
      leading: isDesktop(width)
          ? null
          : AppleBackButton(
              label: l.back,
              onPressed: () => Navigator.pop(context),
            ),
      onRefresh: requestSafeSearchSettings,
      actions: [
        IconButton(
          onPressed: statusProvider.loadStatus == LoadStatus.loaded
              ? saveConfig
              : null,
          tooltip: l.save,
          icon: const Icon(CupertinoIcons.checkmark),
        ),
      ],
      slivers: content(),
    );
  }
}
