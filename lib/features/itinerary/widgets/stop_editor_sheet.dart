import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/itinerary/models/stop_display.dart';
import 'package:xplore/features/itinerary/services/place_search_service.dart';
import 'package:xplore/features/itinerary/widgets/custom_stop_sheet.dart';
import 'package:xplore/features/itinerary/widgets/edit_fields.dart';
import 'package:xplore/features/itinerary/widgets/itinerary_confirmations.dart';
import 'package:xplore/features/itinerary/widgets/stop_form_fields.dart';
import 'package:xplore/features/itinerary/widgets/stop_place_search_sheet.dart';

const _photoTileSize = 56.0;
const _changePillHeight = 44.0;

// Every flow below hands its edit to the cubit with `unawaited`: saves show on the page at once, and their
// futures may never complete while offline, so a sheet must never wait on one.

/// Lets the person add a stop to day [dayIndex]: place search first, with a
/// custom stop as the fallback. Completes when the flow closes, with or without a new stop.
Future<void> showAddStopFlow(BuildContext context, {required int dayIndex}) async {
  final cubit = context.read<ItineraryCubit>();
  final day = _dayAt(cubit.state, dayIndex);
  if (day == null) {
    return;
  }
  final service = context.read<PlaceSearchService>();

  var query = '';
  while (true) {
    if (!context.mounted) {
      return;
    }
    final choice = await showStopPlaceSearch(
      context,
      service: service,
      purpose: StopSearchPurpose.add,
      near: day.location,
      initialQuery: query,
    );
    switch (choice) {
      case null:
        return;
      case StopSearchPlacePicked(:final place):
        unawaited(cubit.addLocation(dayIndex, stopFromPlace(place)));
        return;
      case StopSearchCustomRequested(query: final typed):
        if (!context.mounted) {
          return;
        }
        final outcome = await showCustomStopSheet(context, submitLabel: 'Add stop', initialName: typed);
        switch (outcome) {
          case null:
            return;
          case CustomStopSubmitted(:final name, :final note):
            unawaited(cubit.addLocation(dayIndex, customStop(name, note: note)));
            return;
          case CustomStopSearchInstead(:final name):
            query = name;
        }
    }
  }
}

/// Opens the editor for the stop at [stopIndex] of day [dayIndex]: change its
/// place or name, edit its note, or delete it. Does nothing if that stop does not exist.
Future<void> showStopEditor(BuildContext context, {required int dayIndex, required int stopIndex}) async {
  final cubit = context.read<ItineraryCubit>();
  final day = _dayAt(cubit.state, dayIndex);
  final stops = day?.plan.locations ?? const <LocationPlanModel>[];
  if (day == null || stopIndex < 0 || stopIndex >= stops.length) {
    return;
  }
  final service = context.read<PlaceSearchService>();

  final result = await showEditSheet<_StopEditorResult>(
    context,
    builder: (_) => _StopEditor(stop: stops[stopIndex], service: service, near: day.location),
  );
  switch (result) {
    case null:
      return;
    case _SaveStop(:final stop):
      unawaited(cubit.updateLocation(dayIndex, stopIndex, stop));
    case _DeleteStop():
      unawaited(cubit.removeLocation(dayIndex, stopIndex));
  }
}

DailyPlanModel? _dayAt(ItineraryStates state, int dayIndex) {
  if (state is! LoadedItineraryState) {
    return null;
  }
  final plans = state.itinerary.dailyPlans;
  return dayIndex >= 0 && dayIndex < plans.length ? plans[dayIndex] : null;
}

/// What the editor asks the caller to write once it has closed.
sealed class _StopEditorResult {
  const _StopEditorResult();
}

final class _SaveStop extends _StopEditorResult {
  const _SaveStop(this.stop);

  final LocationPlanModel stop;
}

final class _DeleteStop extends _StopEditorResult {
  const _DeleteStop();
}

class _StopEditor extends StatefulWidget {
  const _StopEditor({required this.stop, required this.service, required this.near});

  final LocationPlanModel stop;
  final PlaceSearchService service;
  final String near;

  @override
  State<_StopEditor> createState() => _StopEditorState();
}

