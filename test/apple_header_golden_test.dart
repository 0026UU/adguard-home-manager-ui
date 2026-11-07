import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'surface.dart';

// The collapsing header and the inset-grouped list card are both paint-level
// behaviour: a widget test that only looks for the title text passes even when
// the title is not drawn at all. These goldens are rendered by the test
// framework, so the header can be inspected as pixels.
//
// Regenerate with: flutter test --update-goldens test/apple_header_golden_test.dart

Future<void> _pump(WidgetTester tester, Widget home) async {
  setTestSurface(tester, const Size(390, 700));

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appleLightTheme(),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

Widget _screen({Widget? header}) => AppleScreen(
      title: 'Settings',
      header: header,
      slivers: [
        SliverToBoxAdapter(
          child: AppleListSection(
            title: 'SERVER',
            children: [
              AppleListTile(title: 'One', icon: Icons.settings),
              AppleListTile(title: 'Two', icon: Icons.person),
              AppleListTile(title: 'Three', icon: Icons.lock),
              AppleListTile(title: 'Four', icon: Icons.wifi),
              AppleListTile(title: 'Five', icon: Icons.timer),
              AppleListTile(title: 'Six', icon: Icons.gps_fixed),
              AppleListTile(title: 'Seven', icon: Icons.gps_fixed),
              AppleListTile(title: 'Eight', icon: Icons.gps_fixed),
              AppleListTile(title: 'Nine', icon: Icons.gps_fixed),
              AppleListTile(title: 'Ten', icon: Icons.gps_fixed),
              AppleListTile(title: 'Eleven', icon: Icons.gps_fixed),
              AppleListTile(title: 'Twelve', icon: Icons.gps_fixed),
            ],
          ),
        ),
      ],
    );

Widget _cardList() => Scaffold(
      backgroundColor: ApplePalette(Brightness.light).window,
      body: Builder(
        builder: (context) => CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
            ...AppleListCard.slivers(
              context,
              itemsCount: 6,
              row: (index) => AppleListTile(
                title: 'Row ${index + 1}',
                subtitle: 'Detail',
                icon: Icons.devices_other,
                iconColor: ApplePalette(Brightness.light).tint,
              ),
            ),
          ],
        ),
      ),
    );

