import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/encryption.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/screens/settings/encryption/encryption.dart';
import 'package:adguard_home_manager/services/api_client.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

// The encryption page reads `/tls/status`, validates every edit against
// `/tls/validate` and writes `/tls/configure`. No test here can reach a server,
// so the API client below answers from the fixture and keeps every payload the
// page produced, which is how the tests check that a switch only moves the
// port it stands for.

/// The server the app is connected to.
Server serverFixture() => Server(
      id: '1',
      name: 'Home',
      connectionMethod: 'http',
      domain: '192.168.1.10',
      port: 3000,
      defaultServer: true,
      runningOnHa: false,
    );

/// When the installed certificate stops being served.
DateTime notAfterFixture() => DateTime.utc(2026, 3, 9, 6, 0);

/// What `/tls/status` answers for a box serving DoT and DoH from files.
EncryptionData encryptionFixture({
  bool enabled = true,
  String serverName = 'dns.example.com',
  int? portHttps = 443,
  int? portDnsOverTls = 853,
  int? portDnsOverQuic,
  bool forceHttps = true,
  bool validCert = true,
  bool validChain = true,
  String subject = 'CN=dns.example.com',
  String issuer = "CN=Yeti, O=Yggdrasil LLC",
  List<String> dnsNames = const ['dns.example.com', 'www.example.com'],
  bool validKey = true,
  String keyType = 'EC private key',
  bool validPair = true,
  String certificatePath = '/opt/adguard-home/ssl/dns.example.com.crt',
  String privateKeyPath = '/opt/adguard-home/ssl/dns.example.com.key',
  String certificateChain = '',
  String privateKey = '',
  bool privateKeySaved = false,
  bool? servePlainDns = true,
}) =>
    EncryptionData(
      enabled: enabled,
      serverName: serverName,
      portHttps: portHttps,
      portDnsOverTls: portDnsOverTls,
      portDnsOverQuic: portDnsOverQuic,
      forceHttps: forceHttps,
      validCert: validCert,
      validChain: validChain,
      subject: subject,
      issuer: issuer,
      notAfter: notAfterFixture(),
      dnsNames: dnsNames,
      validKey: validKey,
      keyType: keyType,
      validPair: validPair,
      certificatePath: certificatePath,
      privateKeyPath: privateKeyPath,
      certificateChain: certificateChain,
      privateKey: privateKey,
      privateKeySaved: privateKeySaved,
      servePlainDns: servePlainDns,
      portDnscrypt: 8443,
      dnscryptConfigFile: '',
      allowUnencryptedDoh: false,
    );

/// What `/tls/validate` answers for that certificate and key.
EncryptionValidation validationFixture({
  bool validCert = true,
  bool validChain = true,
  bool validKey = true,
  bool validPair = true,
  String? warningValidation,
}) =>
    EncryptionValidation(
      subject: 'CN=dns.example.com',
      issuer: "CN=Yeti, O=Yggdrasil LLC",
      keyType: 'EC private key',
      notAfter: notAfterFixture(),
      dnsNames: const ['dns.example.com', 'www.example.com'],
      validCert: validCert,
      validChain: validChain,
      validKey: validKey,
      validPair: validPair,
      warningValidation: warningValidation,
    );

/// An API client that never opens a socket.
class EncryptionApiStub extends ApiClientV2 {
  EncryptionApiStub({
    required super.server,
    required this.data,
    this.validation,
  });

  /// What `/tls/status` answers.
  EncryptionData data;

  /// What `/tls/validate` answers; a stub without one answers with a sound
  /// certificate.
  EncryptionValidation? validation;

  bool succeeds = true;

  /// Whether `/tls/configure` accepts what the page writes.
  bool writeSucceeds = true;

  /// Keeps the first read back until the test releases the gate.
  bool blocks = false;

  /// Holds a write open so the test can see the blocking progress dialog.
  bool blockWrites = false;

  int reads = 0;
  final List<Map<String, dynamic>> validations = [];
  final List<Map<String, dynamic>> saves = [];
  final Completer<void> gate = Completer<void>();
  Completer<void> writesGate = Completer<void>();

  /// A real call answers after the frame, so the page never hears about new
  /// data while it is still building.
  Future<void> _settled() => Future<void>.delayed(Duration.zero);

  @override
  Future<ApiResponse> getEncryptionSettings() async {
    await _settled();
    if (blocks) await gate.future;
    reads++;
    if (!succeeds) return const ApiResponse(successful: false);
    return ApiResponse(successful: true, content: data);
  }

  @override
  Future<ApiResponse> checkEncryptionSettings({
    required Map<String, dynamic> data,
  }) async {
    await _settled();
    validations.add(data);
    return ApiResponse(
      successful: true,
      content: EncryptionValidationResult(
        isObject: true,
        encryptionValidation: validation ?? validationFixture(),
      ),
    );
  }

  @override
  Future<ApiResponse> saveEncryptionSettings({
    required Map<String, dynamic> data,
  }) async {
    await _settled();
    if (blockWrites) await writesGate.future;
    saves.add(data);
    if (!writeSucceeds) return const ApiResponse(successful: false);
    return const ApiResponse(successful: true);
  }
}

class EncryptionHarness {
  EncryptionHarness(this.api, this.servers);

  final EncryptionApiStub api;
  final ServersProvider servers;
}

/// Pumps the encryption page the way the settings list pushes it.
///
/// The page is long, so the surface is tall enough to keep every row inside the
/// viewport and tappable: a [CustomScrollView] only lets a tap reach what it
/// paints. The goldens override the size to the 840pt frame of the design layer.
Future<EncryptionHarness> pumpEncryption(
  WidgetTester tester, {
  EncryptionData? data,
  EncryptionValidation? validation,
  bool succeeds = true,
  bool writeSucceeds = true,
  bool blocks = false,
  bool blockWrites = false,
  bool settle = true,
  Brightness brightness = Brightness.light,
  Size surface = const Size(390, 3000),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final server = serverFixture();
  final api = EncryptionApiStub(
    server: server,
    data: data ?? encryptionFixture(),
    validation: validation,
  )
    ..succeeds = succeeds
    ..writeSucceeds = writeSucceeds
    ..blocks = blocks
    ..blockWrites = blockWrites;

  final servers = ServersProvider()
    ..setSelectedServer(server)
    ..setApiClient2(api);
  final appConfig = AppConfigProvider(sharedPreferencesInstance: prefs);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfigProvider>.value(value: appConfig),
        ChangeNotifierProvider<ServersProvider>.value(value: servers),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: globalNavigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        theme: brightness == Brightness.dark ? appleDarkTheme() : appleLightTheme(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: ApplePalette.of(context).window,
            body: Center(
              child: AppleButton(
                label: 'open',
                onPressed: () => Navigator.push(
                  context,
                  CupertinoPageRoute<void>(
                    builder: (_) => const EncryptionSettings(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  await tester.tap(find.text('open'));
  // A gated load keeps its spinner turning, so settling would never finish.
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  return EncryptionHarness(api, servers);
}
