// ignore_for_file: use_build_context_synchronously
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';


import 'package:adguard_home_manager/widgets/add_server/unsupported_version_modal.dart';
import 'package:adguard_home_manager/widgets/add_server/add_server_functions.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/config/minimum_server_version.dart';
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/functions/compare_versions.dart';
import 'package:adguard_home_manager/services/auth.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/services/api_client.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/constants/urls.dart';
import 'package:adguard_home_manager/functions/open_url.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/functions/base64.dart';
import 'package:adguard_home_manager/models/app_log.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/models/server.dart';

enum ConnectionType { http, https}

class AddServerModal extends StatefulWidget {
  final Server? server;

  /// True shows the wide card, false the phone sheet.
  final bool dialog;
  final void Function(String version) onUnsupportedVersion;

  const AddServerModal({
    super.key,
    this.server,
    required this.dialog,
    required this.onUnsupportedVersion
  });

  @override
  State<AddServerModal> createState() => _AddServerModalState();
}

class _AddServerModalState extends State<AddServerModal> {
  final uuid = const Uuid();

  final TextEditingController nameController = TextEditingController();
  String? nameError;

  ConnectionType connectionType = ConnectionType.http;

  final TextEditingController ipDomainController = TextEditingController();
  String? ipDomainError;

  final TextEditingController pathController = TextEditingController();
  String? pathError;

  final TextEditingController portController = TextEditingController();
  String? portError;

  final TextEditingController userController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  bool defaultServer = false;

  bool homeAssistant = false;

  bool allDataValid = false;

  bool isConnecting = false;

  @override
  void initState() {
    if (widget.server != null) {
      nameController.text = widget.server!.name;
      connectionType = widget.server!.connectionMethod == 'https' ? ConnectionType.https : ConnectionType.http;
      ipDomainController.text = widget.server!.domain;
      pathController.text = widget.server!.path ?? '';
      portController.text = widget.server!.port != null ? widget.server!.port.toString() : "";
      userController.text = widget.server!.user ?? "";
      passwordController.text = widget.server!.password ?? "";
      defaultServer = widget.server!.defaultServer;
      homeAssistant = widget.server!.runningOnHa;
    }
    setState(() => allDataValid = checkDataValid(
      ipDomainController: ipDomainController,
      nameController: nameController,
      ipDomainError: ipDomainError,
      pathError: pathError,
      portError: portError
    ));
    super.initState();
  }

  @override
  void dispose() {
    nameController.dispose();
    ipDomainController.dispose();
    pathController.dispose();
    portController.dispose();
    userController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    final serversProvider = Provider.of<ServersProvider>(context, listen: false);
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);

    void cancelConnecting() {
      if (mounted) {
        setState(() => isConnecting = false);
      }
      else {
        isConnecting = false;
      }
    }

    void validateData() {
      setState(() => allDataValid = checkDataValid(
        ipDomainController: ipDomainController,
        nameController: nameController,
        ipDomainError: ipDomainError,
        pathError: pathError,
        portError: portError
      ));
    }

    String getErrorMessage(AuthStatus status) {
      if (status == AuthStatus.invalidCredentials) return AppLocalizations.of(context)!.invalidUsernamePassword;
      if (status == AuthStatus.manyAttepts) return AppLocalizations.of(context)!.tooManyAttempts;
      if (status == AuthStatus.socketException || status == AuthStatus.timeoutException) return AppLocalizations.of(context)!.cantReachServer;
      if (status == AuthStatus.serverError) return AppLocalizations.of(context)!.serverError;
      if (status == AuthStatus.handshakeException) return AppLocalizations.of(context)!.sslError;
      return AppLocalizations.of(context)!.unknownError;
    }

