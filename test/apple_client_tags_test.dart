import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/screens/clients/client/client_screen_functions.dart';
import 'package:adguard_home_manager/screens/clients/client/tags_modal.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

const _catalog = ['device_laptop', 'os_macos', 'user_admin'];
const _openKey = ValueKey('open-tags');

class _Harness {
  final rootNavigator = GlobalKey<NavigatorState>();
  final results = <List<String>>[];
  late ClientsProvider clients;
}

Future<_Harness> _openTags(
  WidgetTester tester, {
  required List<String> selected,
  List<String> catalog = _catalog,
  Brightness brightness = Brightness.light,
  Size surface = const Size(390, 844),
  double textScale = 1,
  double bottomInset = 0,
  bool nestedNavigator = false,
  ValueChanged<List<String>>? onSelected,
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final harness = _Harness();
  harness.clients = ClientsProvider()
    ..setClientsData(
      Clients(clients: [], autoClients: [], supportedTags: catalog),
      false,
    );
  addTearDown(harness.clients.dispose);

  final host = Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: AppleButton(
          key: _openKey,
          label: 'Open tags',
          onPressed: () => openTagsModal(
            context: context,
            selectedTags: selected,
            onSelectedTags: (tags) {
              // Keep the actual callback value, not a copy that hides aliasing.
              harness.results.add(tags);
              onSelected?.call(tags);
            },
          ),
        ),
      ),
    ),
  );

  await tester.pumpWidget(
    ChangeNotifierProvider<ClientsProvider>.value(
      value: harness.clients,
      child: MaterialApp(
        navigatorKey: harness.rootNavigator,
        theme: brightness == Brightness.dark
            ? appleDarkTheme()
            : appleLightTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            padding: EdgeInsets.only(bottom: bottomInset),
            viewPadding: EdgeInsets.only(bottom: bottomInset),
          ),
          child: child!,
        ),
        home: nestedNavigator
            ? Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => host,
                ),
              )
            : host,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _reopen(tester);
  return harness;
}

Future<void> _reopen(WidgetTester tester) async {
  await tester.tap(find.byKey(_openKey));
  await tester.pumpAndSettle();
  expect(find.byType(TagsModal), findsOneWidget);
  expect(tester.takeException(), isNull);
}

Finder _row(String tag) => find.widgetWithText(AppleListTile, tag);

void _expectChecked(WidgetTester tester, String tag, bool checked) {
  expect(
    find.descendant(
      of: _row(tag),
      matching: find.byIcon(CupertinoIcons.checkmark),
    ),
    checked ? findsOneWidget : findsNothing,
  );
  final semantics = tester.widget<Semantics>(
    find
        .ancestor(
          of: _row(tag),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.checked != null,
          ),
        )
        .first,
  );
  expect(semantics.properties.checked, checked);
}

