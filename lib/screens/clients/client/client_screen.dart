import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/clients/client/client_form.dart';
import 'package:adguard_home_manager/screens/clients/client/client_screen_functions.dart';

import 'package:adguard_home_manager/models/safe_search.dart';
import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

class ClientInitialData {
  final String name;
  final String ip;

  const ClientInitialData({
    required this.name,
    required this.ip,
  });
}

class ControllerListItem {
  final String id;
  final TextEditingController controller;

  const ControllerListItem({
    required this.id,
    required this.controller,
  });
}

/// The add/edit form of one device: a pushed Apple page on a phone, a centred
/// card on the wide layouts. Saving hands the whole entry back through
/// [onConfirm]; the server is only touched by the caller.
class ClientScreen extends StatefulWidget {
  final Client? client;
  final void Function(Client) onConfirm;
  final void Function(Client)? onDelete;
  final bool fullScreen;
  final ClientInitialData? initialData;

  const ClientScreen({
    super.key,
    this.client,
    required this.onConfirm,
    this.onDelete,
    required this.fullScreen,
    this.initialData,
  });

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  final _scrollController = ScrollController();

  /// The form's own half of the nested scroll view, picked up when the body is
  /// built so a refused save can bring the reasons card back into view.
  ScrollController? _innerScrollController;

  final Uuid uuid = const Uuid();

  TextEditingController nameController = TextEditingController();

  List<String> selectedTags = [];

  List<ControllerListItem> identifiersControllers = [
    ControllerListItem(id: "0", controller: TextEditingController()),
  ];

  bool useGlobalSettingsFiltering = true;
  bool? enableFiltering;
  bool? enableSafeBrowsing;
  bool? enableParentalControl;
  SafeSearch? safeSearch;

  final SafeSearch defaultSafeSearch = SafeSearch(
    enabled: false,
    bing: false,
    duckduckgo: false,
    ecosia: false,
    google: false,
    pixabay: false,
    yandex: false,
    youtube: false,
  );

  bool useGlobalSettingsServices = true;
  List<String> blockedServices = [];

  List<ControllerListItem> upstreamServers = [];

  bool _ignoreClientQueryLog = false;
  bool _ignoreClientStatistics = false;

  bool _enableDnsCache = false;
  final _dnsCacheField = TextEditingController();
  String? _dnsCacheError;

  BlockedServicesSchedule _blockedServicesSchedule = BlockedServicesSchedule();

  // VALIDATIONS
  bool _nameValid = true;
  bool _identifiersValid = true;
  bool _dnsCacheValid = true;

  void enableDisableGlobalSettingsFiltering() {
    if (useGlobalSettingsFiltering == true) {
      setState(() {
        useGlobalSettingsFiltering = false;

        enableFiltering = false;
        enableSafeBrowsing = false;
        enableParentalControl = false;
        safeSearch = defaultSafeSearch;
      });
    } else if (useGlobalSettingsFiltering == false) {
      setState(() {
        useGlobalSettingsFiltering = true;

        enableFiltering = null;
        enableSafeBrowsing = null;
        enableParentalControl = null;
        safeSearch = null;
      });
    }
  }

  @override
  void initState() {
    if (widget.client != null) {
      nameController.text = widget.client!.name;
      selectedTags = widget.client!.tags;
      identifiersControllers = widget.client!.ids
          .map(
            (e) => ControllerListItem(
              id: uuid.v4(),
              controller: TextEditingController(text: e),
            ),
          )
          .toList();
      useGlobalSettingsFiltering = widget.client!.useGlobalSettings;
      enableFiltering = widget.client!.filteringEnabled;
      enableParentalControl = widget.client!.parentalEnabled;
      enableSafeBrowsing = widget.client!.safebrowsingEnabled;
      safeSearch = widget.client!.safeSearch;
      useGlobalSettingsServices = widget.client!.useGlobalBlockedServices;
      blockedServices = widget.client!.blockedServices;
      upstreamServers = widget.client!.upstreams
          .map(
            (e) => ControllerListItem(
              id: uuid.v4(),
              controller: TextEditingController(text: e),
            ),
          )
          .toList();
      _ignoreClientQueryLog = widget.client!.ignoreQuerylog ?? false;
      _ignoreClientStatistics = widget.client!.ignoreStatistics ?? false;
      _enableDnsCache = widget.client!.upstreamsCacheEnabled ?? false;
      _dnsCacheField.text = widget.client!.upstreamsCacheSize != null
          ? widget.client!.upstreamsCacheSize.toString()
          : "";
      if (widget.client!.blockedServicesSchedule != null) {
        _blockedServicesSchedule = widget.client!.blockedServicesSchedule!;
      }
    }
    if (widget.initialData != null) {
      nameController.text = widget.initialData!.name;
      identifiersControllers[0] = ControllerListItem(
        id: uuid.v4(),
        controller: TextEditingController(text: widget.initialData!.ip),
      );
    }
    super.initState();
  }

