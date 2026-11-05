import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Single-field comment editor used by the DNS screens.
class CommentModal extends StatelessWidget {
  final String? comment;
  final void Function(String) onConfirm;
  final bool dialog;

  const CommentModal(
      {super.key, this.comment, required this.onConfirm, required this.dialog});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AppleFormModal(
      title: l.comment,
      icon: CupertinoIcons.textformat,
      dialog: dialog,
      body: _Content(comment: comment, onConfirm: onConfirm),
    );
  }
}

class _Content extends StatefulWidget {
  final String? comment;
  final void Function(String) onConfirm;

  const _Content({required this.comment, required this.onConfirm});

  @override
  State<_Content> createState() => __ContentState();
}

class __ContentState extends State<_Content> {
  final TextEditingController commentController = TextEditingController();

  bool validData = false;

  @override
  void initState() {
    if (widget.comment != null) {
      commentController.text =
          widget.comment!.replaceFirst(RegExp(r'#(\s)?'), "");
    }
    super.initState();
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextFormField(
                controller: commentController,
                style: AppleInput.style(context),
                onChanged: (value) =>
                    setState(() => validData = value.isNotEmpty),
                decoration: AppleInput.decoration(
                  context,
                  label: l.comment,
                  icon: CupertinoIcons.textformat,
                  helper: l.commentsDescription,
                  helperMaxLines: 3,
                ),
              ),
            ),
          ),
        ),
        AppleFormFooter(
          confirmLabel: l.confirm,
          confirmEnabled: validData,
          onConfirm: () {
            Navigator.pop(context);
            widget.onConfirm("# ${commentController.text}");
          },
        ),
      ],
    );
  }
}
