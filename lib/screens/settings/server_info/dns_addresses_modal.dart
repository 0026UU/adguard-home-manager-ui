import 'package:flutter/cupertino.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// The addresses the server answers on, read from `/status`.
class DnsAddressesModal extends StatelessWidget {
  final bool isDialog;
  final List<String> dnsAddresses;

  const DnsAddressesModal({
    super.key,
    required this.isDialog,
    required this.dnsAddresses,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AppleFormModal(
      title: l.dnsAddresses,
      icon: CupertinoIcons.globe,
      dialog: isDialog,
      maxWidth: 500,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: AppleListSection(
                  margin: EdgeInsets.zero,
                  children: [
                    for (final address in dnsAddresses)
                      AppleListTile(
                        title: address,
                        mono: true,
                        showChevron: false,
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: AppleButton(
              label: l.close,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