  @override
  void dispose() {
    // The identifier and upstream rows are made and thrown away as the user
    // types, so whatever is still in the lists when the page goes is what has
    // to be released; each one owns an edit box the framework cannot free.
    for (final item in identifiersControllers) {
      item.controller.dispose();
    }
    for (final item in upstreamServers) {
      item.controller.dispose();
    }
    nameController.dispose();
    _dnsCacheField.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final clientsProvider = Provider.of<ClientsProvider>(context);

    void createClient() {
      final Client client = Client(
        name: nameController.text,
        ids: List<String>.from(
          identifiersControllers.map((e) => e.controller.text),
        ),
        useGlobalSettings: useGlobalSettingsFiltering,
        filteringEnabled: enableFiltering ?? false,
        parentalEnabled: enableParentalControl ?? false,
        safebrowsingEnabled: enableSafeBrowsing ?? false,
        safeSearch: safeSearch,
        useGlobalBlockedServices: useGlobalSettingsServices,
        blockedServices: blockedServices,
        // An empty row left in the list is not an upstream the server can
        // take, so the rows nobody filled in are dropped rather than sent as
        // "" and rejected with a failure that names nothing.
        upstreams: upstreamServers
            .map((e) => e.controller.text.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        // The form draws no field for the rules of the device, so the ones it
        // carries are written back as they are.
        rules: widget.client?.rules ?? const [],
        tags: selectedTags,
        ignoreQuerylog: _ignoreClientQueryLog,
        ignoreStatistics: _ignoreClientStatistics,
        upstreamsCacheEnabled: _enableDnsCache,
        upstreamsCacheSize:
            _dnsCacheField.text != "" ? int.parse(_dnsCacheField.text) : null,
        blockedServicesSchedule: _blockedServicesSchedule,
      );
      widget.onConfirm(client);
    }

    void validateValues() {
      _nameValid = nameController.text != '';
      _identifiersValid = identifiersControllers.isNotEmpty &&
          identifiersControllers.every(
            (e) => e.controller.text.trim().isNotEmpty,
          );
      _dnsCacheValid = validateNumber(_dnsCacheField.text);
      if (_nameValid && _identifiersValid && _dnsCacheValid) {
        createClient();
        Navigator.pop(context);
      } else {
        // Both halves of the nested scroll view go back to the top: growing the
        // bar alone leaves the reasons card off screen, and animating the inner
        // half of a [NestedScrollView] leaves a driven activity behind that
        // outlives the page. Jumping is instant anyway, which is what a refused
        // save should feel like.
        final inner = _innerScrollController;
        for (final controller in [
          if (_scrollController.hasClients) _scrollController,
          if (inner != null && inner.hasClients) inner,
        ]) {
          controller.jumpTo(0);
        }
        setState(() => {});
      }
    }

    void remove() => openDeleteClientScreen(
          context: context,
          onDelete: () async {
            final result =
                await clientsProvider.deleteClient(widget.client!);

            if (!context.mounted) return;

            AppleToast.show(
              context,
              message: result
                  ? l.clientDeletedSuccessfully
                  : l.clientNotDeleted,
              accent: result ? p.green : p.red,
            );

            // The entry is gone, so this form has nothing left to edit.
            if (result == true) Navigator.pop(context);
          },
        );

    Widget form() => ClientForm(
          client: widget.client,
          nameController: nameController,
          identifiersControllers: identifiersControllers,
          selectedTags: selectedTags,
          useGlobalSettingsFiltering: useGlobalSettingsFiltering,
          enableFiltering: enableFiltering,
          enableParentalControl: enableParentalControl,
          enableSafeBrowsing: enableSafeBrowsing,
          safeSearch: safeSearch,
          blockedServices: blockedServices,
          updateBlockedServices: (v) => setState(() => blockedServices = v),
          upstreamServers: upstreamServers,
          updateUpstreamServers: (v) => setState(() => upstreamServers = v),
          defaultSafeSearch: defaultSafeSearch,
          useGlobalSettingsServices: useGlobalSettingsServices,
          updateSelectedTags: (v) => setState(() => selectedTags = v),
          updateIdentifiersControllers: (v) =>
              setState(() => identifiersControllers = v),
          enableDisableGlobalSettingsFiltering:
              enableDisableGlobalSettingsFiltering,
          updateEnableFiltering: (v) => setState(() => enableFiltering = v),
          updateEnableParentalControl: (v) =>
              setState(() => enableParentalControl = v),
          updateEnableSafeBrowsing: (v) =>
              setState(() => enableSafeBrowsing = v),
          updateSafeSearch: (v) => setState(() => safeSearch = v),
          updateUseGlobalSettingsServices: (v) =>
              setState(() => useGlobalSettingsServices = v),
          ignoreClientQueryLog: _ignoreClientQueryLog,
          ignoreClientStatistics: _ignoreClientStatistics,
          updateIgnoreClientQueryLog: (v) =>
              setState(() => _ignoreClientQueryLog = v),
          updateIgnoreClientStatistics: (v) =>
              setState(() => _ignoreClientStatistics = v),
          enableDnsCache: _enableDnsCache,
          updateEnableDnsCache: (v) => setState(() => _enableDnsCache = v),
          dnsCacheField: _dnsCacheField,
          dnsCacheError: _dnsCacheError,
          updateDnsCacheError: (v) => setState(() => _dnsCacheError = v),
          blockedServicesSchedule: _blockedServicesSchedule,
          setBlockedServicesSchedule: (v) =>
              setState(() => _blockedServicesSchedule = v),
        );

    final errors = !_nameValid || !_identifiersValid || !_dnsCacheValid
        ? _Errors(
            nameValid: _nameValid,
            identifiersValid: _identifiersValid,
            dnsCacheValid: _dnsCacheValid,
          )
        : null;

    final title =
        widget.client != null ? l.client : l.addClient;

    if (widget.fullScreen == true) {
      return AppleScreen(
        title: title,
        scrollController: _scrollController,
        leading: AppleHeaderAction(
          label: l.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          AppleHeaderAction(label: l.save, onPressed: validateValues),
          if (widget.client != null)
            AppleHeaderAction(
              label: l.delete,
              destructive: true,
              onPressed: remove,
            ),
        ],
        // The form scrolls inside the nested body of [AppleScreen], which
        // parks it under the pinned title bar unless it gives that overlap
        // back first: without the injector the name field was hidden.
        body: Builder(
          builder: (context) {
            _innerScrollController = PrimaryScrollController.maybeOf(context);
            return CustomScrollView(
              slivers: [
                SliverOverlapInjector(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
                if (errors != null) SliverToBoxAdapter(child: errors),
                SliverToBoxAdapter(child: form()),
              ],
            );
          },
        ),
      );
    }

    return AppleFormModal(
      title: title,
      icon: CupertinoIcons.person,
      dialog: true,
      maxWidth: 500,
      trailing: IconButton(
        tooltip: l.close,
        onPressed: () => Navigator.pop(context),
        icon: Icon(CupertinoIcons.xmark, size: 18, color: p.label2),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              children: [if (errors != null) errors, form()],
            ),
          ),
          AppleFormFooter(
            confirmLabel: l.save,
            onConfirm: validateValues,
            cancelLabel: l.cancel,
            leading: widget.client != null
                ? IconButton(
                    tooltip: l.delete,
                    onPressed: remove,
                    icon: Icon(CupertinoIcons.trash, size: 20, color: p.red),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// The reasons a save was refused, in one tinted card at the top of the form.
class _Errors extends StatelessWidget {
  final bool nameValid;
  final bool identifiersValid;
  final bool dnsCacheValid;

  const _Errors({
    required this.nameValid,
    required this.identifiersValid,
    required this.dnsCacheValid,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    final messages = <String>[
      if (!nameValid) l.nameInvalid,
      if (!identifiersValid) l.oneIdentifierRequired,
      if (!dnsCacheValid) l.dnsCacheNumber,
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.exclamationmark_circle_fill,
                size: 18,
                color: p.red,
              ),
              const SizedBox(width: 8),
              Text(
                l.errors,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: p.label,
                ),
              ),
            ],
          ),
          for (final message in messages)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 26),
              child: Text(
                message,
                style: TextStyle(fontSize: 13.5, color: p.label2),
              ),
            ),
        ],
      ),
    );
  }
}
