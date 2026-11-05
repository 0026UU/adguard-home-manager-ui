import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/dhcp.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/models/rewrite_rules.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';
import 'package:adguard_home_manager/screens/filters/details/add_list_modal.dart';
import 'package:adguard_home_manager/screens/filters/modals/update_interval_lists_modal.dart';
import 'package:adguard_home_manager/screens/logs/filters/logs_filters_modal.dart';
import 'package:adguard_home_manager/screens/settings/access_settings/add_client_modal.dart';
import 'package:adguard_home_manager/screens/settings/dhcp/add_static_lease_modal.dart';
import 'package:adguard_home_manager/screens/settings/dns/comment_modal.dart';
import 'package:adguard_home_manager/screens/settings/dns_rewrites/dns_rewrite_modal.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/option_box.dart';

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
      home: home,
    ),
  );

  await tester.pumpAndSettle();
}

late BuildContext _hostContext;

/// Like [_pump] but with the providers above `MaterialApp`, the way `main.dart`
/// wires them, so routes pushed by the navigator can still read them.
Future<void> _pumpWithProviders(WidgetTester tester, List<SingleChildWidget> providers) async {
  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(
    MultiProvider(
      providers: providers,
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
}

/// Shows [modal] the way the screens do: a dialog on wide layouts, a bottom
/// sheet on phones.
Future<void> _showModal(WidgetTester tester, Size surface, Widget modal) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await _pump(
    tester,
    Builder(
      builder: (ctx) {
        _hostContext = ctx;
        return const SizedBox.shrink();
      },
    ),
  );

  if (surface.width > 600) {
    showDialog(context: _hostContext, builder: (_) => modal);
  } else {
    showModalBottomSheet(
      context: _hostContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => modal,
    );
  }
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the rewrite dialog is a card that gates confirm on validation', (tester) async {
    RewriteRules? confirmed;

    await _showModal(
      tester,
      const Size(900, 900),
      DnsRewriteModal(
        dialog: true,
        onConfirm: (rule, _) => confirmed = rule,
        onDelete: (_) {},
      ),
    );

    expect(find.byType(AppleFormModal), findsOneWidget);
    expect(find.text(l.addDnsRewrite), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));

    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();
    expect(confirmed, isNull);

    await tester.enterText(find.byType(TextFormField).at(0), 'example.com');
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(1), '10.0.0.1');
    await tester.pump();

    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();

    expect(confirmed?.domain, 'example.com');
    expect(confirmed?.answer, '10.0.0.1');
    expect(find.byType(DnsRewriteModal), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing a rewrite rule offers delete', (tester) async {
    RewriteRules? deleted;

    await _showModal(
      tester,
      const Size(900, 900),
      DnsRewriteModal(
        dialog: true,
        rule: RewriteRules(domain: 'old.example.com', answer: '10.0.0.1', enabled: true),
        onConfirm: (_, __) {},
        onDelete: (rule) => deleted = rule,
      ),
    );

    expect(find.text(l.editRewriteRule), findsOneWidget);

    await tester.tap(find.text(l.delete));
    await tester.pumpAndSettle();

    expect(deleted?.domain, 'old.example.com');
    expect(find.byType(DnsRewriteModal), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the comment sheet prefixes the saved comment', (tester) async {
    String? saved;

    await _showModal(
      tester,
      const Size(420, 800),
      CommentModal(dialog: false, onConfirm: (value) => saved = value),
    );

    expect(find.text(l.comment), findsWidgets);

    await tester.enterText(find.byType(TextFormField), 'internal box');
    await tester.pump();
    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();

    expect(saved, '# internal box');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the lease sheet reports invalid values', (tester) async {
    Lease? confirmed;

    await _showModal(
      tester,
      const Size(420, 800),
      AddStaticLeaseModal(dialog: false, onConfirm: (lease) => confirmed = lease),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'not-a-mac');
    await tester.pumpAndSettle();

    expect(find.text(l.macAddressNotValid), findsOneWidget);

    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();
    expect(confirmed, isNull);

    await tester.enterText(find.byType(TextFormField).at(0), '32:0a:9b:c8:34:4d');
    await tester.enterText(find.byType(TextFormField).at(1), '192.168.1.40');
    await tester.enterText(find.byType(TextFormField).at(2), 'printer');
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();

    expect(confirmed?.ip, '192.168.1.40');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the access list sheet titles itself per list', (tester) async {
    String? value;
    AccessSettingsList? kind;

    await _showModal(
      tester,
      const Size(900, 900),
      AddClientModal(
        dialog: true,
        type: AccessSettingsList.allowed,
        onConfirm: (text, list) {
          value = text;
          kind = list;
        },
      ),
    );

    expect(find.text(l.allowClient), findsOneWidget);
    expect(find.text(l.clientIdentifier), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '192.168.1.10');
    await tester.pump();
    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();

    expect(value, '192.168.1.10');
    expect(kind, AccessSettingsList.allowed);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the interval sheet writes the picked value back', (tester) async {
    int? changed;

    await _showModal(
      tester,
      const Size(900, 900),
      UpdateIntervalListsModal(
        dialog: true,
        interval: 1,
        onChange: (value) => changed = value,
      ),
    );

    expect(find.text(l.updateFrequency), findsOneWidget);
    expect(find.byType(OptionBox), findsNWidgets(6));

    await tester.tap(find.text(l.hours12));
    await tester.pump();
    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();

    expect(changed, 12);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the whitelist form saves an edited list', (tester) async {
    final original = Filter(
      url: 'https://example.org/list.txt',
      name: 'Old name',
      lastUpdated: DateTime.utc(2026, 11, 4),
      id: 3,
      rulesCount: 12,
      enabled: true,
    );
    Filter? edited;

    await _showModal(
      tester,
      const Size(900, 900),
      AddListModal(
        dialog: true,
        type: 'whitelist',
        list: original,
        onEdit: ({required list, required type}) => edited = list,
      ),
    );

    expect(find.text(l.editWhitelist), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Allowlist');
    await tester.pump();
    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();

    expect(edited?.name, 'Allowlist');
    expect(edited?.url, original.url);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the log filter sheet groups its rows and quick filters', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpWithProviders(tester, [
      ChangeNotifierProvider(create: (_) => LogsProvider()),
      ChangeNotifierProvider(create: (_) => ClientsProvider()),
    ]);

    showDialog(
      context: _hostContext,
      builder: (_) => const LogsFiltersModal(dialog: true),
    );
    // The loading row spins, so settle on fixed frames instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(l.filters), findsOneWidget);
    expect(find.text(l.quickFilters), findsOneWidget);
    expect(find.byType(AppleSegmented), findsOneWidget);
    // Clients are still loading, so that row is disabled and spins.
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
