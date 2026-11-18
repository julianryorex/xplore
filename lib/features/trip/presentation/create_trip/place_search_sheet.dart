import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/presentation/create_trip/create_trip_widgets.dart';

/// Opens a tall sheet to search [catalog] for a place to add, leaving out the
/// ids in [excludeIds]. Completes with the chosen place, or null when dismissed.
Future<CatalogPlace?> showPlaceSearchSheet(
  BuildContext context, {
  required Iterable<String> excludeIds,
  PlaceCatalog catalog = placeCatalog,
}) {
  return showModalBottomSheet<CatalogPlace>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: XploreColors.card,
    builder: (_) => _PlaceSearchSheet(excludeIds: excludeIds.toSet(), catalog: catalog),
  );
}

/// The search sheet's content: a search field over popular places or matches.
/// Pops with the tapped [CatalogPlace].
class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet({required this.excludeIds, required this.catalog});

  final Set<String> excludeIds;
  final PlaceCatalog catalog;

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final results = widget.catalog.search(_query, exclude: widget.excludeIds);
    final searching = _query.trim().isNotEmpty;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(createStepGutter, 0, createStepGutter, 12),
            child: Semantics(
              header: true,
              child: Text('Add a place', style: XploreText.heading.copyWith(color: XploreColors.white)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(createStepGutter, 0, createStepGutter, 12),
            child: _SearchField(onChanged: (value) => setState(() => _query = value)),
          ),
          Expanded(
            child: results.isEmpty && searching
                ? _NoMatches(bottomInset: keyboard)
                : ListView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    // The keyboard overlaps the sheet; pad so the last result can scroll above it.
                    padding: EdgeInsets.fromLTRB(createStepGutter, 8, createStepGutter, keyboard + 24),
                    children: [
                      if (!searching) ...[const CreateOverline('Popular'), const SizedBox(height: 6)],
                      for (final place in results)
                        _PlaceResult(place: place, onTap: () => Navigator.of(context).pop(place)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: true,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      textCapitalization: TextCapitalization.words,
      autocorrect: false,
      style: XploreText.body.copyWith(color: XploreColors.white),
      cursorColor: XploreColors.accent,
      decoration: InputDecoration(
        hintText: 'Search cities and countries',
        hintStyle: XploreText.body.copyWith(color: XploreColors.secondaryLabel),
        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: XploreColors.secondaryLabel),
        filled: true,
        fillColor: XploreColors.raised,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusSm), borderSide: BorderSide.none),
      ),
    );
  }
}

class _PlaceResult extends StatelessWidget {
  const _PlaceResult({required this.place, required this.onTap});

  final CatalogPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      hint: 'Adds ${place.name} to the trip',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: XploreColors.raised)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(place.name, style: XploreText.bodyStrong.copyWith(color: XploreColors.white)),
                    Text(place.country, style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel)),
                  ],
                ),
              ),
              const Icon(Icons.add_rounded, size: 20, color: XploreColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(createStepGutter, 32, createStepGutter, bottomInset),
      child: Column(
        children: [
          Text('No matches', style: XploreText.heading.copyWith(color: XploreColors.white)),
          const SizedBox(height: 6),
          Text(
            'Only well-known destinations are available for now.',
            textAlign: TextAlign.center,
            style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
          ),
        ],
      ),
    );
  }
}
