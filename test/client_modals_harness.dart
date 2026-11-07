import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/blocked_services.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'surface.dart';

// The device pickers read the blocked-service catalog from the server and hand
// their edits back through a callback. No test can reach a server, so the
// catalog comes from a fixture and the provider below answers from it.

List<BlockedService> serviceCatalog(int count) => List.generate(
      count,
      (index) => BlockedService(
        id: 'svc_$index',
        name: 'Service $index',
        iconSvg: '',
        rules: const [],
      ),
    );

class StubFiltering extends FilteringProvider {
  StubFiltering({required this.services, this.succeeds = true});

  final List<BlockedService> services;
  bool succeeds;
  int loads = 0;
  final loaderFlags = <bool?>[];

  /// Held shut while a test wants to look at the loading state.
  Completer<bool>? gate;

  @override
  Future<bool> getBlockedServices({bool? showLoader}) async {
    loads++;
    loaderFlags.add(showLoader);
    final wait = gate;
    if (wait != null) {
      await wait.future;
    } else {
      // A real request answers after the frame that opened the sheet, and a
      // synchronous notify would land inside the modal's own initState.
      await Future<void>.delayed(Duration.zero);
    }

    if (succeeds) {
      setBlockedServicesListLoadStatus(LoadStatus.loaded, false);
      setBlockedServiceListData(services);
      return true;
    }
    setBlockedServicesListLoadStatus(LoadStatus.error, true);
    return false;
  }
}

/// Pumps [body] as the home of an Apple themed app, at [surface] size.
///
/// [body] gets the context under the navigator, so it can open the real
/// dialogs and sheets the way a screen does.
Future<void> pumpAppleApp(
  WidgetTester tester, {
  required Widget Function(BuildContext) body,
  List<SingleChildWidget> providers = const [],
  Size surface = const Size(390, 844),
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
}) async {
  setTestSurface(tester, surface);

  final app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.dark ? appleDarkTheme() : appleLightTheme(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(body: Center(child: body(context))),
    ),
  );

  await tester.pumpWidget(
    providers.isEmpty ? app : MultiProvider(providers: providers, child: app),
  );
  await tester.pumpAndSettle();
}

/// Opens a route and waits for its transition without settling the whole tree,
/// which a loading spinner would never let finish.
Future<void> settleRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

/// A multi-choice row of the design layer: its title, and the tick it draws on
/// the trailing edge when the row is chosen.
Finder checkRow(String label) => find.widgetWithText(AppleListTile, label);

bool isChecked(WidgetTester tester, String label) => find
    .descendant(
      of: checkRow(label),
      matching: find.byIcon(CupertinoIcons.checkmark),
    )
    .evaluate()
    .isNotEmpty;

bool rowEnabled(WidgetTester tester, String label) =>
    tester.widget<AppleListTile>(checkRow(label)).enabled;
