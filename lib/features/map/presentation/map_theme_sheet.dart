import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/map/models/map_theme.dart';

/// Opens the map style picker and returns the chosen theme, or null when dismissed.
Future<MapTheme?> showMapThemeSheet(BuildContext context, {required MapTheme selected}) {
  return showModalBottomSheet<MapTheme>(
    context: context,
    backgroundColor: XploreColors.card,
    showDragHandle: true,
    builder: (_) => _MapThemeSheet(selected: selected),
  );
}

class _MapThemeSheet extends StatelessWidget {
  const _MapThemeSheet({required this.selected});

  final MapTheme selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Map style', style: XploreText.heading.copyWith(color: XploreColors.white)),
          ),
          for (final theme in MapTheme.values) _MapThemeRow(theme: theme, isSelected: theme == selected),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MapThemeRow extends StatelessWidget {
  const _MapThemeRow({required this.theme, required this.isSelected});

  final MapTheme theme;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(theme),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              _Swatch(theme: theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(theme.label, style: XploreText.bodyStrong.copyWith(color: XploreColors.white)),
                    const SizedBox(height: 2),
                    Text(theme.description, style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel)),
                  ],
                ),
              ),
              if (isSelected) const Icon(CupertinoIcons.checkmark_alt, size: 20, color: XploreColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// A miniature of the theme: land with a band of water and a patch of park.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.theme});

  final MapTheme theme;

  static const _size = 44.0;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: _size,
        height: _size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.land,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: XploreColors.separator),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _size * 0.36,
              child: ColoredBox(color: theme.water),
            ),
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: theme.park, borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
