import 'package:flutter/cupertino.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/constants/urls.dart';
import 'package:adguard_home_manager/functions/open_url.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

class CustomRuleDocs extends StatelessWidget {
  const CustomRuleDocs({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    // The examples are code, so they wear the monospaced face in the accent;
    // what each one does sits under it in quiet secondary text.
    final ruleStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: p.tint,
    );
    final descStyle = TextStyle(fontSize: 13, color: p.label2);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(CupertinoIcons.info_circle, size: 20, color: p.label),
                    const SizedBox(width: 10),
                    Text(
                      l.examples,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: p.label,
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "||example.org^",
                        textAlign: TextAlign.left,
                        style: ruleStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(l.example1, style: descStyle),
                      const SizedBox(height: 16),
                      Text(
                        "@@||example.org^",
                        textAlign: TextAlign.left,
                        style: ruleStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(l.example2, style: descStyle),
                      const SizedBox(height: 16),
                      Text(
                        "! Here goes a comment",
                        textAlign: TextAlign.left,
                        style: ruleStyle,
                      ),
                      Text(
                        "# Also a comment",
                        textAlign: TextAlign.left,
                        style: ruleStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(l.example3, style: descStyle),
                      const SizedBox(height: 16),
                      Text(
                        "/REGEX/",
                        textAlign: TextAlign.left,
                        style: ruleStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(l.example4, style: descStyle),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        AppleListSection(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            AppleListTile(
              title: l.moreInformation,
              showChevron: false,
              trailing: Icon(
                CupertinoIcons.arrow_up_right,
                size: 18,
                color: p.label3,
              ),
              onTap: () => openUrl(Urls.customRuleDocs),
            ),
          ],
        ),
      ],
    );
  }
}
