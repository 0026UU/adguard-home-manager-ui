import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';
import 'package:adguard_home_manager/screens/logs/filters/added_client_id_selection_modal.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

class _ClientLog {
  final String? name;
  final List<String> ids;

  const _ClientLog({
    required this.name,
    required this.ids,
  });

  /// The label a query-log row carries for this client: the configured name
  /// when it has one, else the address its queries come from.  An id the log
  /// never writes, a MAC above all, would narrow the log to nothing.
  String get logKey => (name != null && name!.isNotEmpty) ? name! : ids[0];
}

/// Multi-choice picker of the clients a log search can be restricted to.
///
/// The selection lives in [LogsProvider], so the rows read and write it there.
class ClientsModal extends StatefulWidget {
  final bool dialog;

  const ClientsModal({super.key, required this.dialog});

  @override
  State<ClientsModal> createState() => _ClientsModalState();
}

class _ClientsModalState extends State<ClientsModal> {
  List<_ClientLog> _filteredClients = [];
  final _searchController = TextEditingController();
  int _selectedList = 0;

  @override
  void initState() {
    final clientsProvider =
        Provider.of<ClientsProvider>(context, listen: false);
    _filteredClients = clientsProvider.clients!.autoClients.map((e) {
      String? name;
      for (final configured in clientsProvider.clients!.clients) {
        if (configured.ids.contains(e.ip)) {
          name = configured.name;
          break;
        }
      }
      return _ClientLog(name: name ?? e.name, ids: [e.ip]);
    }).toList();

    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);
    final clientsProvider = Provider.of<ClientsProvider>(context);
    final logsProvider = Provider.of<LogsProvider>(context);

    void onSearch({required String value, int? selectedList}) {
      if ((selectedList ?? _selectedList) == 1) {
        final filtered = clientsProvider.clients!.clients
            .map((e) => _ClientLog(name: e.name, ids: e.ids))
            .toList();
        setState(() => _filteredClients = filtered);
      } else {
        final filtered = clientsProvider.clients!.autoClients.map((e) {
          String? name;
          for (final configured in clientsProvider.clients!.clients) {
            if (configured.ids.contains(e.ip)) {
              name = configured.name;
              break;
            }
          }
          return _ClientLog(name: name ?? e.name, ids: [e.ip]);
        }).toList();
        setState(() => _filteredClients = filtered);
      }
    }

    void onListChange(int list) {
      onSearch(value: _searchController.text, selectedList: list);
    }

    void searchAddedClient(String id) {
      logsProvider.setSearchText(id);
      logsProvider.filterLogs();
      Navigator.of(context).pop();
      Navigator.pop(context);
    }

    return AppleFormModal(
      title: l.clients,
      icon: CupertinoIcons.wifi,
      dialog: widget.dialog,
      maxWidth: 500,
      trailing: widget.dialog
          ? AppleFormButton(
              label: l.close,
              background: Colors.transparent,
              foreground: p.tint,
              width: 74,
              onPressed: () => Navigator.pop(context),
            )
          : null,
      body: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 8),
        children: [
          AppleSearchField(
            controller: _searchController,
            hint: l.search,
            onChanged: (value) => onSearch(value: value),
          ),
          AppleCaption(
            l.selectClientsFiltersInfo,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: AppleSegmented(
              labels: [l.activeClients, l.added],
              selectedIndex: _selectedList,
              onChanged: (index) {
                onListChange(index);
                setState(() => _selectedList = index);
              },
            ),
          ),
          AppleListSection(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (var index = 0; index < _filteredClients.length; index++)
                _ListItem(
                  title: _selectedList == 0
                      ? _filteredClients[index].ids[0]
                      : _filteredClients[index].name ?? "",
                  subtitle: _selectedList == 0
                      ? _filteredClients[index].name
                      : _filteredClients[index].ids.join(", "),
                  checkboxActive: _filteredClients[index]
                      .ids
                      .any((id) => logsProvider.selectedClients.contains(id))
                      || logsProvider.selectedClients
                          .contains(_filteredClients[index].logKey),
                  ids: _filteredClients[index].ids,
                  isAddedClient: _selectedList == 1,
                  onSearchAddedClient: searchAddedClient,
                  onChanged: (isSelected) {
                    if (isSelected == true) {
                      logsProvider.setSelectedClients([
                        ...logsProvider.selectedClients,
                        _filteredClients[index].logKey
                      ]);
                    } else {
                      logsProvider.setSelectedClients(logsProvider
                          .selectedClients
                          .where((item) =>
                              !_filteredClients[index].ids.contains(item)
                              && item != _filteredClients[index].logKey)
                          .toList());
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool checkboxActive;
  final void Function(bool) onChanged;
  final List<String> ids;
  final bool isAddedClient;
  final void Function(String id)? onSearchAddedClient;

  const _ListItem({
    required this.title,
    this.subtitle,
    required this.checkboxActive,
    required this.onChanged,
    required this.ids,
    required this.isAddedClient,
    required this.onSearchAddedClient,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    void showIdSelectionModal() {
      showDialog(
          context: context,
          builder: (context) => AddedClientIdSelectionModal(
                clientIds: ids,
                onConfirm: (id) {
                  if (onSearchAddedClient != null) {
                    onSearchAddedClient!(id);
                  }
                },
              ));
    }

    if (isAddedClient == true) {
      return AppleListTile(
        title: title,
        subtitle: subtitle,
        showChevron: false,
        trailing: AppleFormButton(
          label: l.select,
          background: Colors.transparent,
          foreground: p.tint,
          width: 74,
          onPressed: showIdSelectionModal,
        ),
      );
    } else {
      return AppleListTile(
        title: title,
        subtitle: subtitle,
        showChevron: false,
        // Tapping anywhere on the row ticks it, like the system lists.
        onTap: () => onChanged(!checkboxActive),
        trailing: SizedBox(
          width: 24,
          child: checkboxActive
              ? Icon(CupertinoIcons.checkmark, size: 20, color: p.tint)
              : null,
        ),
      );
    }
  }
}
