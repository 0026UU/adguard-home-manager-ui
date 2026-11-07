import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';

import 'surface.dart';

// The log filter sheets read the devices the server knows and refetch the
// query log on every change. Neither test file can reach a server, so the
// doubles below answer from these fixtures.

AutoClient autoClientFixture(int index) => AutoClient(
      whoisInfo: WhoisInfo(country: 'IT', orgname: 'Example'),
      name: index.isEven ? 'device-$index' : null,
      source: 'rdns',
      ip: '192.168.1.$index',
    );

Client addedClientFixture(int index) => Client(
      name: 'client-$index',
      blockedServices: const [],
      ids: ['10.0.0.$index', 'aa:bb:cc:dd:ee:ff'],
      tags: const [],
      upstreams: const [],
      rules: const [],
      filteringEnabled: true,
      parentalEnabled: false,
      safebrowsingEnabled: true,
      useGlobalBlockedServices: true,
      useGlobalSettings: true,
      safeSearch: null,
      ignoreQuerylog: null,
      ignoreStatistics: null,
      upstreamsCacheEnabled: null,
      upstreamsCacheSize: null,
      blockedServicesSchedule: null,
    );

Clients clientsFixture() => Clients(
      clients: [addedClientFixture(0)],
      autoClients: [autoClientFixture(1), autoClientFixture(2)],
      supportedTags: const [],
    );

/// More devices than the filter sheet lists inline.
Clients manyClientsFixture() => Clients(
      clients: [addedClientFixture(0)],
      autoClients: [for (var i = 1; i <= 7; i++) autoClientFixture(i)],
      supportedTags: const [],
    );

/// Choosing a log filter always refetches the logs, which needs a live server.
/// Only the widget wiring is under test here, so the network call is dropped
/// while the draft → applied promotion of the real provider still runs.
class OfflineLogs extends LogsProvider {
  @override
  Future<bool> fetchLogs({
    int? inOffset,
    bool? loadingMore,
    String? searchText,
  }) async =>
      true;
}

/// The providers the log filters hand to these sheets. `serverStatus` stays
/// empty on purpose: the sheets read it through a `try/catch` and fall back to
/// the raw identifiers.
class SheetsHarness {
  final LogsProvider logs = OfflineLogs();
  final ClientsProvider clients = ClientsProvider();
  final StatusProvider status = StatusProvider();

  SheetsHarness();

  SheetsHarness.withClients() {
    clients.setClientsLoadStatus(LoadStatus.loaded, false);
    clients.setClientsData(clientsFixture(), false);
  }

  SheetsHarness.withManyClients() {
    clients.setClientsLoadStatus(LoadStatus.loaded, false);
    clients.setClientsData(manyClientsFixture(), false);
  }

  List<SingleChildWidget> get providers => [
        ChangeNotifierProvider.value(value: logs),
        ChangeNotifierProvider.value(value: clients),
        ChangeNotifierProvider.value(value: status),
      ];
}

late BuildContext _hostContext;

/// Presents [modal] the way `logs_filters_modal.dart` does: a card on wide
/// layouts, a full-height sheet on phones.
Future<void> pumpSheet(
  WidgetTester tester,
  SheetsHarness harness,
  Size surface,
  Widget modal, {
  Brightness brightness = Brightness.light,
}) async {
  SharedPreferences.setMockInitialValues({});

  setTestSurface(tester, surface);

  await tester.pumpWidget(
    MultiProvider(
      providers: harness.providers,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appleLightTheme(),
        darkTheme: appleDarkTheme(),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) {
            _hostContext = ctx;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (surface.width > 600) {
    showDialog(context: _hostContext, builder: (_) => modal);
  } else {
    showModalBottomSheet(
      context: _hostContext,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => modal,
    );
  }
  await tester.pumpAndSettle();
}