class _StopEditorState extends State<_StopEditor> {
  // The real place the stop will point at, with its saved details; null while it is a custom stop.
  late LocationPlanModel? _place = widget.stop.isCustom ? null : widget.stop;
  late final _name = TextEditingController(text: widget.stop.isCustom ? widget.stop.name : '');
  late final _note = TextEditingController(text: widget.stop.description);

  bool get _canSave => _place != null || _name.text.trim().isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _searchForPlace() async {
    final choice = await showStopPlaceSearch(
      context,
      service: widget.service,
      purpose: StopSearchPurpose.change,
      near: widget.near,
      // From a custom stop, its name is the best guess at the place it should be.
      initialQuery: _place == null ? _name.text : '',
    );
    if (!mounted || choice == null) {
      return;
    }
    setState(() {
      switch (choice) {
        case StopSearchPlacePicked(:final place):
          _place = stopFromPlace(place);
        case StopSearchCustomRequested(:final query):
          final fallback = _place?.name ?? _name.text;
          _name.text = query.isEmpty ? fallback : query;
          _place = null;
      }
    });
  }

  void _save() {
    final original = widget.stop;
    final note = _note.text.trim();
    final place = _place;
    final edited = place == null
        ? customStop(_name.text, note: note, completed: original.completed)
        : place.copyWith(description: note, completed: original.completed);
    // The change record is rewritten by the cubit on every save, so it says nothing about whether anything changed.
    final changed = edited.copyWith(lastChange: null) != original.copyWith(lastChange: null);
    Navigator.of(context).pop(changed ? _SaveStop(edited) : null);
  }

  Future<void> _delete() async {
    final confirmed = await confirmDeleteStop(context, stopName: widget.stop.name);
    if (confirmed && mounted) {
      Navigator.of(context).pop(const _DeleteStop());
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = _place;
    return EditSheetBody(
      title: 'Edit stop',
      children: [
        if (place != null) ...[
          const SizedBox(height: 16),
          _PlaceCard(place: place, onChange: _searchForPlace),
        ] else ...[
          const SizedBox(height: stopSheetSectionGap),
          StopNameField(controller: _name, onChanged: (_) => setState(() {})),
        ],
        const SizedBox(height: stopSheetSectionGap),
        StopNoteField(controller: _note),
        const SizedBox(height: 24),
        StopPrimaryButton(label: 'Save', onPressed: _canSave ? _save : null),
        const SizedBox(height: 4),
        if (place == null) StopSecondaryButton(label: 'Search for a place instead', onPressed: _searchForPlace),
        StopSecondaryButton(label: 'Delete stop', color: XploreColors.error, onPressed: _delete),
      ],
    );
  }
}

/// The real place a stop points at: a photo tile, its name and details, and a "Change" pill.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onChange});

  final LocationPlanModel place;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final summary = placeSummary(category: place.category, neighbourhood: place.neighbourhood);
    final hours = openingHoursLabel(place.openingHours);
    final detailStyle = XploreText.footnote.copyWith(color: XploreColors.secondaryLabel);

    return Container(
      padding: const EdgeInsets.all(paddingUnit),
      decoration: BoxDecoration(color: XploreColors.raised, borderRadius: BorderRadius.circular(radiusMd)),
      child: Row(
        children: [
          const _PhotoTile(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  place.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: XploreText.bodyStrong.copyWith(color: XploreColors.white),
                ),
                if (summary.isNotEmpty) Text(summary, style: detailStyle),
                if (hours != null) Text(hours, style: detailStyle),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              backgroundColor: XploreColors.accentSoft,
              foregroundColor: XploreColors.accent,
              minimumSize: const Size(0, _changePillHeight),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: const StadiumBorder(),
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}

/// Stands in for the place photo: stage 1 has no photo source, so it shows a neutral place icon.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: _photoTileSize,
        height: _photoTileSize,
        decoration: BoxDecoration(color: XploreColors.separator, borderRadius: BorderRadius.circular(radiusSm)),
        child: const Icon(Icons.place_outlined, size: 24, color: XploreColors.secondaryLabel),
      ),
    );
  }
}
