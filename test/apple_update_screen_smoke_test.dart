import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/models/update_available.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/screens/settings/update_server/update_screen.dart';
import 'package:adguard_home_manager/services/api_client.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'surface.dart';

// The Updates page answers one question — can this server update itself, and
// what would it get — and offers one action. The tests below check that the
// answer is drawn from the design layer rather than a Material bar, that each
// of the four answers a check can give reads differently, that the changelog
// arrives as a card, and that the word on the bar sends the request exactly
// once.

/// What `/control/version.json` and `/status` answer together, the shape the
/// provider builds an [UpdateAvailableData] out of.
Map<String, dynamic> versionAnswer({
  String currentVersion = 'v0.107.43',
  String? newVersion = 'v0.108.0',
  bool canAutoupdate = true,
  bool disabled = false,
  String? changelog,
}) =>
    {
      'current_version': currentVersion,
      'new_version': newVersion,
      'can_autoupdate': canAutoupdate,
      'disabled': disabled,
      if (changelog != null) 'changelog': changelog,
    };

/// The same answer as the model the page opens with, so a test does not have to
/// run a request just to state a server's version.
UpdateAvailableData updateFixture({
  String currentVersion = 'v0.107.43',
  String? newVersion = 'v0.108.0',
  bool canAutoupdate = true,
  bool disabled = false,
  String? changelog,
}) =>
    UpdateAvailableData(
      currentVersion: currentVersion,
      newVersion: newVersion,
      announcement: null,
      announcementUrl: null,
      canAutoupdate: canAutoupdate,
      disabled: disabled,
      changelog: changelog,
    );

/// An API client that never opens a socket.
class UpdateApiStub extends ApiClientV2 {
  UpdateApiStub({required super.server});

  Map<String, dynamic> answer = versionAnswer();

  bool succeeds = true;

  /// Keeps the version answer back until the test releases it, so the page can
  /// be caught mid-check.
  bool blocksCheck = false;

  final Completer<void> checkGate = Completer<void>();

  /// The update request is held open by default, because the page that sends it
  /// then starts polling the server every two seconds.
  bool blocksUpdate = true;

  final Completer<void> updateGate = Completer<void>();

  int checkCalls = 0;
  int updateCalls = 0;

  Future<void> _settled() => Future<void>.delayed(Duration.zero);

  @override
  Future<ApiResponse> checkServerUpdates() async {
    await _settled();
    if (blocksCheck) await checkGate.future;
    checkCalls++;
    if (!succeeds) return const ApiResponse(successful: false);
    return ApiResponse(successful: true, content: answer);
  }

  @override
  Future<ApiResponse> requestUpdateServer() async {
    updateCalls++;
    if (blocksUpdate) await updateGate.future;
    return const ApiResponse(successful: true);
  }
}

class UpdateHarness {
  UpdateHarness(this.api, this.servers);

  final UpdateApiStub api;
  final ServersProvider servers;
}

