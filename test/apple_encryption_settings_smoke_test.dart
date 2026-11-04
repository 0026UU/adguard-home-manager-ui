import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/functions/base64.dart';
import 'package:adguard_home_manager/functions/format_time.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/screens/settings/encryption/custom_text_field.dart';
import 'package:adguard_home_manager/screens/settings/encryption/master_switch.dart';
import 'package:adguard_home_manager/screens/settings/encryption/reset_settings_modal.dart';
import 'package:adguard_home_manager/screens/settings/encryption/status.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';
import 'package:adguard_home_manager/widgets/custom_checkbox_list_tile.dart';
import 'package:adguard_home_manager/widgets/custom_list_tile.dart';
import 'package:adguard_home_manager/widgets/custom_switch_list_tile.dart';
import 'package:adguard_home_manager/widgets/section_label.dart';

import 'encryption_settings_harness.dart';

// Encryption is the page the design layer draws from `/tls/status` and
// `/tls/validate`. Its switches move the ports of the form it has always had,
// its certificate rows repeat what the server answered, and nothing is printed
// that the API never sent. The tests below hold the page to that.

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  String subtitleOf(WidgetTester t, String title) =>
      t.widget<AppleSwitchListTile>(find.widgetWithText(AppleSwitchListTile, title))
          .subtitle!;

  bool switchValue(WidgetTester t, String title) =>
      t.widget<AppleSwitchListTile>(find.widgetWithText(AppleSwitchListTile, title)).value;

  bool saveIsEnabled(WidgetTester t) =>
      t.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(l.save),
          matching: find.byType(IconButton),
        ),
      ).onPressed !=
      null;

  String fieldValue(WidgetTester t, String label) =>
      t.widget<AppleTextField>(find.widgetWithText(AppleTextField, label)).controller.text;

  testWidgets('the protocols are one Apple group under the page title', (tester) async {
    final h = await pumpEncryption(tester);

    expect(tester.takeException(), isNull);
    // The page read `/tls/status` exactly once while opening.
    expect(h.api.reads, 1);

    expect(
      find.descendant(
        of: find.byType(AppleLargeTitle),
        matching: find.text(l.encryptionSettings),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppleLargeTitle),
        matching: find.text(l.encryptionSettingsDescription),
      ),
      findsOneWidget,
    );
    expect(find.byType(AppleBackButton), findsOneWidget);

    // The group the design layer opens with, and the switches it holds.
    expect(find.text(l.enabledProtocols.toUpperCase()), findsOneWidget);
    expect(find.widgetWithText(AppleSwitchListTile, l.enableEncryption), findsOneWidget);
    expect(find.widgetWithText(AppleSwitchListTile, l.dnsOverTls), findsOneWidget);
    expect(find.widgetWithText(AppleSwitchListTile, l.dnsOverHttps), findsOneWidget);
    expect(find.widgetWithText(AppleSwitchListTile, l.dnsOverQuic), findsOneWidget);
    expect(find.byType(AppleSwitchListTile), findsNWidgets(6));
    expect(find.byType(CupertinoSwitch), findsNWidgets(6));

    // The save of the bar waits for the form to be touched, as it always did.
    expect(saveIsEnabled(tester), false);

    // No Material chrome is left on the page.
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(RadioListTile), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Card), findsNothing);
    expect(find.byType(CustomListTile), findsNothing);
    expect(find.byType(CustomSwitchListTile), findsNothing);
    expect(find.byType(CustomCheckboxListTile), findsNothing);
    expect(find.byType(SectionLabel), findsNothing);
    expect(find.byType(EncryptionMasterSwitch), findsNothing);
    expect(find.byType(EncryptionTextField), findsNothing);
    expect(find.byType(Status), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.save), findsNothing);
    expect(find.byIcon(Icons.restore_rounded), findsNothing);
    for (final scaffold in tester.widgetList<Scaffold>(find.byType(Scaffold))) {
      expect(scaffold.appBar, isNull);
    }
  });

  testWidgets('every row repeats what the server answered', (tester) async {
    await pumpEncryption(tester);

    // The port each protocol answers on, and the certificate it serves with.
    expect(subtitleOf(tester, l.dnsOverTls), 'Port 853 · ${l.certificateValid}');
    expect(subtitleOf(tester, l.dnsOverHttps), 'Port 443');
    expect(subtitleOf(tester, l.dnsOverQuic), l.portNotConfigured);
    expect(switchValue(tester, l.enableEncryption), true);
    expect(switchValue(tester, l.dnsOverTls), true);
    expect(switchValue(tester, l.dnsOverHttps), true);
    expect(switchValue(tester, l.dnsOverQuic), false);

    String value(String title) =>
        tester.widget<AppleListTile>(find.widgetWithText(AppleListTile, title)).value!;

    expect(find.text(l.certificates.toUpperCase()), findsOneWidget);
    expect(value(l.subject), 'CN=dns.example.com');
    expect(value(l.issuer), 'CN=Yeti, O=Yggdrasil LLC');
    expect(
      value(l.expirationDate),
      convertTimestampLocalTimezone(notAfterFixture(), 'yyyy-MM-dd'),
    );
    expect(value(l.hostNames), 'dns.example.com · www.example.com');

    // The answers of `/tls/validate`, not a fingerprint nobody computed.
    expect(find.text(l.validCertificateChain), findsOneWidget);
    expect(find.text(l.validPrivateKey), findsOneWidget);
    expect(value(l.keyType), 'EC private key');

    // The form the page has always carried is still on it.
    expect(find.text(l.serverConfiguration.toUpperCase()), findsOneWidget);
    expect(find.text(l.certificateSource.toUpperCase()), findsOneWidget);
    expect(find.text(l.privateKey.toUpperCase()), findsOneWidget);
    expect(find.byType(AppleTextField), findsNWidgets(6));
    expect(fieldValue(tester, l.domainName), 'dns.example.com');
    expect(fieldValue(tester, l.tlsPort), '853');
    expect(fieldValue(tester, l.dnsOverQuicPort), '');
    expect(fieldValue(tester, l.certificatePath), '/opt/adguard-home/ssl/dns.example.com.crt');
    expect(switchValue(tester, l.redirectHttps), true);
    expect(switchValue(tester, l.enablePlainDns), true);

    // Nothing invented: no row holds a placeholder.
    expect(find.text('—'), findsNothing);
    expect(find.text('SHA-256'), findsNothing);
  });

  testWidgets('a protocol switch moves only its own port', (tester) async {
    final h = await pumpEncryption(tester);

    // DNS-over-QUIC is served on no port at all, so its switch is off.
    await tester.tap(find.byType(CupertinoSwitch).at(3));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(fieldValue(tester, l.dnsOverQuicPort), '853');
    expect(subtitleOf(tester, l.dnsOverQuic), 'Port 853');
    // The other ports stayed where the server left them.
    expect(fieldValue(tester, l.tlsPort), '853');
    expect(fieldValue(tester, l.httpsPort), '443');
    // The switch asked the server whether that answer is valid, as the form does.
    expect(h.api.validations.last['port_dns_over_quic'], 853);

    // Switching it back takes the port away again.
    await tester.tap(find.byType(CupertinoSwitch).at(3));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(fieldValue(tester, l.dnsOverQuicPort), '');
    expect(subtitleOf(tester, l.dnsOverQuic), l.portNotConfigured);

    // The form has been touched, so saving it is allowed now.
    expect(saveIsEnabled(tester), true);
    await tester.tap(find.byTooltip(l.save));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final payload = h.api.saves.single;
    expect(payload['enabled'], true);
    expect(payload['server_name'], 'dns.example.com');
    expect(payload['port_https'], 443);
    expect(payload['port_dns_over_tls'], 853);
    expect(payload['port_dns_over_quic'], isNull);
    expect(payload['certificate_path'], '/opt/adguard-home/ssl/dns.example.com.crt');
    expect(find.text(l.encryptionConfigSaved), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('encryption switched off puts the protocols away', (tester) async {
    await pumpEncryption(tester);

    await tester.tap(find.byType(CupertinoSwitch).at(0));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(switchValue(tester, l.enableEncryption), false);
    // A server that serves nothing cannot have a protocol moved on it.
    expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch).at(1)).onChanged, isNull);
    expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch).at(2)).onChanged, isNull);
    expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch).at(3)).onChanged, isNull);
    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch).at(4)).onChanged,
      isNull,
    );
    // The ports the server reported are still the ones the form holds.
    expect(fieldValue(tester, l.tlsPort), '853');
  });

  testWidgets('a certificate the server refuses is said out loud', (tester) async {
    await pumpEncryption(
      tester,
      data: encryptionFixture(validCert: false),
      validation: validationFixture(
        validCert: false,
        validKey: false,
        validPair: false,
        warningValidation: 'certificate is expired',
      ),
    );

    // The banner carries the message of the validation call, not a summary.
    expect(find.byType(AppleCard), findsOneWidget);
    expect(find.text('certificate is expired'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.exclamationmark_triangle_fill), findsOneWidget);

    expect(subtitleOf(tester, l.dnsOverTls), 'Port 853 · ${l.certificateInvalid}');
    expect(find.text(l.invalidPrivateKey), findsOneWidget);
    expect(find.text(l.keysNotMatch), findsOneWidget);
    expect(find.text(l.validPrivateKey), findsNothing);
    // A pair the server refused cannot be saved.
    expect(saveIsEnabled(tester), false);
  });

  testWidgets('the certificate and the key are still chosen, then written', (tester) async {
    final h = await pumpEncryption(tester);

    // The path option is the one the server reported.
    Icon markOf(String title) => tester.widget<Icon>(
          find.descendant(
            of: find.widgetWithText(AppleListTile, title),
            matching: find.byIcon(CupertinoIcons.checkmark),
          ),
        );
    expect(markOf(l.certificateFilePath).color, isNotNull);
    expect(
      find.descendant(
        of: find.widgetWithText(AppleListTile, l.pasteCertificateContent),
        matching: find.byIcon(CupertinoIcons.checkmark),
      ),
      findsNothing,
    );
    expect(find.widgetWithText(AppleTextField, l.certificatePath), findsOneWidget);

    await tester.tap(find.widgetWithText(AppleListTile, l.pasteCertificateContent));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(markOf(l.pasteCertificateContent).color, isNotNull);
    expect(find.widgetWithText(AppleTextField, l.certificatePath), findsNothing);
    // A pasted certificate is a block of lines, not a single field.
    expect(
      tester.widget<AppleTextField>(find.widgetWithText(AppleTextField, l.certificateContent))
          .maxLines,
      isNull,
    );

    await tester.tap(find.widgetWithText(AppleListTile, l.pastePrivateKey));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppleSwitchListTile, l.usePreviousKey), findsOneWidget);
    expect(
      find.widgetWithText(AppleTextField, l.privateKeyPath),
      findsNothing,
    );

    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(AppleTextField, l.pastePrivateKey),
        matching: find.byType(TextFormField),
      ),
      '-----BEGIN PRIVATE KEY-----',
    );
    await tester.pump();
    await tester.pumpAndSettle();

    // A pasted key is an edit like any other: it went to `/tls/validate`.
    expect(
      h.api.validations.last['private_key'],
      encodeBase64('-----BEGIN PRIVATE KEY-----'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the reset row still asks before writing', (tester) async {
    final h = await pumpEncryption(tester, blockWrites: true);

    await tester.tap(find.widgetWithText(AppleListTile, l.resetSettings));
    await tester.pumpAndSettle();
    expect(find.byType(ResetSettingsModal), findsOneWidget);
    expect(find.text(l.resetEncryptionSettingsDescription), findsOneWidget);

    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();
    expect(h.api.saves, isEmpty);

    await tester.tap(find.widgetWithText(AppleListTile, l.resetSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.confirm));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The write blocks behind the progress dialog until the server answers.
    expect(find.text(l.resettingConfig), findsOneWidget);

    h.api.writesGate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    final payload = h.api.saves.single;
    expect(payload['enabled'], false);
    expect(payload['port_https'], 443);
    expect(payload['port_dns_over_tls'], 853);
    expect(payload['port_dns_over_quic'], 853);
    expect(payload['serve_plain_dns'], true);
    expect(find.text(l.configurationResetSuccessfully), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the settings load behind an Apple spinner', (tester) async {
    final h = await pumpEncryption(tester, blocks: true, settle: false);

    expect(find.byType(AppleLoading), findsOneWidget);
    expect(find.text(l.loadingEncryptionSettings), findsOneWidget);
    expect(find.byType(AppleSwitchListTile), findsNothing);

    h.api.gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(AppleLoading), findsNothing);
    expect(find.text(l.enabledProtocols.toUpperCase()), findsOneWidget);
  });

  testWidgets('a failed read reports the Apple way', (tester) async {
    await pumpEncryption(tester, succeeds: false);

    expect(find.byType(AppleEmptyState), findsOneWidget);
    expect(find.text(l.encryptionSettingsNotLoaded), findsOneWidget);
    expect(find.byType(AppleSwitchListTile), findsNothing);
    expect(find.byType(CupertinoSwitch), findsNothing);
    expect(find.byIcon(CupertinoIcons.exclamationmark_triangle), findsOneWidget);
  });
}
