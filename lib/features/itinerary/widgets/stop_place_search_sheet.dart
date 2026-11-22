import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/itinerary/models/stop_display.dart';
import 'package:xplore/features/itinerary/services/place_search_service.dart';
import 'package:xplore/features/itinerary/widgets/edit_fields.dart';

const _gutter = 20.0;
const _sheetHeightFraction = 0.88;
const _debounce = Duration(milliseconds: 300);
const _rowMinHeight = 56.0;
// Matches the rows of the trip's place search sheet, a step quieter than the separator token.
const _hairline = XploreColors.raised;

/// Why the search sheet is open: it reads "Add a stop" when adding and
/// "Change place" when picking a replacement for an existing stop.
enum StopSearchPurpose { add, change }

/// What the person chose in the place search sheet.
sealed class StopSearchResult {
  const StopSearchResult();
}

/// A real place was picked.
final class StopSearchPlacePicked extends StopSearchResult {
  const StopSearchPlacePicked(this.place);

  final PlaceDetails place;
}

/// The person asked for a custom stop instead; [query] is what they had typed.
final class StopSearchCustomRequested extends StopSearchResult {
  const StopSearchCustomRequested(this.query);

  final String query;
}

/// Opens a tall sheet to search [service] for a place, suggesting places
/// around [near] until something is typed. Completes with the choice, or null when dismissed.
Future<StopSearchResult?> showStopPlaceSearch(
  BuildContext context, {
  required PlaceSearchService service,
  required StopSearchPurpose purpose,
  String near = '',
  String initialQuery = '',
}) {
  return showModalBottomSheet<StopSearchResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: XploreColors.card,
    builder: (_) =>
        _StopPlaceSearchSheet(service: service, purpose: purpose, near: near.trim(), initialQuery: initialQuery.trim()),
  );
}

/// The state of the results area.
sealed class _SearchState {
  const _SearchState();
}

final class _Searching extends _SearchState {
  const _Searching();
}

final class _Found extends _SearchState {
  const _Found(this.places);

  final List<PlaceDetails> places;
}

final class _Failed extends _SearchState {
  const _Failed();
}

class _StopPlaceSearchSheet extends StatefulWidget {
  const _StopPlaceSearchSheet({
    required this.service,
    required this.purpose,
    required this.near,
    required this.initialQuery,
  });

  final PlaceSearchService service;
  final StopSearchPurpose purpose;
  final String near;
  final String initialQuery;

  @override
  State<_StopPlaceSearchSheet> createState() => _StopPlaceSearchSheetState();
}

