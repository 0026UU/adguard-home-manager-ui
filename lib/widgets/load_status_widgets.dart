import 'package:flutter/cupertino.dart';

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
class ErrorLoadData extends StatelessWidget {
  final String text;

  const ErrorLoadData({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return Center(
      child: AppleEmptyState(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: text,
        color: p.orange,
      ),
    );
  }
}