    void connect() async {
      setState(() => isConnecting = true);

      Server serverObj = Server(
        id: uuid.v4(),
        name: nameController.text, 
        connectionMethod: connectionType.name, 
        domain: ipDomainController.text, 
        port: portController.text != '' ? int.parse(portController.text) : null,
        user: userController.text != "" ? userController.text : null, 
        password: passwordController.text != "" ? passwordController.text : null, 
        path: pathController.text != "" ? pathController.text : null, 
        defaultServer: defaultServer,
        authToken: homeAssistant == true 
          ? encodeBase64UserPass(userController.text, passwordController.text)
          : null,
        runningOnHa: homeAssistant
      );

      final result = homeAssistant == true 
        ? await ServerAuth.loginHA(serverObj)
        : await ServerAuth.login(serverObj);

      // If something goes wrong with the connection
      if (result != AuthStatus.success) {
        cancelConnecting();
        if (mounted) {
          showSnackbar(
            appConfigProvider: appConfigProvider, 
            label: getErrorMessage(result), 
            color: Colors.red
          );
        }
        return;
      }

      if (serverObj.user != null && serverObj.password != null) {
        serverObj.authToken = encodeBase64UserPass(serverObj.user!, serverObj.password!);
      }

      statusProvider.setServerStatusLoad(LoadStatus.loading);
      final ApiClientV2 apiClient2 = ApiClientV2(server: serverObj);
      final serverStatus = await apiClient2.getServerStatus();

      if (!context.mounted) return;

      // If something goes wrong when fetching server status
      if (serverStatus.successful == false) {
        statusProvider.setServerStatusLoad(LoadStatus.error);
        Navigator.pop(context);
        return;
      }

      final status = serverStatus.content as ServerStatus;

      // Check if ths server version is compatible
      final validVersion = serverVersionIsAhead(
        currentVersion: status.serverVersion, 
        referenceVersion: MinimumServerVersion.stable,
        referenceVersionBeta: MinimumServerVersion.beta
      );
      if (validVersion == false) {
        showDialog(
          context: context, 
          builder: (ctx) => UnsupportedVersionModal(
            serverVersion: status.serverVersion,
            onClose: () => Navigator.pop(context)
          )
        );
        return;
      }

      final serverCreated = await serversProvider.createServer(serverObj);

      if (!context.mounted) return;

      // If something goes wrong when saving the connection on the db
      if (serverCreated != null) {
        setState(() => isConnecting = false);
        showSnackbar(
          appConfigProvider: appConfigProvider, 
          label: AppLocalizations.of(context)!.connectionNotCreated, 
          color: Colors.red
        );
        return;
      }

      // If everything is successful
      statusProvider.setServerStatusData(
        data: status
      );
      serversProvider.setApiClient2(apiClient2);
      statusProvider.setServerStatusLoad(LoadStatus.loaded);
      if (serverVersionNeedsWarning(status.serverVersion)) {
        Navigator.pop(context);
        widget.onUnsupportedVersion(status.serverVersion);
      }
      else {
        Navigator.pop(context);
      }
    }

    void edit() async {
      setState(() => isConnecting = true);
      
      final Server serverObj = Server(
        id: widget.server!.id,
        name: nameController.text, 
        connectionMethod: connectionType.name, 
        domain: ipDomainController.text, 
        port: portController.text != '' ? int.parse(portController.text) : null,
        user: userController.text != "" ? userController.text : null, 
        password: passwordController.text != "" ? passwordController.text : null, 
        defaultServer: defaultServer,
        authToken: homeAssistant == true 
          ? encodeBase64UserPass(userController.text, passwordController.text)
          : null,
        runningOnHa: homeAssistant
      );
      
      final result = homeAssistant == true 
        ? await ServerAuth.loginHA(serverObj)
        : await ServerAuth.login(serverObj);

      // If something goes wrong with the connection
      if (result != AuthStatus.success) {
        cancelConnecting();
        if (mounted) {
          showSnackbar(
            appConfigProvider: appConfigProvider, 
            label: getErrorMessage(result), 
            color: Colors.red
          );
        }
        return;
      }
      
      if (serverObj.user != null && serverObj.password != null) {
        serverObj.authToken = encodeBase64UserPass(serverObj.user!, serverObj.password!);
      }

      final ApiClientV2 apiClient2 = ApiClientV2(server: serverObj);
      final version = await apiClient2.getServerVersion();
      if (version.successful == false) {
        if (mounted) setState(() => isConnecting = false);
        return;
      }

      // Check if ths server version is compatible
      final validVersion = serverVersionIsAhead(
        currentVersion: version.content, 
        referenceVersion: MinimumServerVersion.stable,
        referenceVersionBeta: MinimumServerVersion.beta
      );
      if (validVersion == false) {
        showDialog(
          context: context, 
          builder: (ctx) => UnsupportedVersionModal(
            serverVersion: version.content,
            onClose: () => Navigator.pop(context)
          )
        );
        return;
      }

      final serverSaved = await serversProvider.editServer(serverObj);

      if (!mounted) return;
    
      // If something goes wrong when saving the connection on the db
      if (serverSaved != null) {
        setState(() => isConnecting = false);
        appConfigProvider.addLog(
          AppLog(
            type: 'save_connection_db', 
            dateTime: DateTime.now(),
            message: serverSaved.toString()
          )
        );
        showSnackbar(
          appConfigProvider: appConfigProvider, 
          label: AppLocalizations.of(context)!.connectionNotCreated, 
          color: Colors.red
        );
        return;
      }

      // If everything is successful
      if (
        version.successful == true &&
        serverVersionNeedsWarning((version.content ?? "") as String)
      ) {
        Navigator.pop(context);
        widget.onUnsupportedVersion(version.content);
      }
      else {
        Navigator.pop(context);
      }      
    }


