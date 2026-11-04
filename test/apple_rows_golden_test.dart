import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

// The log entry, the device row and the settings header card are all defined
// by where their parts sit relative to each other, which a widget test cannot
// see. These goldens pin the painted result.
//
// Regenerate with: flutter test --update-goldens test/apple_rows_golden_test.dart

Future<void> _pump(WidgetTester tester, Widget body, {double inset = 16}) async {
  await tester.binding.setSurfaceSize(const Size(390, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final palette = ApplePalette(Brightness.light);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appleLightTheme(),
      home: Scaffold(
        backgroundColor: palette.window,
        body: ListView(padding: const EdgeInsets.symmetric(vertical: 16), children: [
          Padding(padding: EdgeInsets.symmetric(horizontal: inset), child: body),
        ]),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _card(List<Widget> rows) {
  final palette = ApplePalette(Brightness.light);

  return ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: ColoredBox(
      color: palette.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              const AppleSeparator(
                indent: AppleLogRow.separatorInset,
                endIndent: AppleLogRow.separatorInset,
              ),
          ],
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('a query log entry draws pill, domain, time and detail runs',
      (tester) async {
    final palette = ApplePalette(Brightness.light);

    await _pump(
      tester,
      _card([
        AppleLogRow(
          leading: ApplePill(label: 'Blocked', color: palette.red),
          title: 'ads.example.org',
          time: '21:04:12',
          details: const ['192.168.1.24', '12.40 ms'],
          onTap: () {},
        ),
        AppleLogRow(
          leading: ApplePill(label: 'Allowed', color: palette.green),
          title: 'client-router.update.microsoft.com',
          time: '21:04:09',
          details: const ['livingroom-mac', '3.10 ms'],
        ),
        AppleLogRow(
          leading: ApplePill(label: 'Forwarded', color: palette.tint),
          title: 'dns.google',
          time: '21:03:58',
          details: const ['192.168.1.11'],
        ),
      ]),
    );

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/log_rows.png'),
    );
  });

  testWidgets('a device row draws the gradient avatar and the trailing value',
      (tester) async {
    final palette = ApplePalette(Brightness.light);

    await _pump(
      tester,
      inset: 0,
      AppleListSection(
        title: 'DEVICES',
        children: [
          AppleListTile(
            title: 'MacBook Pro',
            subtitle: '192.168.1.24',
            value: '5.1k',
            leading: AppleAvatar(
              text: 'MacBook Pro',
              size: 40,
              color: palette.seeded('MacBook Pro'),
              gradientTo: palette.seededAlt('MacBook Pro'),
            ),
            leadingWidth: 40,
            onTap: () {},
          ),
          AppleListTile(
            title: 'Living Room Mac',
            subtitle: '192.168.1.5',
            value: '924',
            leading: AppleAvatar(
              text: 'Living Room Mac',
              size: 40,
              color: palette.seeded('Living Room Mac'),
              gradientTo: palette.seededAlt('Living Room Mac'),
            ),
            leadingWidth: 40,
            onTap: () {},
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/device_rows.png'),
    );
  });

  testWidgets('the settings header card draws the server block and its action',
      (tester) async {
    await _pump(
      tester,
      AppleBigRow(
        icon: Icons.dns_outlined,
        color: ApplePalette(Brightness.light).green,
        colorTo: ApplePalette(Brightness.light).teal,
        title: 'Home server',
        details: 'https://192.168.1.10:3000 · v0.107.58',
        status: 'Connected',
        actionLabel: 'Servers',
        onAction: () {},
      ),
    );

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/settings_bigrow.png'),
    );
  });
}
