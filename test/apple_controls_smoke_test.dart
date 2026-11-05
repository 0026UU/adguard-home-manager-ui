import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/confirm_action_modal.dart';
import 'package:adguard_home_manager/widgets/custom_checkbox_list_tile.dart';
import 'package:adguard_home_manager/widgets/custom_radio.dart';
import 'package:adguard_home_manager/widgets/custom_radio_list_tile.dart';
import 'package:adguard_home_manager/widgets/list_bottom_sheet.dart';
import 'package:adguard_home_manager/widgets/master_switch.dart';
import 'package:adguard_home_manager/widgets/option_box.dart';
import 'package:adguard_home_manager/widgets/process_dialog.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(
    MaterialApp(
      theme: appleLightTheme(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: home),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('list bottom sheet renders as an iOS sheet with a titled header', (tester) async {
    late BuildContext context;

    await _pump(
      tester,
      Builder(
        builder: (ctx) {
          context = ctx;
          return const SizedBox.shrink();
        },
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ListBottomSheet(
        icon: CupertinoIcons.lock,
        title: 'Privacy',
        children: const [
          AppleListTile(title: 'Mode', showChevron: false),
          AppleListTile(title: 'Duration', showChevron: false),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.lock), findsOneWidget);
    expect(find.text('Mode'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
  });

  testWidgets('a radio row selects by tapping anywhere on the row', (tester) async {
    var group = 'refused';

    await _pump(
      tester,
      Material(
        child: Column(
          children: [
            CustomRadioListTile(
              groupValue: group,
              value: 'default',
              title: 'Default',
              subtitle: 'Block using NXDOMAIN or REFUSED',
              onChanged: (value) => group = value,
            ),
            CustomRadioListTile(
              groupValue: group,
              value: 'refused',
              title: 'REFUSED',
              onChanged: (value) => group = value,
            ),
          ],
        ),
      ),
    );

    expect(find.byType(CustomRadio), findsNWidgets(2));
    expect(find.byType(AppleListTile), findsNWidgets(2));

    await tester.tap(find.text('Default'));
    await tester.pumpAndSettle();

    expect(group, 'default');
    expect(tester.takeException(), isNull);
  });

  testWidgets('only the selected radio keeps a filled dot', (tester) async {
    await _pump(
      tester,
      const Material(
        child: Row(
          children: [
            CustomRadio(value: 1, groupValue: 1),
            CustomRadio(value: 0, groupValue: 1),
          ],
        ),
      ),
    );

    final dots = tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    ).toList();

    expect(dots, hasLength(2));
    expect(dots[0].constraints!.maxWidth, 12);
    expect(dots[1].constraints!.maxWidth, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkbox rows toggle from the row and stay quiet when disabled', (tester) async {
    var value = false;
    var locked = false;

    await _pump(
      tester,
      Material(
        child: Column(
          children: [
            CustomCheckboxListTile(
              value: value,
              title: 'Safebrowsing',
              onChanged: (next) => value = next,
            ),
            CustomCheckboxListTile(
              value: locked,
              disabled: true,
              title: 'Family protection',
              onChanged: (next) => locked = next,
            ),
          ],
        ),
      ),
    );

    expect(find.byType(CupertinoCheckbox), findsNWidgets(2));

    await tester.tap(find.text('Safebrowsing'));
    await tester.pumpAndSettle();
    expect(value, isTrue);

    await tester.tap(find.text('Family protection'));
    await tester.pumpAndSettle();
    expect(locked, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the master switch gates its group with an iOS control', (tester) async {
    var value = false;

    await _pump(
      tester,
      Material(
        child: MasterSwitch(
          label: 'Query logging',
          value: value,
          onChange: (next) => value = next,
        ),
      ),
    );

    expect(find.byType(AppleListSection), findsOneWidget);
    expect(find.byType(CupertinoSwitch), findsOneWidget);

    await tester.tap(find.text('Query logging'));
    await tester.pumpAndSettle();

    expect(value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('option boxes are tinted pills that report their value', (tester) async {
    var picked = 'week';

    await _pump(
      tester,
      Material(
        child: Column(
          children: [
            OptionBox(
              optionsValue: picked,
              itemValue: 'day',
              label: 'Day',
              onTap: (value) => picked = value,
            ),
            OptionBox(
              optionsValue: picked,
              itemValue: 'week',
              label: 'Week',
              onTap: (value) => picked = value,
            ),
          ],
        ),
      ),
    );

    final p = ApplePalette.of(tester.element(find.text('Day')));
    Color fillOf(String label) {
      final w = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return (w.decoration as BoxDecoration).color!;
    }

    expect(fillOf('Week'), p.tint);
    expect(fillOf('Day'), isNot(p.tint));

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();

    expect(picked, 'day');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the confirm alert runs the action and dismisses itself', (tester) async {
    var confirmed = false;
    late BuildContext context;

    await _pump(
      tester,
      Builder(
        builder: (ctx) {
          context = ctx;
          return const SizedBox.shrink();
        },
      ),
    );

    showDialog(
      context: context,
      builder: (_) => ConfirmActionModal(
        title: 'Restore leases',
        message: 'This restores the leases file from the database',
        onConfirm: () => confirmed = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppleAlertDialog), findsOneWidget);
    expect(find.text('Restore leases'), findsOneWidget);
    expect(find.text(l.cancel), findsOneWidget);
    expect(find.text(l.confirm), findsOneWidget);

    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(find.byType(AppleAlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the processing dialog blocks dismissal', (tester) async {
    late BuildContext context;

    await _pump(
      tester,
      Builder(
        builder: (ctx) {
          context = ctx;
          return const SizedBox.shrink();
        },
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ProcessDialog(message: 'Loading…'),
    );
    // The Cupertino spinner never settles, so pump fixed frames here.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Loading…'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    expect(find.text('Loading…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