/// Pumps the Updates page the way the settings list pushes it.
///
/// The route is pushed rather than used as the home widget because the page
/// draws its own back capsule, which only appears when there is a route to go
/// back to. The answer the server gives is placed on the provider before the
/// page opens, which is what the app has already done by then; [status] as
/// [LoadStatus.loading] instead leaves the page waiting on a real request.
Future<UpdateHarness> pumpUpdateScreen(
  WidgetTester tester, {
  UpdateAvailableData? data,
  LoadStatus status = LoadStatus.loaded,
  bool blocksCheck = false,
  bool blocksUpdate = true,
  Size surface = const Size(390, 1400),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  // The view metrics, and not the binding's surface size, because the page
  // reads its width from MediaQuery to decide whether it is on a desktop
  // layout. The surface size alone would lay the page out narrow while still
  // telling it the window is 800pt wide.
  setTestSurface(tester, surface);

  final server = Server(
    id: '1',
    name: 'Home',
    connectionMethod: 'http',
    domain: '192.168.1.10',
    port: 3000,
    defaultServer: true,
    runningOnHa: false,
  );
  final api = UpdateApiStub(server: server)
    ..blocksCheck = blocksCheck
    ..blocksUpdate = blocksUpdate;

  final servers = ServersProvider()
    ..setSelectedServer(server)
    ..setApiClient2(api);
  final appConfig = AppConfigProvider(sharedPreferencesInstance: prefs);

  if (status == LoadStatus.loading) {
    servers.checkServerUpdatesAvailable(server: server);
  } else {
    if (data != null) servers.setUpdateAvailableData(data);
    servers.setUpdateAvailableLoadStatus(status, false);
  }
  addTearDown(servers.dispose);
  addTearDown(appConfig.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfigProvider>.value(value: appConfig),
        ChangeNotifierProvider<ServersProvider>.value(value: servers),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: globalNavigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        theme: appleLightTheme(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: ApplePalette.of(context).window,
            body: Center(
              child: AppleButton(
                label: 'open',
                onPressed: () => Navigator.push(
                  context,
                  CupertinoPageRoute<void>(builder: (_) => const UpdateScreen()),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await settleUpdates(tester);

  return UpdateHarness(api, servers);
}

/// Brings the page to rest without asking the framework to settle for it.
///
/// Two things on this page keep `pumpAndSettle` from ever returning: the
/// indeterminate spinner it draws while it waits, which animates for as long as
/// the wait lasts, and the changelog parse, which runs on isolates the test
/// clock cannot advance. So the frames are pumped by hand, and the real event
/// loop is lent to the isolates in rounds: the parse chains two of them and each
/// takes a round or two to come back.
Future<void> settleUpdates(WidgetTester tester) async {
  for (var frame = 0; frame < 6; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  for (var round = 0; round < 5; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The word the design layer paints for the value line of the status row.
String statusValue(WidgetTester tester) =>
    tester.widget<AppleListTile>(find.byType(AppleListTile).first).subtitle!;

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  tearDown(() => AppleToast.hide());

  testWidgets('the page is a screen of the design layer, not a Material bar',
      (tester) async {
    await pumpUpdateScreen(tester, data: updateFixture());

    expect(tester.takeException(), isNull);
    expect(find.byType(UpdateScreen), findsOneWidget);
    expect(find.byType(AppleScreen), findsOneWidget);
    for (final scaffold in tester.widgetList<Scaffold>(find.byType(Scaffold))) {
      expect(scaffold.appBar, isNull);
    }

    // The collapsing title carries the page name and its one-line meaning.
    expect(
      find.descendant(
        of: find.byType(AppleLargeTitle),
        matching: find.text(l.updates),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppleLargeTitle),
        matching: find.text(l.updatesDescription),
      ),
      findsOneWidget,
    );

    // Where the server stands is one row: the verdict and the release it is
    // about.
    expect(find.byType(AppleListSection), findsOneWidget);
    expect(find.widgetWithText(AppleListTile, l.updateAvailable), findsOneWidget);
    expect(statusValue(tester), '${l.newVersion}: v0.108.0');

    // The bar is the design layer's own: a large title on a blur, rather than
    // the Material app bar, the button that used to float over the text and the
    // Material spinner that used to fill it.
    expect(find.byType(AppleLargeTitle), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(Icons.download_rounded), findsNothing);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // A pushed route draws the back capsule of the design layer, and it pops.
    expect(find.byType(AppleBackButton), findsOneWidget);
    await tester.tap(find.byType(AppleBackButton));
    await settleUpdates(tester);
    expect(find.byType(UpdateScreen), findsNothing);
  });

  testWidgets('the check is on the bar and asks the server again',
      (tester) async {
    final h = await pumpUpdateScreen(tester, data: updateFixture());

    expect(h.api.checkCalls, 0);
    expect(find.widgetWithText(AppleListTile, l.updateAvailable), findsOneWidget);

    // The next release the server has just heard about.
    h.api.answer = versionAnswer(newVersion: 'v0.109.0', changelog: '# v1');
    await tester.tap(find.byTooltip(l.refresh));
    await settleUpdates(tester);

    expect(h.api.checkCalls, 1);
    expect(statusValue(tester), '${l.newVersion}: v0.109.0');

    // And so are the notes that came with them. The page arrived with no
    // changelog at all, so a parse that ran only on arrival would leave the card
    // waiting on notes this very check has already handed it.
    expect(find.text(l.loadingChangelog), findsNothing);
    expect(find.text('Changelog v0.109.0'), findsOneWidget);
    expect(find.text('v1', findRichText: true), findsOneWidget);
  });

  testWidgets('a check that never got an answer names itself and offers the retry',
      (tester) async {
    final h = await pumpUpdateScreen(tester, status: LoadStatus.error);

    expect(tester.takeException(), isNull);
    // Nothing on the page pulls, so the state has to carry the retry itself.
    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(find.text(l.unknownStatus), findsOneWidget);
    expect(find.text(l.serverInfoNotLoaded), findsOneWidget);
    expect(find.widgetWithText(AppleFormButton, l.checkUpdates), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.exclamationmark_triangle), findsOneWidget);
    // A server that refused to answer gets no verdict row.
    expect(find.byType(AppleListTile), findsNothing);

    h.api.succeeds = true;
    h.api.answer = versionAnswer(changelog: '# v1');
    await tester.tap(find.widgetWithText(AppleFormButton, l.checkUpdates));
    await settleUpdates(tester);

    expect(h.api.checkCalls, 1);
    expect(find.byType(AppleEmptyState), findsNothing);
    expect(find.widgetWithText(AppleListTile, l.updateAvailable), findsOneWidget);
  });

  testWidgets('a server that does not update itself says so instead of spinning',
      (tester) async {
    await pumpUpdateScreen(
      tester,
      data: updateFixture(canAutoupdate: false, disabled: true),
    );

    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(find.text(l.autoupdateUnavailable), findsOneWidget);
    expect(find.text(l.autoupdateUnavailableDescription), findsOneWidget);
    // The changelog spinner would have nothing to wait for, and there is no
    // update to request.
    expect(find.text(l.loadingChangelog), findsNothing);
    expect(find.byType(AppleLoading), findsNothing);
    expect(find.text(l.updateNow), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a server up to date names its installed version', (tester) async {
    await pumpUpdateScreen(
      tester,
      data: updateFixture(newVersion: 'v0.107.43', canAutoupdate: false),
    );

    expect(find.widgetWithText(AppleListTile, l.serverUpdated), findsOneWidget);
    expect(statusValue(tester), '${l.installedVersion}: v0.107.43');
    expect(find.byIcon(CupertinoIcons.checkmark_shield_fill), findsOneWidget);
    expect(find.text(l.updateNow), findsNothing);

    // With no answer from the release feed the page says what it is waiting on.
    expect(find.byType(AppleLoading), findsOneWidget);
    expect(find.text(l.loadingChangelog), findsOneWidget);
  });

  testWidgets('the release notes come as a card under their own heading',
      (tester) async {
    await pumpUpdateScreen(
      tester,
      data: updateFixture(changelog: '### Changes\n\n- fixed caching'),
    );

    expect(find.byType(AppleLoading), findsNothing);
    expect(find.text('Changelog v0.108.0'), findsOneWidget);
    expect(find.byType(AppleCard), findsOneWidget);
    // The card paints the parsed HTML, which arrives as rich text rather than
    // as a Text widget of its own.
    expect(find.text('fixed caching', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a check still running has no verdict to show', (tester) async {
    final h = await pumpUpdateScreen(
      tester,
      status: LoadStatus.loading,
      blocksCheck: true,
    );

    expect(find.text(l.checkingUpdates), findsOneWidget);
    expect(find.text(l.updateAvailable), findsNothing);
    expect(find.byType(AppleListTile), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsWidgets);
    // The version the last check left behind is not repeated as a promise.
    expect(find.text('${l.newVersion}: v0.108.0'), findsNothing);

    h.api.blocksCheck = false;
    h.api.checkGate.complete();
    h.api.answer = versionAnswer(changelog: '# v1');
    await settleUpdates(tester);

    expect(find.text(l.checkingUpdates), findsNothing);
    expect(find.widgetWithText(AppleListTile, l.updateAvailable), findsOneWidget);
    expect(statusValue(tester), '${l.newVersion}: v0.108.0');
  });

  testWidgets('the word on the bar requests the update once', (tester) async {
    final h = await pumpUpdateScreen(
      tester,
      data: updateFixture(changelog: '# v1'),
    );

    expect(find.text(l.updateNow), findsOneWidget);
    await tester.tap(find.text(l.updateNow));
    // The modal the page opens is held by a delay of its own.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(h.api.updateCalls, 1);
    expect(find.text(l.requestingUpdate), findsOneWidget);

    // The server answers by reporting itself at the new version already, which
    // is what stops the two second poll the page starts.
    h.api.answer = versionAnswer(
      currentVersion: 'v0.108.0',
      newVersion: 'v0.108.0',
      changelog: '# v1',
    );
    h.api.updateGate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(l.requestingUpdate), findsNothing);
    expect(find.text(l.requestStartUpdateSuccessful), findsOneWidget);
    // Nothing is offered twice while the server is busy.
    expect(h.servers.updatingServer, isTrue);
    expect(find.text(l.updateNow), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.servers.updatingServer, isFalse);

    await settleUpdates(tester);
    expect(statusValue(tester), '${l.newVersion}: v0.108.0');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a page pushed on a wide layout keeps its back capsule out',
      (tester) async {
    await pumpUpdateScreen(tester, data: updateFixture(), surface: const Size(1200, 1400));

    expect(find.byType(AppleBackButton), findsNothing);
    expect(find.byType(AppleScreen), findsOneWidget);
    expect(find.widgetWithText(AppleListTile, l.updateAvailable), findsOneWidget);
  });
}
