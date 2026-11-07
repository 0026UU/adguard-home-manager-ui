import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/confirm_action_modal.dart';
import 'package:adguard_home_manager/widgets/process_dialog.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
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