    Widget notice(IconData icon, Color color, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: AppleCard(
        radius: BorderRadius.circular(10),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppleIconBadge(icon: icon, color: color, size: 26, iconSize: 15),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  text,
                  style: TextStyle(fontSize: 13, height: 1.35, color: p.label2),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    List<Widget> form() {
      final locked = widget.server != null || isConnecting;

      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: p.pill(p.tint),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.tint.withValues(alpha: 0.3)),
            ),
            child: Text(
              "${connectionType.name}://${ipDomainController.text}${portController.text != '' ? ':${portController.text}' : ""}${pathController.text}",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: p.tint,
              ),
            ),
          ),
        ),
        AppleFormGroupLabel(l.general),
        AppleTextField(
          label: l.name,
          controller: nameController,
          enabled: !isConnecting,
          icon: CupertinoIcons.textbox,
          error: nameError,
          onChanged: (value) {
            if (value != '') {
              setState(() => nameError = null);
            } else {
              setState(() => nameError = l.nameNotEmpty);
            }
            validateData();
          },
        ),
        AppleFormGroupLabel(l.connection),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: AppleSegmented(
            labels: const ["HTTP", "HTTPS"],
            selectedIndex: connectionType.index,
            onChanged: (v) =>
                setState(() => connectionType = ConnectionType.values[v]),
          ),
        ),
        notice(
          CupertinoIcons.exclamationmark_triangle_fill,
          p.orange,
          l.redirectHttpsWarning,
        ),
        if (connectionType == ConnectionType.https)
          notice(CupertinoIcons.info_circle_fill, p.tint, l.sslWarning),
        AppleTextField(
          label: l.ipDomain,
          controller: ipDomainController,
          enabled: !isConnecting,
          icon: CupertinoIcons.link,
          error: ipDomainError,
          keyboardType: TextInputType.url,
          onChanged: (v) {
            setState(
              () => ipDomainError = validateAddress(context: context, value: v),
            );
            validateData();
          },
        ),
        AppleTextField(
          label: l.path,
          controller: pathController,
          enabled: !isConnecting,
          icon: CupertinoIcons.list_bullet_indent,
          error: pathError,
          hint: l.examplePath,
          helper: l.helperPath,
          onChanged: (v) {
            setState(
              () => pathError = validateSubroute(context: context, value: v),
            );
            validateData();
          },
        ),
        AppleTextField(
          label: l.port,
          controller: portController,
          enabled: !isConnecting,
          icon: CupertinoIcons.number,
          error: portError,
          keyboardType: TextInputType.number,
          onChanged: (v) {
            setState(
              () => portError = validatePort(context: context, value: v),
            );
            validateData();
          },
        ),
        AppleFormGroupLabel(l.authentication),
        AppleTextField(
          label: l.username,
          controller: userController,
          enabled: !isConnecting,
          icon: CupertinoIcons.person,
        ),
        AppleTextField(
          label: l.password,
          controller: passwordController,
          enabled: !isConnecting,
          icon: CupertinoIcons.lock,
          keyboardType: TextInputType.visiblePassword,
          obscure: true,
        ),
        AppleFormGroupLabel(l.other),
        AppleListSection(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          children: [
            AppleSwitchListTile(
              title: l.defaultServer,
              icon: CupertinoIcons.star_fill,
              iconColor: p.yellow,
              value: defaultServer,
              onChanged: locked
                  ? null
                  : (value) => setState(() => defaultServer = value),
            ),
            AppleSwitchListTile(
              title: l.runningHomeAssistant,
              icon: CupertinoIcons.house_fill,
              iconColor: p.indigo,
              value: homeAssistant,
              onChanged: locked
                  ? null
                  : (value) => setState(() => homeAssistant = value),
            ),
          ],
        ),
      ];
    }

    return AppleFormModal(
      title: widget.server == null ? l.createConnection : l.editConnection,
      icon: widget.server == null ? CupertinoIcons.plus : CupertinoIcons.pencil,
      dialog: widget.dialog,
      maxWidth: 460,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isConnecting)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CupertinoActivityIndicator(radius: 4),
              ),
            ),
          IconButton(
            onPressed: () => openUrl(Urls.connectionInstructions),
            icon: Icon(CupertinoIcons.question_circle, color: p.tint),
          ),
        ],
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(children: form()),
            ),
          ),
          AppleFormFooter(
            confirmLabel: widget.server == null ? l.connect : l.save,
            confirmEnabled: allDataValid && !isConnecting,
            onConfirm: widget.server == null ? connect : edit,
          ),
        ],
      ),
    );
  }
}
