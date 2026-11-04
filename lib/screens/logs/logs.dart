// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:adguard_home_manager/screens/logs/logs_list.dart';
import 'package:adguard_home_manager/screens/logs/details/log_details_screen.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/providers/live_logs_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';

class Logs extends StatefulWidget {
  const Logs({super.key});

  @override
  State<Logs> createState() => _LogsState();
}

class _LogsState extends State<Logs> {
  Log? _selectedLog;

  @override
  void initState() {
    Provider.of<FilteringProvider>(context, listen: false).fetchFilters();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ApplePalette.of(context);

    // The live stream belongs to this screen: it is created with it and stops
    // with it.
    return ChangeNotifierProxyProvider<ServersProvider, LiveLogsProvider>(
      create: (context) => LiveLogsProvider(),
      update: (context, servers, logs) => logs!..update(servers),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Material(
              color: palette.card,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: LogsListWidget(
                      twoColumns: true,
                      selectedLog: _selectedLog,
                      onLogSelected: (log) => setState(() => _selectedLog = log),
                    )
                  ),
                  SizedBox(
                    width: 0.5,
                    child: ColoredBox(color: palette.separator),
                  ),
                  Expanded(
                    flex: 3,
                    child: _selectedLog != null
                      ? LogDetailsScreen(
                          log: _selectedLog!,
                          dialog: false,
                          twoColumns: true,
                        )
                      : const SizedBox()
                  )
                ],
              ),
            );
          }
          else {
            return LogsListWidget(
              twoColumns: false,
              selectedLog: _selectedLog,
              onLogSelected: (log) => setState(() => _selectedLog = log),
            );
          }
        },
      ),
    );
  }
}