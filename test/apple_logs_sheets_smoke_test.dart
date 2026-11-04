import 'package:flutter/cupertino.dart';
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
import 'package:adguard_home_manager/screens/logs/filters/added_client_id_selection_modal.dart';
import 'package:adguard_home_manager/screens/logs/filters/clients_modal.dart';
import 'package:adguard_home_manager/screens/logs/filters/filter_status_modal.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/custom_checkbox_list_tile.dart';
import 'package:adguard_home_manager/widgets/custom_list_tile.dart';
import 'package:adguard_home_manager/widgets/custom_radio.dart';

AutoClient _auto(int index) => AutoClient(
      whoisInfo: WhoisInfo(country: 'IT', orgname: 'Example'),
      name: index.isEven ? 'device-$index' : null,
      source: 'rdns',
      ip: '192.168.1.$index',
    );

Client _added(int index) => Client(
      name: 'client-$index',
      blockedServices: const [],
      ids: ['10.0.0.$index', 'aa:bb:cc:dd:ee:ff'],
      tags: const [],
      upstreams: const [],
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

Clients _clientsData() => Clients(
      clients: [_added(0)],
      autoClients: [_auto(1), _auto(2)],
      supportedTags: const [],
    );

/// Choosing a log filter always refetches the logs, which needs a live server.
/// Only the widget wiring is under test here, so the network call is dropped.
class _OfflineLogs extends LogsProvider {
  @override
  Future<bool> filterLogs() async => true;
}

/// The providers the log filters hand to these sheets. `serverStatus` stays
/// empty on purpose: the sheets read it through a `try/catch` and fall back to
/// the raw identifiers.
class _Harness {
  final LogsProvider logs = _OfflineLogs();
  final ClientsProvider clients = ClientsProvider();
  final StatusProvider status = StatusProvider();

  _Harness();

  _Harness.withClients() {
    clients.setClientsLoadStatus(LoadStatus.loaded, false);
    clients.setClientsData(_clientsData(), false);
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
Future<void> _show(
  WidgetTester tester,
  _Harness harness,
  Size surface,
  Widget modal,
) async {
  SharedPreferences.setMockInitialValues({});

  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MultiProvider(
      providers: harness.providers,
      child: MaterialApp(
        theme: appleLightTheme(),
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

/// The radios of the status picker, in the order the sheet lists them.
List<AnimatedContainer> _statusDots(WidgetTester tester) => tester
    .widgetList<AnimatedContainer>(find.descendant(
      of: find.byType(CustomRadio),
      matching: find.byType(AnimatedContainer),
    ))
    .toList();

/// A drawn radio dot is 12 logical pixels wide; an empty one is 0.
bool _isFilled(AnimatedContainer dot) => dot.constraints!.maxWidth == 12;

const int _allRow = 0;
const int _blockedRow = 4;

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the response status picker is one radio per status',
      (tester) async {
    final harness = _Harness();

    await _show(
      tester,
      harness,
      const Size(900, 900),
      FilterStatusModal(dialog: true),
    );

    expect(find.byType(AppleFormModal), findsOneWidget);
    expect(find.text(l.responseStatus), findsOneWidget);
    expect(find.byType(AppleListTile), findsNWidgets(8));
    expect(find.byType(CustomRadio), findsNWidgets(8));
    expect(_statusDots(tester).where(_isFilled), hasLength(1));

    await tester.tap(find.text(l.blocked));
    await tester.pumpAndSettle();

    expect(harness.logs.selectedResultStatus, 'blocked');
    final dots = _statusDots(tester);
    expect(dots.where(_isFilled), hasLength(1));
    expect(_isFilled(dots[_blockedRow]), isTrue);
    expect(_isFilled(dots[_allRow]), isFalse);

    await tester.tap(find.text(l.close));
    await tester.pumpAndSettle();

    expect(find.byType(FilterStatusModal), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same picker drops the close button as a sheet',
      (tester) async {
    final harness = _Harness();

    await _show(
      tester,
      harness,
      const Size(420, 800),
      FilterStatusModal(dialog: false),
    );

    expect(find.byType(AppleListTile), findsNWidgets(8));
    expect(find.text(l.blockedSafeSearchRow), findsOneWidget);
    expect(find.text(l.close), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the clients sheet ticks active clients into the log filter',
      (tester) async {
    final harness = _Harness.withClients();

    await _show(
      tester,
      harness,
      const Size(900, 900),
      ClientsModal(dialog: true),
    );

    expect(find.byType(AppleFormModal), findsOneWidget);
    expect(find.byType(AppleSearchField), findsOneWidget);
    expect(find.byType(AppleSegmented), findsOneWidget);
    expect(find.text(l.selectClientsFiltersInfo), findsOneWidget);
    // Two auto clients, each with its address as the title.
    expect(find.byType(CustomCheckboxListTile), findsNWidgets(2));
    expect(find.text('192.168.1.1'), findsOneWidget);

    await tester.tap(find.text('192.168.1.2'));
    await tester.pumpAndSettle();

    expect(harness.logs.selectedClients, ['192.168.1.2']);
    expect(
        tester
            .widget<CupertinoCheckbox>(find.byType(CupertinoCheckbox).at(1))
            .value,
        true);

    await tester.tap(find.text('192.168.1.2'));
    await tester.pumpAndSettle();

    expect(harness.logs.selectedClients, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('added clients go through the identifier picker', (tester) async {
    final harness = _Harness.withClients();

    await _show(
      tester,
      harness,
      const Size(420, 800),
      ClientsModal(dialog: false),
    );

    await tester.tap(find.text(l.added));
    await tester.pumpAndSettle();

    // The added tab has no checkboxes; it asks which id to filter by.
    expect(find.byType(CustomCheckboxListTile), findsNothing);
    expect(find.byType(CustomListTile), findsNWidgets(1));
    expect(find.text('10.0.0.0, aa:bb:cc:dd:ee:ff'), findsOneWidget);

    await tester.tap(find.text(l.select));
    await tester.pumpAndSettle();

    expect(find.byType(AddedClientIdSelectionModal), findsOneWidget);
    expect(find.text(l.selectIdToFilter), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();

    expect(find.byType(AddedClientIdSelectionModal), findsNothing);
    expect(find.byType(ClientsModal), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
