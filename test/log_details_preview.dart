import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/config/apple_theme.dart';
import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/clients/client/tags_modal.dart';
import 'package:adguard_home_manager/screens/logs/details/log_details_screen.dart';

class PreviewStatus extends StatusProvider {
  bool failNext = false;

  PreviewStatus() {
    setFilteringStatus(FilteringStatus(
      filters: [], whitelistFilters: [], userRules: [], interval: 24, enabled: true,
    ));
  }

  @override
  Future<bool> blockUnblockDomain({required String domain, required String newStatus}) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final success = !failNext;
    failNext = false;
    return success;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppConfigProvider(sharedPreferencesInstance: prefs)),
      ChangeNotifierProvider<StatusProvider>(create: (_) => PreviewStatus()),
    ],
    child: const LogDetailsPreview(),
  ));
}

class LogDetailsPreview extends StatefulWidget {
  const LogDetailsPreview({super.key});

  @override
  State<LogDetailsPreview> createState() => _LogDetailsPreviewState();
}

class _LogDetailsPreviewState extends State<LogDetailsPreview> {
  bool dark = false;
  List<String> selectedTags = ['family'];

  Log _log({String reason = 'NotFilteredNotFound', bool missing = false}) => Log(
    cached: false,
    client: '192.168.1.20',
    clientInfo: ClientInfo(whois: Whois(), name: '客厅 Mac', disallowedRule: '', disallowed: false),
    clientProto: '53',
    elapsedMs: '1.234',
    question: Question(questionClass: 'IN', name: 'ads.example.com', type: 'A'),
    reason: reason,
    rules: [],
    time: DateTime.utc(2024, 5, 1, 12),
    upstream: '8.8.8.8:53',
    answer: missing ? [] : [Answer(type: 'A', value: '10.0.0.1', ttl: 300)],
    size: missing ? null : 124,
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    navigatorKey: globalNavigatorKey,
    scaffoldMessengerKey: scaffoldMessengerKey,
    theme: appleTheme(dark ? Brightness.dark : Brightness.light),
    locale: const Locale('zh', 'CN'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Builder(builder: (context) => Scaffold(
      body: SafeArea(child: Center(child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('日志详情组件预览 · 模拟后端，不修改服务器'),
            Text('当前标签：${selectedTags.isEmpty ? '无' : selectedTags.join('、')}'),
            TextButton(onPressed: () => showLogDetails(context, log: _log()), child: const Text('打开上游查询')),
            TextButton(onPressed: () => showLogDetails(context, log: _log(reason: 'FilteredBlackList')), child: const Text('打开已拦截查询')),
            TextButton(onPressed: () => showLogDetails(context, log: _log(missing: true)), child: const Text('打开缺失字段查询')),
            TextButton(onPressed: () {
              (context.read<StatusProvider>() as PreviewStatus).failNext = true;
              showLogDetails(context, log: _log());
            }, child: const Text('测试保存失败后重试')),
            TextButton(onPressed: () => setState(() => dark = !dark), child: const Text('切换深浅色')),
            TextButton(onPressed: () => showModalBottomSheet<void>(
              context: context,
              useRootNavigator: true,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              barrierColor: const Color(0x66000000),
              builder: (context) => TagsModal(
                selectedTags: selectedTags,
                tags: const ['family', 'work', 'iot', 'kids'],
                onConfirm: (tags) => setState(() => selectedTags = tags),
              ),
            ), child: const Text('打开标签选择')),
          ],
        ),
      ))),
    )),
  );
}
