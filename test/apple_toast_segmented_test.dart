import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: globalNavigatorKey,
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

TextStyle _styleOf(WidgetTester tester, String label) =>
    DefaultTextStyle.of(tester.element(find.text(label))).style;

double _fontSizeOf(WidgetTester tester, String label) => _styleOf(tester, label).fontSize!;

Color _colorOf(WidgetTester tester, String label) => _styleOf(tester, label).color!;

void main() {
  late AppConfigProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    provider = AppConfigProvider(
      sharedPreferencesInstance: await SharedPreferences.getInstance(),
    );
  });

  // The pill is app-global state, so each test starts and ends with none.
  tearDown(() => AppleToast.hide());

  group('AppleSegmented', () {
    testWidgets('drags a single capsule instead of repainting each segment', (tester) async {
      final taps = <int>[];

      await _pump(
        tester,
        SizedBox(
          width: 300,
          child: AppleSegmented(
            labels: const ['24 小时', '7 天', '30 天'],
            selectedIndex: 0,
            onChanged: taps.add,
          ),
        ),
      );

      // 300 wide minus the 2px inset on both sides, split across three segments.
      final capsule = tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned));
      expect(find.byType(AnimatedPositioned), findsOneWidget);
      expect(capsule.width, closeTo(296 / 3, 0.001));
      expect(capsule.left, closeTo(0, 0.001));
      expect(capsule.curve, isA<Cubic>());

      await tester.tap(find.text('30 天'));
      await tester.pumpAndSettle();

      // The parent owns the selection, so the widget itself must not move.
      expect(taps, [2]);
      expect(
        tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned)).left,
        closeTo(0, 0.001),
      );
    });

    testWidgets('capsule follows the selected index', (tester) async {
      for (final index in [0, 1, 2]) {
        await _pump(
          tester,
          SizedBox(
            width: 300,
            child: AppleSegmented(
              labels: const ['a', 'b', 'c'],
              selectedIndex: index,
              onChanged: (_) {},
            ),
          ),
        );

        final capsule = tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned));
        expect(capsule.left, closeTo(index * 296 / 3, 0.001));
      }
    });

    testWidgets('large matches the prototype .seg.lg metrics', (tester) async {
      await _pump(
        tester,
        Column(
          children: [
            SizedBox(
              width: 300,
              child: AppleSegmented(
                labels: const ['small', 'a'],
                selectedIndex: 0,
                onChanged: (_) {},
              ),
            ),
            SizedBox(
              width: 300,
              child: AppleSegmented(
                labels: const ['large', 'b'],
                selectedIndex: 0,
                onChanged: (_) {},
                large: true,
              ),
            ),
          ],
        ),
      );

      expect(_fontSizeOf(tester, 'small'), 13);
      expect(_fontSizeOf(tester, 'a'), 13);
      expect(_fontSizeOf(tester, 'large'), 15);
      expect(_fontSizeOf(tester, 'b'), 15);

      // The prototype sizes the control from its label padding, so the large
      // variant is taller by the two extra pixels on each side.
      expect(
        tester.getSize(find.byType(AppleSegmented).at(1)).height,
        greaterThan(tester.getSize(find.byType(AppleSegmented).at(0)).height),
      );
      expect(tester.getSize(find.byType(AppleSegmented).at(0)).width, 300);
    });

    testWidgets('unselected labels are dimmed, selected is full strength', (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: 300,
          child: AppleSegmented(
            labels: const ['on', 'off'],
            selectedIndex: 0,
            onChanged: (_) {},
          ),
        ),
      );

      final selected = _colorOf(tester, 'on');
      final unselected = _colorOf(tester, 'off');

      expect(selected.a, closeTo(1.0, 0.001));
      expect(unselected.a, closeTo(0.75, 0.001));
      expect(unselected.withValues(alpha: 1), selected.withValues(alpha: 1));
    });
  });

  group('AppleToast', () {
    testWidgets('shows one pill and removes it when its duration expires', (tester) async {
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

      AppleToast.show(context, message: '防护已开启', accent: Colors.green);
      await tester.pump();
      expect(find.text('防护已开启'), findsOneWidget);

      // A second one replaces the first rather than stacking.
      AppleToast.show(context, message: '已复制到剪贴板', icon: Icons.copy_rounded);
      await tester.pump();
      expect(find.text('已复制到剪贴板'), findsOneWidget);
      expect(find.text('防护已开启'), findsNothing);
      expect(tester.widgetList<Icon>(find.byIcon(Icons.copy_rounded)).length, 1);

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('已复制到剪贴板'), findsNothing);
    });

    testWidgets('is inert so it never blocks the UI underneath', (tester) async {
      var tapped = 0;
      late BuildContext context;

      await _pump(
        tester,
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => tapped++,
          child: SizedBox.expand(
            child: Builder(
              builder: (ctx) {
                context = ctx;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      AppleToast.show(context, message: '列表已删除');
      await tester.pump();

      // The pill sits over the target, yet the page behind still takes the tap.
      await tester.tapAt(tester.getCenter(find.text('列表已删除')));
      expect(tapped, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('hide() clears it immediately', (tester) async {
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

      AppleToast.show(context, message: '临时', duration: const Duration(minutes: 5));
      await tester.pump();
      expect(find.text('临时'), findsOneWidget);

      AppleToast.hide();
      await tester.pump();
      expect(find.text('临时'), findsNothing);
    });
  });

  group('showSnackbar routing', () {
    testWidgets('uses the pill and never a Material snack bar', (tester) async {
      await _pump(tester, const SizedBox.shrink());

      showSnackbar(
        appConfigProvider: provider,
        label: '设备已添加',
        color: Colors.green,
      );
      await tester.pump();

      expect(find.text('设备已添加'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      AppleToast.hide();
      await tester.pumpAndSettle();
    });
  });
}