class _StopPlaceSearchSheetState extends State<_StopPlaceSearchSheet> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  _SearchState _state = const _Searching();
  Timer? _debounceTimer;

  // Bumped per request so a slow response to an older query never replaces a newer one.
  int _latestRequest = 0;

  String get _query => _controller.text.trim();

  @override
  void initState() {
    super.initState();
    unawaited(_search());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String _) {
    _debounceTimer?.cancel();
    setState(() => _state = const _Searching());
    _debounceTimer = Timer(_debounce, () => unawaited(_search()));
  }

  void _clear() {
    _controller.clear();
    _onQueryChanged('');
  }

  void _retry() {
    setState(() => _state = const _Searching());
    unawaited(_search());
  }

  Future<void> _search() async {
    final request = ++_latestRequest;
    _SearchState next;
    try {
      next = _Found(await widget.service.search(_query, near: widget.near));
    } on Exception {
      // Broader than PlaceSearchException: a real backend client may also surface raw I/O errors.
      next = const _Failed();
    }
    if (mounted && request == _latestRequest) {
      setState(() => _state = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final title = switch (widget.purpose) {
      StopSearchPurpose.add => 'Add a stop',
      StopSearchPurpose.change => 'Change place',
    };

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * _sheetHeightFraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 12),
            child: Semantics(
              header: true,
              child: Text(title, style: XploreText.heading.copyWith(color: XploreColors.white)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _gutter),
            child: _SearchField(controller: _controller, onChanged: _onQueryChanged, onClear: _clear),
          ),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              // The keyboard overlaps the sheet; pad so the last row can scroll above it.
              padding: EdgeInsets.fromLTRB(_gutter, 22, _gutter, keyboard + 24),
              children: [
                ..._resultsSection(),
                const SizedBox(height: 26),
                const EditOverline('Not a place?'),
                const SizedBox(height: 6),
                _CustomStopRow(
                  query: _query,
                  onTap: () => Navigator.of(context).pop(StopSearchCustomRequested(_query)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _resultsSection() {
    return switch (_state) {
      _Searching() => const [_SearchingIndicator()],
      _Failed() => [
        _SearchMessage(
          title: "Couldn't search places",
          message: 'Check your connection and try again.',
          action: TextButton(onPressed: _retry, child: const Text('Try again')),
        ),
      ],
      _Found(places: []) => const [
        _SearchMessage(title: 'No places found', message: 'Try another name, or add it as a custom stop.'),
      ],
      _Found(:final places) => [
        EditOverline(widget.near.isEmpty ? 'Places' : 'Near ${widget.near}'),
        const SizedBox(height: 6),
        for (final place in places)
          _PlaceRow(
            place: place,
            purpose: widget.purpose,
            onTap: () => Navigator.of(context).pop(StopSearchPlacePicked(place)),
          ),
      ],
    };
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged, required this.onClear});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      textCapitalization: TextCapitalization.words,
      autocorrect: false,
      style: XploreText.body.copyWith(color: XploreColors.white),
      cursorColor: XploreColors.accent,
      decoration: InputDecoration(
        hintText: 'Search places',
        hintStyle: XploreText.body.copyWith(color: XploreColors.secondaryLabel),
        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: XploreColors.secondaryLabel),
        suffixIcon: _ClearButton(controller: controller, onClear: onClear),
        filled: true,
        fillColor: XploreColors.raised,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusSm), borderSide: BorderSide.none),
      ),
    );
  }
}

/// Clears the search field; shown only while it has text.
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.controller, required this.onClear});

  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.text.isEmpty) {
          return const SizedBox.shrink();
        }
        return IconButton(
          onPressed: onClear,
          tooltip: 'Clear search',
          constraints: const BoxConstraints.tightFor(width: minTouchTarget, height: minTouchTarget),
          icon: const Icon(Icons.cancel_rounded, size: 18, color: XploreColors.tertiaryLabel),
        );
      },
    );
  }
}

/// A tappable row: a title over a supporting line, with a trailing icon.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.hint,
    required this.onTap,
    this.divider = true,
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final String hint;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      hint: hint,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: _rowMinHeight),
          decoration: divider
              ? const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _hairline)),
                )
              : null,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: XploreText.bodyStrong.copyWith(color: XploreColors.white),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ExcludeSemantics(child: trailing),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place, required this.purpose, required this.onTap});

  final PlaceDetails place;
  final StopSearchPurpose purpose;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ChoiceRow(
      title: place.name,
      subtitle: placeSummary(
        category: place.category,
        neighbourhood: place.neighbourhood,
        openingHours: place.openingHours,
        withHours: true,
      ),
      trailing: const Icon(Icons.add_rounded, size: 20, color: XploreColors.accent),
      hint: switch (purpose) {
        StopSearchPurpose.add => 'Adds ${place.name} to the day',
        StopSearchPurpose.change => 'Uses ${place.name} for this stop',
      },
      onTap: onTap,
    );
  }
}

class _CustomStopRow extends StatelessWidget {
  const _CustomStopRow({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ChoiceRow(
      title: query.isEmpty ? 'Add a custom stop' : 'Add “$query” as a custom stop',
      subtitle: 'No map pin, opening hours or directions',
      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: XploreColors.tertiaryLabel),
      hint: 'Opens the custom stop form',
      divider: false,
      onTap: onTap,
    );
  }
}

class _SearchingIndicator extends StatelessWidget {
  const _SearchingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5, semanticsLabel: 'Searching places'),
        ),
      ),
    );
  }
}

/// A centred heading and explanation standing in for results, with an optional [action].
class _SearchMessage extends StatelessWidget {
  const _SearchMessage({required this.title, required this.message, this.action});

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: XploreText.heading.copyWith(color: XploreColors.white),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
          ),
          if (action != null) ...[const SizedBox(height: 8), action],
        ],
      ),
    );
  }
}
