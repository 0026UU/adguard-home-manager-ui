import 'package:adguard_home_manager/constants/regexps.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/apple/apple.dart';


class _IpListItemController {
  final String id;
  final TextEditingController controller;
  bool error;

  _IpListItemController({
    required this.id,
    required this.controller,
    required this.error
  });
}

class RateLimitAllowlistModal extends StatefulWidget {
  final List<String> values;
  final void Function(List<String>) onConfirm;

  const RateLimitAllowlistModal({
    super.key,
    required this.values,
    required this.onConfirm,
  });

  @override
  State<RateLimitAllowlistModal> createState() => _RateLimitAllowlistModalState();
}

class _RateLimitAllowlistModalState extends State<RateLimitAllowlistModal> {
  final Uuid uuid = const Uuid();
  List<_IpListItemController> _controllersList = [];

  void _validateIp(String value, _IpListItemController item) {
    if (Regexps.ipv4Address.hasMatch(value)) {
      setState(() => _controllersList = _controllersList.map((e) {
        if (e.id == item.id) {
          return _IpListItemController(
            id: e.id, 
            controller: e.controller, 
            error: false
          );
        }
        return e;
      }).toList());
    }
    else {
      setState(() => _controllersList = _controllersList.map((e) {
        if (e.id == item.id) {
          return _IpListItemController(
            id: e.id, 
            controller: e.controller, 
            error: true
          );
        }
        return e;
      }).toList());
    }
  }

  @override
  void initState() {
    _controllersList = widget.values.map((e) => _IpListItemController(
      id: uuid.v4(), 
      controller: TextEditingController(text: e), 
      error: false
    )).toList();

    super.initState();
  }
  
  @override
  Widget build(BuildContext context) {
    final validData = _controllersList.where((e) => e.error == true).isEmpty;
    final l = AppLocalizations.of(context)!;
    final p = ApplePalette.of(context);

    return AppleFormModal(
      title: l.rateLimitAllowlist,
      icon: CupertinoIcons.list_bullet,
      dialog: true,
      maxWidth: 500,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in _controllersList)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 6, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppleTextField(
                              label: l.ipAddress,
                              icon: CupertinoIcons.link,
                              controller: item.controller,
                              keyboardType: TextInputType.number,
                              error: item.error == true ? l.invalidIp : null,
                              onChanged: (v) => _validateIp(v, item),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(
                              () => _controllersList = _controllersList.where((c) => c.id != item.id).toList()
                            ), 
                            icon: Icon(
                              CupertinoIcons.minus_circle,
                              size: 19,
                              color: p.red,
                            ),
                            tooltip: l.remove,
                          )
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: AppleButton.secondary(
                      label: l.addItem,
                      icon: CupertinoIcons.plus,
                      onPressed: () => setState(() => _controllersList.add(
                        _IpListItemController(
                          id: uuid.v4(), 
                          controller: TextEditingController(),
                          error: false
                        ),
                      )),
                    ),
                  )
                ],
              ),
            )
          ),
          AppleFormFooter(
            confirmLabel: l.confirm,
            confirmEnabled: validData,
            onConfirm: () {
              widget.onConfirm(
                _controllersList.map((e) => e.controller.text).toList()
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}