import 'package:flutter/cupertino.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Blocking alert shown while a request runs.
class ProcessDialog extends StatelessWidget {
  final String message;

  const ProcessDialog({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return PopScope(
      canPop: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 270),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ColoredBox(
              color: p.chromeSolid,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                child: Row(
                  children: [
                    const CupertinoActivityIndicator(radius: 10),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.3,
                          color: p.label,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
