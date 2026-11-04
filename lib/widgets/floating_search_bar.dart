import 'package:flutter/material.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/widgets/apple/apple.dart';

/// Search field that drops in over the bar it was opened from, like the system
/// lists. Submitting closes it again.
class FloatingSearchBar extends StatefulWidget {
  final void Function(String) onSearchCompleted;
  final RenderBox? searchButtonRenderBox;
  final String? existingSearchValue;
  final void Function(String)? onSearchFieldUpdated;

  const FloatingSearchBar({
    super.key,
    required this.onSearchCompleted,
    required this.searchButtonRenderBox,
    this.existingSearchValue,
    this.onSearchFieldUpdated,
  });

  @override
  State<FloatingSearchBar> createState() => _SearchState();
}

class _SearchState extends State<FloatingSearchBar> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    if (widget.existingSearchValue != null) {
      _searchController.text = widget.existingSearchValue!;
    }

    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final position = widget.searchButtonRenderBox?.localToGlobal(Offset.zero);
    final topPadding =
        MediaQuery.of(globalNavigatorKey.currentContext!).viewPadding.top;

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Material(
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth - 32 > 500
                ? 500
                : constraints.maxWidth - 32;

            return Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: position != null ? position.dy - topPadding : topPadding,
                  child: SizedBox(
                    width: width,
                    // Taps on the field must not reach the dismiss handler.
                    child: GestureDetector(
                      onTap: () => {},
                      child: AppleSearchField(
                        controller: _searchController,
                        hint: l.search,
                        autofocus: true,
                        onChanged: (value) =>
                            widget.onSearchFieldUpdated?.call(value),
                        onSubmit: () {
                          widget.onSearchCompleted(_searchController.text);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }
}
