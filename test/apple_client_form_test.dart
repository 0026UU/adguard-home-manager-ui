import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/screens/clients/client/client_screen.dart';
import 'package:adguard_home_manager/screens/clients/client/safe_search_modal.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

// The add/edit form of one device. Nothing here reaches a server: the entry
// handed to "save" is recorded, and the delete path is only opened as far as
// its confirmation.

Future<void> _pump(
  WidgetTester tester, {
  Client? client,
  bool fullScreen = true,
  required void Function(Client) onConfirm,
  Size surface = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final clients = ClientsProvider();
  addTearDown(clients.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<ClientsProvider>.value(
      value: clients,
      child: MaterialApp(
        theme: appleLightTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClientScreen(
          fullScreen: fullScreen,
          client: client,
          onConfirm: onConfirm,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _field(int index) => find.descendant(
      of: find.byType(AppleTextField).at(index),
      matching: find.byType(TextField),
    );

Client _stored({
  String name = 'Living Room',
  List<String> ids = const ['192.168.1.2'],
  bool useGlobalSettings = true,
  bool filteringEnabled = true,
  List<String> rules = const [],
}) => Client(
      name: name,
      ids: ids,
      tags: const [],
      upstreams: const [],
      rules: rules,
      filteringEnabled: filteringEnabled,
      parentalEnabled: false,
      safebrowsingEnabled: false,
      useGlobalBlockedServices: true,
      useGlobalSettings: useGlobalSettings,
      blockedServices: const [],
      safeSearch: null,
      ignoreQuerylog: null,
      ignoreStatistics: null,
      upstreamsCacheEnabled: null,
      upstreamsCacheSize: null,
      blockedServicesSchedule: null,
    );

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the add page is an Apple form and saves what was typed',
      (tester) async {
    final saved = <Client>[];
    await _pump(tester, onConfirm: saved.add);

    expect(find.byType(AppleScreen), findsOneWidget);
    expect(find.byType(AppleListSection), findsNWidgets(7));
    // The name, the one identifier it starts with and the cache size.
    expect(find.byType(AppleTextField), findsNWidgets(3));

    // Saving an empty form lists every reason instead of sending it.
    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(find.text(l.errors), findsOneWidget);
    expect(find.text(l.nameInvalid), findsOneWidget);
    expect(find.text(l.oneIdentifierRequired), findsOneWidget);

    await tester.enterText(_field(0), 'Living Room');
    await tester.enterText(_field(1), '192.168.1.50');
    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single.name, 'Living Room');
    expect(saved.single.ids, ['192.168.1.50']);
    expect(saved.single.useGlobalSettings, isTrue);
    expect(saved.single.filteringEnabled, isFalse);
    expect(find.text(l.errors), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing keeps the name read-only and prefills the form',
      (tester) async {
    final saved = <Client>[];
    await _pump(
      tester,
      client: _stored(ids: const ['192.168.1.2', 'AA:BB:CC:DD:EE:FF']),
      onConfirm: saved.add,
    );

    expect(tester.widgetList<AppleTextField>(find.byType(AppleTextField)).first.enabled,
        isFalse);
    // Name, two identifiers, cache size.
    expect(find.byType(AppleTextField), findsNWidgets(4));
    expect(
      tester.widget<TextField>(_field(1)).controller!.text,
      '192.168.1.2',
    );

    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();
    expect(saved.single.name, 'Living Room');
    expect(saved.single.ids, ['192.168.1.2', 'AA:BB:CC:DD:EE:FF']);
    expect(saved.single.filteringEnabled, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the global switch locks and unlocks the per-device settings',
      (tester) async {
    await _pump(tester, onConfirm: (_) {});

    bool switchEnabled(int index) => tester
        .widgetList<CupertinoSwitch>(find.byType(CupertinoSwitch))
        .elementAt(index)
        .onChanged !=
        null;

    // Filtering, safe browsing and parental follow the server for now.
    expect(switchEnabled(1), isFalse);
    expect(switchEnabled(2), isFalse);
    expect(switchEnabled(3), isFalse);

    final safeSearchRow = find.widgetWithText(AppleListTile, l.safeSearch);
    expect(tester.widget<AppleListTile>(safeSearchRow).onTap, isNull);

    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pumpAndSettle();
    expect(switchEnabled(1), isTrue);
    expect(tester.widget<AppleListTile>(safeSearchRow).onTap, isNotNull);

    await tester.tap(safeSearchRow);
    await tester.pumpAndSettle();
    expect(find.byType(SafeSearchModal), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(SafeSearchModal),
        matching: find.text(l.cancel),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SafeSearchModal), findsNothing);

    // Back to global clears the per-device draft again.
    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pumpAndSettle();
    expect(switchEnabled(1), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('identifiers and upstreams grow and shrink from their headers',
      (tester) async {
    await _pump(tester, onConfirm: (_) {});

    // The nav bar carries its own header actions, so the adds are looked up
    // inside the section they belong to: identifiers, then upstreams.
    final addIdentifier = find.descendant(
      of: find.byType(AppleListSection).at(1),
      matching: find.byType(AppleHeaderAction),
    );
    final addUpstream = find.descendant(
      of: find.byType(AppleListSection).at(5),
      matching: find.byType(AppleHeaderAction),
    );

    await tester.tap(addIdentifier);
    await tester.pumpAndSettle();
    expect(find.byType(AppleTextField), findsNWidgets(4));

    await tester.tap(find.byIcon(CupertinoIcons.trash).first);
    await tester.pumpAndSettle();
    expect(find.byType(AppleTextField), findsNWidgets(3));
    expect(find.text(l.noIdentifiers), findsNothing);

    await tester.tap(find.byIcon(CupertinoIcons.trash).first);
    await tester.pumpAndSettle();
    expect(find.byType(AppleTextField), findsNWidgets(2));
    expect(find.text(l.noIdentifiers), findsOneWidget);

    // The upstream group starts below the fold on a phone.
    await tester.dragFrom(const Offset(195, 700), const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.tap(addUpstream);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppleTextField, l.serverAddress), findsOneWidget);
    expect(find.text(l.noUpstreamServers), findsNothing);

    await tester.tap(find.byIcon(CupertinoIcons.trash).last);
    await tester.pumpAndSettle();
    expect(find.text(l.noUpstreamServers), findsOneWidget);
    expect(find.text(l.willBeUsedGeneralServers), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the wide layout is a card with its actions in the footer',
      (tester) async {
    final saved = <Client>[];
    await _pump(
      tester,
      fullScreen: false,
      surface: const Size(900, 900),
      onConfirm: saved.add,
    );

    expect(find.byType(AppleFormModal), findsOneWidget);
    expect(find.byType(AppleFormFooter), findsOneWidget);
    expect(find.byTooltip(l.close), findsOneWidget);
    expect(find.byType(AppleScreen), findsNothing);

    await tester.enterText(_field(0), 'Studio');
    await tester.enterText(_field(1), '10.0.0.7');
    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();
    expect(saved.single.name, 'Studio');
    expect(saved.single.ids, ['10.0.0.7']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting asks before anything is removed', (tester) async {
    await _pump(tester, client: _stored(), onConfirm: (_) {});

    await tester.tap(find.text(l.delete));
    await tester.pumpAndSettle();
    expect(find.byType(AppleAlertDialog), findsOneWidget);
    expect(find.text(l.removeClient), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AppleAlertDialog),
        matching: find.text(l.cancel),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppleAlertDialog), findsNothing);
    expect(find.byType(ClientScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
