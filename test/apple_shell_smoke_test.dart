import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

const List<String> _ranges = ['24 hours', '7 days', '30 days'];

Widget _heroCard() {
  final p = const ApplePalette(Brightness.light);

  return AppleCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const AppleIconBadge(
              icon: CupertinoIcons.checkmark_shield,
              color: Color(0xFF34C759),
              size: 34,
              iconSize: 21,
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: AppleStatCard(
                label: 'All protections',
                value: 'Protection enabled',
                caption: 'adguard.example.com',
              ),
            ),
            AppleDonut(percent: 32.4, color: p.red),
          ],
        ),
        const SizedBox(height: 12),
        const AppleSparkline(values: [1, 4, 2, 8, 6, 9, 3]),
      ],
    ),
  );
}

Widget _segmented() {
  return AppleSegmented(
    labels: _ranges,
    selectedIndex: 0,
    onChanged: (_) {},
  );
}

Widget _shell() {
  return AppleScreen(
    title: 'Overview',
    onRefresh: () async {},
    actions: [
      IconButton(onPressed: () {}, icon: const Icon(CupertinoIcons.arrow_clockwise)),
    ],
    searchbar: AppleSearchField(hint: 'Search', onChanged: (_) {}),
    slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: _heroCard(),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _segmented(),
        ),
      ),
      SliverToBoxAdapter(
        child: AppleListSection(
          title: 'Server status',
          headerTrailing: const Text('All protections'),
          footer: 'Hairlines stay inset from the row text.',
          children: [
            AppleListTile(
              title: 'Rule filtering',
              subtitle: 'A very long subtitle that must ellipsize instead of overflowing the row',
              icon: CupertinoIcons.line_horizontal_3_decrease,
              trailing: const ApplePill(label: 'Enabled', color: Color(0xFF34C759)),
            ),
            const AppleSwitchListTile(
              title: 'Safe browsing',
              value: true,
              icon: CupertinoIcons.checkmark_shield,
            ),
            AppleListTile(
              title: 'Safe search',
              value: 'Disabled',
              onTap: () {},
            ),
          ],
        ),
      ),
      SliverToBoxAdapter(
        child: AppleListSection(
          title: 'Queried domains',
          children: [
            for (var i = 0; i < 5; i++)
              AppleListTile(
                title: 'domain-$i.example.com',
                subtitle: '1 234 queries',
                leading: AppleAvatar(text: 'd$i', color: pLight.tint, size: 30),
                value: '123',
              ),
          ],
        ),
      ),
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: AppleCard(
            child: _Chart(),
          ),
        ),
      ),
      const SliverToBoxAdapter(
        child: AppleEmptyState(
          icon: CupertinoIcons.doc_text,
          title: 'No logs',
          message: 'Nothing was queried yet.',
        ),
      ),
    ],
  );
}

const ApplePalette pLight = ApplePalette(Brightness.light);

class _Chart extends StatelessWidget {
  const _Chart();

  @override
  Widget build(BuildContext context) {
    return AppleAreaChart(
      values: const [0, 12, 30, 8, 0, 44, 21, 60, 12, 0],
      height: 90,
      xLabels: const ['00:00', '08:00', '16:00', '24:00'],
      maxValueLabel: (max) => 'max ${max.toInt()}',
    );
  }
}

Widget _tree(double width) {
  return MaterialApp(
    theme: appleLightTheme(),
    home: Scaffold(
      body: SizedBox.expand(
        child: width > 1000
          ? Row(
              children: [
                SizedBox(
                  width: 240,
                  child: AppleSidebar(
                    currentIndex: 1,
                  onChanged: (_) {},
                    items: const [
                      AppleSidebarItem(icon: CupertinoIcons.house, label: 'Home'),
                      AppleSidebarItem(icon: CupertinoIcons.doc_text, label: 'Logs', badge: true),
                    ],
                  ),
                ),
                Expanded(child: _shell()),
              ],
            )
          : _shell(),
      ),
      bottomNavigationBar: width > 1000
        ? null
        : AppleTabBar(
            currentIndex: 2,
            onChanged: (_) {},
            items: const [
              AppleTabItem(icon: CupertinoIcons.house, label: 'Home'),
              AppleTabItem(icon: CupertinoIcons.person_2, label: 'Clients'),
              AppleTabItem(icon: CupertinoIcons.doc_text, label: 'Logs', badge: true),
              AppleTabItem(icon: CupertinoIcons.shield, label: 'Filters'),
              AppleTabItem(icon: CupertinoIcons.settings, label: 'Settings'),
            ],
          ),
    ),
  );
}

void main() {
  Future<void> pumpShell(WidgetTester tester, double width) async {
    await tester.pumpWidget(_tree(width));
    await tester.pumpAndSettle();
  }

  testWidgets('shell lays out on a phone', (tester) async {
    await pumpShell(tester, 390);
    expect(tester.takeException(), isNull);
    expect(find.text('Overview'), findsWidgets);
  });

  testWidgets('shell lays out on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpShell(tester, 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shell lays out on desktop', (tester) async {
    tester.view.physicalSize = const Size(1440 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await pumpShell(tester, 1440);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large title collapses while scrolling', (tester) async {
    await pumpShell(tester, 390);
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SliverAppBar), findsOneWidget);
  });

  testWidgets('segmented control is tappable', (tester) async {
    await pumpShell(tester, 390);
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('action sheet and sheet open', (tester) async {
    await pumpShell(tester, 390);

    final context = tester.element(find.text('Overview').first);

    showAppleActionSheet(
      context,
      title: 'domain.example.com',
      actions: [
        AppleSheetAction(label: 'Block domain', onTap: () {}),
        const AppleSheetAction(label: 'Delete', destructive: true),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);

    Navigator.of(context).pop();
    await tester.pumpAndSettle();

    showAppleSheet(
      context,
      title: 'Details',
      body: const AppleListSection(
        children: [AppleListTile(title: 'Row')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Row'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
