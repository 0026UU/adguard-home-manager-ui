import 'package:adguard_home_manager/models/rewrite_status.dart';
import 'package:flutter/material.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/error_reason.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/models/rewrite_rules.dart';

class RewriteRulesProvider with ChangeNotifier, ErrorReason {
  ServersProvider? _serversProvider;

  void update(ServersProvider? provider) {
    _serversProvider = provider;
  }

  LoadStatus _loadStatus = LoadStatus.loading;
  List<RewriteRules>? _rewriteRules;
  RewriteStatus? _rewriteStatus;

  LoadStatus get loadStatus {
    return _loadStatus;
  }

  RewriteStatus? get rewriteStatus {
    return _rewriteStatus;
  }

  List<RewriteRules>? get rewriteRules {
    return _rewriteRules;
  }

  void setRewriteRulesData(List<RewriteRules> data) {
    _rewriteRules = data;
    notifyListeners();
  }

  void setRewriteRulesLoadStatus(LoadStatus status, bool notify) {
    _loadStatus = status;
    if (notify == true) {
      notifyListeners();
    }
  }

  void setRewriteStatusData(RewriteStatus status) {
    _rewriteStatus = status;
    notifyListeners();
  }

  Future<bool> addDnsRewrite(RewriteRules rule) async {
    final result = await _serversProvider!.apiClient2!.addDnsRewriteRule(
      data: {
        "domain": rule.domain,
        "answer": rule.answer
      }
    );
    captureErrorReason(result);

    if (result.successful == true) {
      if (rewriteRules == null) {
        return setFailureReason(
          'the rule was written but the list it belongs to was never loaded',
        );
      }

      List<RewriteRules> data = rewriteRules!;
      data.add(rule);
      setRewriteRulesData(data);
      return true;
    }
    else {
      notifyListeners();
      return false;
    }
  }

  Future<bool> editDnsRewrite(RewriteRules newRule, RewriteRules oldRule) async {
    final result = await _serversProvider!.apiClient2!.updateRewriteRule(
      body: {
        "target": {
          "answer": oldRule.answer,
          "domain": oldRule.domain,
          "enabled": oldRule.enabled
        },
        "update": {
          "answer": newRule.answer,
          "domain": newRule.domain,
          "enabled": newRule.enabled
        }
      }
    );
    captureErrorReason(result);

    if (result.successful == true) {
      List<RewriteRules> data = rewriteRules!;
      final index = data.indexOf(oldRule);
      data[index] = newRule;
      setRewriteRulesData(data);
      return true;
    }
    else {
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDnsRewrite(RewriteRules rule) async {
    final result = await _serversProvider!.apiClient2!.deleteDnsRewriteRule(
      data: {
        "domain": rule.domain,
        "answer": rule.answer
      }
    );
    captureErrorReason(result);

    if (result.successful == true) {
      List<RewriteRules> data = rewriteRules!;
      // One domain may carry several answers and the server deletes only the
      // pair that was posted, so the list loses that single entry as well.
      data.removeWhere(
        (item) => item.domain == rule.domain && item.answer == rule.answer
      );
      setRewriteRulesData(data);
      return true;
    }
    else {
      notifyListeners();
      return false;
    }
  }

  Future<bool> fetchData({
    bool? showLoading
  }) async {
    // Only worth announcing when it is a change: a retry fired from initState
    // would otherwise notify listeners while the page is still being built.
    if (showLoading == true && _loadStatus != LoadStatus.loading) {
      _loadStatus = LoadStatus.loading;
      notifyListeners();
    }

    final result = await Future.wait([
      _serversProvider!.apiClient2!.getDnsRewriteRules(),
      _serversProvider!.apiClient2!.getDnsRewriteSettings(),
    ]);

    // The two answers arrive together, so the page is told which of them the
    // server actually refused.
    const List<String> paths = ['/rewrite', '/rewrite/settings'];
    final int failed = result.indexWhere((element) => element.successful != true);
    if (failed == -1) {
      captureErrorReason(result.first);
    }
    else {
      captureErrorReason(
        result[failed],
        fallback: 'the server gave nothing back for ${paths[failed]}',
      );
    }

    if (result.every((element) => element.successful == true)) {
      _rewriteRules = result[0].content as List<RewriteRules>;
      _rewriteStatus = result[1].content as RewriteStatus;
      _loadStatus = LoadStatus.loaded;
      notifyListeners();
      return true;
    }
    else {
      // The error is recorded whether or not a spinner was promised. The toast
      // that goes with a failed refresh is easy to miss, and a rewrite table
      // left on screen after the server stopped answering reads as a list the
      // server still agrees with.
      _loadStatus = LoadStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future enableDisableRewriteRules(bool enabled) async {
    final result = await _serversProvider!.apiClient2!.updateDnsRewriteSettings(
      data: {
        "enabled": enabled
      }
    );
    captureErrorReason(result);

    if (result.successful == true) {
      _rewriteStatus = RewriteStatus(
        enabled: enabled
      );
      notifyListeners();
      return true;
    }
    else {
      notifyListeners();
      return false;
    }
  }
}