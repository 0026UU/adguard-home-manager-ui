import 'package:flutter/cupertino.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Placeholder shown while a settings section loads its values.
class LoadingData extends StatelessWidget {
  final String text;

  const LoadingData({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: AppleLoading(label: text),
    );
  }
}

/// Placeholder shown when a settings section could not be loaded.
///
/// [onRetry] is what makes the state recoverable: without it a failed load is
/// a dead end and the only way out is to leave the screen and come back.
class ErrorLoadData extends StatelessWidget {
  final String text;
  final Future<void> Function()? onRetry;

  const ErrorLoadData({
    super.key,
    required this.text,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final l = AppLocalizations.of(context)!;

    return Center(
      child: AppleEmptyState(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: text,
        color: p.orange,
        action: onRetry == null
            ? null
            : AppleButton(
                label: l.refresh,
                icon: CupertinoIcons.arrow_clockwise,
                color: p.tint,
                onPressed: onRetry,
              ),
      ),
    );
  }
}