void main() {
  testWidgets('the large title is painted in the expanded header',
      (tester) async {
    await _pump(tester, _screen());

    final title = find.descendant(
      of: find.byType(AppleLargeTitle),
      matching: find.text('Settings'),
    );
    expect(title, findsOneWidget);

    final style = tester.widget<Text>(title).style!;
    expect(style.fontSize, 34);
    expect(style.fontWeight, FontWeight.w600);

    // It has to sit inside the bar, not under the list.
    final bar = tester.getRect(find.byType(AppleLargeTitle));
    final text = tester.getRect(title);
    expect(text.bottom, lessThanOrEqualTo(bar.bottom + 0.5));
    expect(text.height, greaterThan(0));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/header_expanded.png'),
    );
  });

  testWidgets('the expanded bar is only as tall as the title needs',
      (tester) async {
    await _pump(tester, _screen());

    // Collapsed band, the title block and a breath: nothing more, so no empty
    // band is left between the bar actions and the large title.
    final bar = tester.getRect(find.byType(AppleLargeTitle));
    expect(bar.height, closeTo(64 + 34 * 1.15 + 10 + 6, 0.51));

    final title = tester.getRect(find.descendant(
      of: find.byType(AppleLargeTitle),
      matching: find.text('Settings'),
    ));
    expect(title.top - 64, lessThan(16),
        reason: 'the large title sits right under the collapsed band');

    // A pinned header band gets its own room back instead of clipping the
    // title away when expanded.
    await _pump(tester, _screen(header: const Placeholder()));
    final withHeader = tester.getRect(find.byType(AppleLargeTitle));
    expect(withHeader.height, closeTo(64 + 44 + 34 * 1.15 + 4 + 6, 0.51));
    final titled = tester.getRect(find.descendant(
      of: find.byType(AppleLargeTitle),
      matching: find.text('Settings'),
    ));
    expect(titled.top, greaterThanOrEqualTo(64 - 0.5));
    expect(titled.bottom, lessThanOrEqualTo(withHeader.bottom - 44 + 0.5));
  });

  testWidgets('the header collapses to the inline title', (tester) async {
    await _pump(tester, _screen());

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -220));
    await tester.pumpAndSettle();

    // The bar is back to its collapsed height and the 17pt inline title has
    // taken over from the large one.
    final bar = tester.getRect(find.byType(AppleLargeTitle));
    expect(bar.height, lessThan(100));

    // The 17pt title in the toolbar fades in; the large one is clipped away by
    // the bar. Only the toolbar copy is wrapped in an AnimatedOpacity.
    final inline = find.ancestor(
      of: find.descendant(
          of: find.byType(AppBar), matching: find.text('Settings')),
      matching: find.byType(AnimatedOpacity),
    );
    expect(inline, findsOneWidget);
    expect(tester.widget<AnimatedOpacity>(inline).opacity, 1);

    // The collapsing area shrinks to nothing, so the large title is clipped
    // and cannot be painted over the inline title. The inner ClipRect is the
    // one AppleLargeTitle puts around the title.
    final large = find.descendant(
      of: find.byType(AppleLargeTitle),
      matching: find.text('Settings'),
    );
    final clips = find.descendant(
      of: find.byType(AppleLargeTitle),
      matching: find.byType(ClipRect),
    );
    expect(tester.getSize(clips.last).height, 0);
    expect(tester.getRect(large).height, greaterThan(0));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/header_collapsed.png'),
    );
  });

  testWidgets('a pinned row under the title keeps the title above it',
      (tester) async {
    await _pump(
      tester,
      _screen(
        header: AppleSegmented(
          labels: const ['Allow', 'Block'],
          selectedIndex: 0,
          onChanged: (_) {},
        ),
      ),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/header_with_segment.png'),
    );
  });

  testWidgets('the overview hero and statistics grid draw as cards',
      (tester) async {
    await _pump(
      tester,
      Scaffold(
        backgroundColor: ApplePalette(Brightness.light).window,
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: AppleHero(
                active: true,
                icon: Icons.shield,
                title: 'Protection enabled',
                description:
                    'Blocking ads and trackers for 128 devices\n'
                    '5,921 / 18,432 queries blocked',
                trailing: SizedBox(width: 58, height: 58),
                actions: [
                  AppleButton.secondary(label: 'Manage'),
                  AppleButton(label: 'Logs'),
                ],
              ),
            ),
            const AppleStatGrid(
              tiles: [
                AppleStatTile(
                  label: 'Queries',
                  value: '18,432',
                  sparkline: AppleSparkline(
                    values: [12, 18, 9, 24, 20, 31, 27],
                    color: Color(0xFF0A84FF),
                    width: 74,
                    height: 28,
                  ),
                ),
                AppleStatTile(
                  label: 'Blocked',
                  value: '5,921',
                  caption: '32.1%',
                ),
                AppleStatTile(
                  label: 'Elapsed time',
                  value: '24.6',
                  unit: 'ms',
                ),
                AppleStatTile(
                  label: 'Rules',
                  value: '312,547',
                  sparkline: AppleSparkline(
                    values: [30, 12, 22, 8, 26, 19, 24],
                    color: Color(0xFFFF9F0A),
                    width: 74,
                    height: 28,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/overview_hero.png'),
    );
  });

  testWidgets('a scrolling list reads as one inset-grouped card',
      (tester) async {
    await _pump(tester, _cardList());

    final caps = find.byType(AppleCardCap);
    expect(caps, findsNWidgets(2));
    expect(tester.getSize(caps.first).height, 12);

    // The rows are inset 16pt from the window edge, like the prototype.
    final row = find.widgetWithText(AppleListTile, 'Row 1');
    expect(tester.getTopLeft(row).dx, closeTo(16, 0.5));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/list_card.png'),
    );
  });
}