Future<void> _toggle(WidgetTester tester, String tag) async {
  await tester.tap(_row(tag));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  late AppLocalizations l;
  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('real opener uses the supported catalog and Apple sheet chrome',
      (tester) async {
    final harness = await _openTags(tester, selected: ['device_laptop']);
    expect(find.byType(AppleSheet), findsOneWidget);
    expect(find.byType(AppleListSection), findsOneWidget);
    expect(find.byType(AppleFormFooter), findsOneWidget);
    expect(find.text(l.tags), findsOneWidget);
    expect(find.byTooltip(l.close), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(
      tester
          .widgetList<AppleListTile>(find.byType(AppleListTile))
          .map((row) => row.title),
      harness.clients.clients!.supportedTags,
    );
    final route = ModalRoute.of(tester.element(find.byType(TagsModal)))!
        as ModalBottomSheetRoute<void>;
    expect(route.isScrollControlled, isTrue);
    expect(route.backgroundColor, Colors.transparent);
    expect(route.barrierColor, const Color(0x66000000));
    _expectChecked(tester, 'device_laptop', true);
    _expectChecked(tester, 'os_macos', false);
    expect(harness.results, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final dismissal in ['cancel', 'close', 'barrier', 'back', 'drag']) {
    testWidgets('$dismissal discards additions and removals without a callback',
        (tester) async {
      final selected = ['device_laptop'];
      final harness = await _openTags(tester, selected: selected);
      await _toggle(tester, 'os_macos');
      await _toggle(tester, 'device_laptop');
      _expectChecked(tester, 'device_laptop', false);
      _expectChecked(tester, 'os_macos', true);
      expect(selected, ['device_laptop']);
      expect(harness.results, isEmpty);

      if (dismissal == 'cancel') {
        await tester.tap(find.text(l.cancel));
      } else if (dismissal == 'close') {
        await tester.tap(find.byTooltip(l.close));
      } else if (dismissal == 'barrier') {
        final top = tester.getTopLeft(find.byType(AppleSheet)).dy;
        expect(top, greaterThan(1));
        await tester.tapAt(Offset(10, top / 2));
      } else if (dismissal == 'back') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.fling(find.text(l.tags), const Offset(0, 600), 1500);
      }
      await tester.pumpAndSettle();
      expect(find.byType(TagsModal), findsNothing);
      expect(selected, ['device_laptop']);
      expect(harness.results, isEmpty);
      expect(tester.takeException(), isNull);

      await _reopen(tester);
      _expectChecked(tester, 'device_laptop', true);
      _expectChecked(tester, 'os_macos', false);
    });
  }

  testWidgets('adding and removing commits only the final selection once',
      (tester) async {
    final selected = ['device_laptop'];
    final harness = await _openTags(tester, selected: selected);
    await _toggle(tester, 'os_macos');
    await _toggle(tester, 'os_macos');
    await _toggle(tester, 'os_macos');
    await _toggle(tester, 'device_laptop');
    expect(selected, ['device_laptop']);
    expect(harness.results, isEmpty);

    final confirm = tester
        .widget<AppleFormFooter>(
          find.byType(AppleFormFooter),
        )
        .onConfirm!;
    await tester.tap(find.text(l.confirm));
    // A second activation during the route's exit must not notify or pop again.
    confirm();
    await tester.pumpAndSettle();
    expect(harness.results, [
      <String>['os_macos']
    ]);
    expect(selected, ['device_laptop']);
    expect(find.byType(TagsModal), findsNothing);
    expect(find.byKey(_openKey).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing the last tag confirms an empty list to clear tags',
      (tester) async {
    final selected = ['device_laptop'];
    final harness = await _openTags(tester, selected: selected);
    await _toggle(tester, 'device_laptop');
    expect(
        tester
            .widget<AppleFormFooter>(find.byType(AppleFormFooter))
            .confirmEnabled,
        isTrue);
    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();
    expect(harness.results, [<String>[]]);
    expect(identical(harness.results.single, selected), isFalse);
    expect(selected, ['device_laptop']);
    expect(find.byType(TagsModal), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty catalog has a localized empty state and can confirm',
      (tester) async {
    final selected = <String>[];
    final catalog = <String>[];
    final harness = await _openTags(
      tester,
      selected: selected,
      catalog: catalog,
    );
    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(find.text(l.noItems), findsOneWidget);
    expect(find.byType(AppleListTile), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();
    expect(harness.results, [<String>[]]);
    expect(identical(harness.results.single, selected), isFalse);
    expect(identical(harness.results.single, catalog), isFalse);
    expect(find.byType(TagsModal), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmodifiable input and catalog support edits without mutation',
      (tester) async {
    final selected = List<String>.unmodifiable(['device_laptop']);
    final catalog = List<String>.unmodifiable(_catalog);
    final harness = await _openTags(
      tester,
      selected: selected,
      catalog: catalog,
    );
    await _toggle(tester, 'os_macos');
    await _toggle(tester, 'device_laptop');
    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();
    expect(harness.results, [
      <String>['os_macos']
    ]);
    expect(selected, ['device_laptop']);
    expect(catalog, _catalog);
    expect(tester.takeException(), isNull);
  });

  testWidgets('input, draft and confirmed output never alias each other',
      (tester) async {
    final selected = ['device_laptop'];
    final catalog = List<String>.of(_catalog);
    final harness = await _openTags(
      tester,
      selected: selected,
      catalog: catalog,
      onSelected: (tags) => tags.add('user_admin'),
    );
    // Mutating the caller after opening must not change the draft either.
    selected.clear();
    await _toggle(tester, 'os_macos');
    _expectChecked(tester, 'device_laptop', true);
    await tester.tap(find.text(l.confirm));
    await tester.pump();
    // The callback mutates its result while the sheet is animating out. The
    // rebuilt draft must not gain that tag through a shared output list.
    _expectChecked(tester, 'user_admin', false);
    expect(harness.results.single, ['device_laptop', 'os_macos', 'user_admin']);
    expect(identical(harness.results.single, selected), isFalse);
    expect(identical(harness.results.single, catalog), isFalse);
    expect(selected, isEmpty);
    expect(catalog, _catalog);
    await tester.pumpAndSettle();

    await _reopen(tester);
    _expectChecked(tester, 'device_laptop', false);
    _expectChecked(tester, 'os_macos', false);
    await _toggle(tester, 'device_laptop');
    expect(harness.results.single, ['device_laptop', 'os_macos', 'user_admin']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unchanged confirmation still returns a fresh independent list',
      (tester) async {
    final selected = ['device_laptop'];
    final harness = await _openTags(tester, selected: selected);
    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();
    expect(harness.results.single, selected);
    expect(identical(harness.results.single, selected), isFalse);
    harness.results.single.add('os_macos');
    expect(selected, ['device_laptop']);
    selected.clear();
    expect(harness.results.single, ['device_laptop', 'os_macos']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nested navigator still opens on root and preserves the host',
      (tester) async {
    final harness = await _openTags(
      tester,
      selected: [],
      nestedNavigator: true,
    );
    final route = ModalRoute.of(tester.element(find.byType(TagsModal)))!;
    expect(route.navigator, same(harness.rootNavigator.currentState));
    await _toggle(tester, 'os_macos');
    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();
    expect(harness.results, [
      <String>['os_macos']
    ]);
    expect(find.byKey(_openKey).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets(
          'long tags scroll at 320x568, $brightness, text scale $textScale',
          (tester) async {
        final catalog = List<String>.generate(
          24,
          (i) => 'device_${i}_a_very_long_supported_tag_with_no_spaces_' * 2,
        );
        final selected = <String>[];
        final harness = await _openTags(
          tester,
          selected: selected,
          catalog: catalog,
          brightness: brightness,
          surface: const Size(320, 568),
          textScale: textScale,
          bottomInset: 34,
        );
        expect(find.text(l.confirm).hitTestable(), findsOneWidget);
        expect(find.text(l.cancel).hitTestable(), findsOneWidget);
        expect(tester.getBottomRight(find.byType(AppleFormFooter)).dy,
            lessThanOrEqualTo(568 - 34));
        expect(_row(catalog.last).hitTestable(), findsNothing);
        final scrollable = find.descendant(
          of: find.byType(AppleSheet),
          matching: find.byType(ListView),
        );
        for (var i = 0;
            i < 40 && _row(catalog.last).hitTestable().evaluate().isEmpty;
            i++) {
          await tester.drag(scrollable, const Offset(0, -220));
          await tester.pumpAndSettle();
          // Do not drain or suppress layout errors: every frame must be clean.
          expect(tester.takeException(), isNull);
        }
        expect(_row(catalog.last).hitTestable(), findsOneWidget);
        await _toggle(tester, catalog.last);
        _expectChecked(tester, catalog.last, true);
        expect(selected, isEmpty);
        expect(find.text(l.confirm).hitTestable(), findsOneWidget);
        expect(find.text(l.cancel).hitTestable(), findsOneWidget);
        expect(find.byTooltip(l.close).hitTestable(), findsOneWidget);
        await tester.tap(find.text(l.confirm));
        await tester.pumpAndSettle();
        expect(harness.results, [
          <String>[catalog.last]
        ]);
        expect(find.byType(TagsModal), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
