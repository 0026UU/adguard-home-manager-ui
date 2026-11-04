import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

// The collapsing header and the inset-grouped list card are both paint-level
// behaviour: a widget test that only looks for the title text passes even when
// the title is not drawn at all. These goldens are rendered by the test
// framework, so the header can be inspected as pixels.
//
// Regenerate with: flutter test --update-goldens test/apple_header_golden_test.dart

Future<void> _pump(WidgetTester tester, Widget home) async {
  await tester.binding.setSurfaceSize(const Size(390, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));

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
    expect(style.fontWeight, FontWeight.w800);

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

    // The collapsing area shrinks to nothing, so the large title loses all of
    // its height and cannot be painted over the inline title.
    final large = find.descendant(
      of: find.byType(AppleLargeTitle),
      matching: find.text('Settings'),
    );
    expect(tester.getRect(large).height, 0);

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

  testWidgets('a scrolling list reads as one inset-grouped card',
      (tester) async {
    await _pump(tester, _cardList());

    final caps = find.byType(AppleCardCap);
    expect(caps, findsNWidgets(2));
    expect(tester.getSize(caps.first).height, 10);

    // The rows are inset 16pt from the window edge, like the prototype.
    final row = find.widgetWithText(AppleListTile, 'Row 1');
    expect(tester.getTopLeft(row).dx, closeTo(16, 0.5));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/list_card.png'),
    );
  });
}
