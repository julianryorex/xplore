import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/trip/bloc/trip_creation_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_creation_state.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/models/trip_stop.dart';
import 'package:xplore/features/trip/presentation/create_trip/create_trip_widgets.dart';
import 'package:xplore/features/trip/presentation/create_trip/place_search_sheet.dart';
import 'package:xplore/features/trip/presentation/create_trip/route_map.dart';

// Popular places offered as one-tap chips before the trip has any.
const _firstPlaceSuggestions = 4;

const _rowHeight = 46.0;
const _railWidth = 16.0;
const _railGap = 18.0;

/// Step 1: the places in visiting order, on a route map and a reorderable
/// timeline, with search and one-tap suggestions for adding more.
class WhereStep extends StatefulWidget {
  const WhereStep({this.mapSurfaceBuilder, super.key});

  /// Replaces the Google Map in widget tests; see [RouteMapSurfaceBuilder].
  final RouteMapSurfaceBuilder? mapSurfaceBuilder;

  @override
  State<WhereStep> createState() => _WhereStepState();
}

class _WhereStepState extends State<WhereStep> {
  final _isSearching = ValueNotifier(false);

  @override
  void dispose() {
    _isSearching.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stops = context.select((TripCreationCubit cubit) => cubit.state.draft.stops);
    final canAddStop = context.select((TripCreationCubit cubit) => cubit.state.canAddStop);

    return BlocListener<TripCreationCubit, TripCreationState>(
      // A full trip cannot take a removed place back, so its undo offer would be dead.
      listenWhen: (previous, current) => previous.canAddStop && !current.canAddStop,
      listener: (context, _) => ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CreateStepTitle('Where to?'),
          const SizedBox(height: 18),
          ValueListenableBuilder<bool>(
            valueListenable: _isSearching,
            builder: (context, isSearching, map) => Visibility(
              visible: !isSearching,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: map!,
            ),
            child: RouteMap(stops: stops, surfaceBuilder: widget.mapSurfaceBuilder),
          ),
          const SizedBox(height: 14),
          _StopTimeline(stops: stops),
          _AddPlaceRow(enabled: canAddStop, continuesRail: stops.isNotEmpty, onTap: () => _searchAndAdd(context)),
          if (canAddStop) _PlaceSuggestions(stops: stops),
        ],
      ),
    );
  }

  Future<void> _searchAndAdd(BuildContext context) async {
    final cubit = context.read<TripCreationCubit>();
    _isSearching.value = true;
    final place = await showPlaceSearchSheet(
      context,
      excludeIds: cubit.state.draft.stops.map((stop) => stop.id),
      // The map would show through the sheet if it came back while the sheet is still sliding away.
      onClosed: () {
        if (mounted) _isSearching.value = false;
      },
    );
    if (place != null && !cubit.isClosed) {
      cubit.addStop(place);
    }
  }
}

class _StopTimeline extends StatelessWidget {
  const _StopTimeline({required this.stops});

  final List<TripStop> stops;

  @override
  Widget build(BuildContext context) {
    // The country only helps when the trip crosses borders.
    final showCountry = stopCountries(stops).length > 1;

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      buildDefaultDragHandles: false,
      itemCount: stops.length,
      onReorderStart: (_) => HapticFeedback.selectionClick(),
      // onReorderItem gives the final index; the cubit takes the pre-removal slot.
      onReorderItem: (from, to) => context.read<TripCreationCubit>().reorderStops(from, to > from ? to + 1 : to),
      proxyDecorator: (child, _, _) =>
          Material(color: XploreColors.card, borderRadius: BorderRadius.circular(radiusSm), child: child),
      itemBuilder: (context, index) {
        final stop = stops[index];
        return Dismissible(
          key: ValueKey(stop.id),
          direction: DismissDirection.endToStart,
          background: const _RemoveBackground(),
          onDismissed: (_) => _removeWithUndo(context, stop),
          child: Semantics(
            customSemanticsActions: {
              const CustomSemanticsAction(label: 'Remove'): () => _removeWithUndo(context, stop),
            },
            child: _StopRow(stop: stop, index: index, showCountry: showCountry),
          ),
        );
      },
    );
  }
}

/// Removes [stop] and offers to put it back where it was, with every stop's
/// nights as they were (removing re-splits exact-date nights).
void _removeWithUndo(BuildContext context, TripStop stop) {
  final cubit = context.read<TripCreationCubit>();
  final stopsBefore = cubit.state.draft.stops;
  cubit.removeStop(stop.id);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('${stop.name} removed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!cubit.isClosed) cubit.restoreStop(stop.id, stopsBefore: stopsBefore);
          },
        ),
        // A snackbar with an action stays until dismissed unless told otherwise.
        persist: false,
        duration: const Duration(seconds: 4),
      ),
    );
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop, required this.index, required this.showCountry});

  final TripStop stop;
  final int index;
  final bool showCountry;

  @override
  Widget build(BuildContext context) {
    return _TimelineRow(
      marker: const _StopMarker(),
      lineAbove: index > 0,
      lineBelow: true,
      trailing: ReorderableDragStartListener(
        index: index,
        child: const SizedBox.square(
          dimension: minTouchTarget,
          child: Icon(Icons.drag_handle_rounded, size: 20, color: XploreColors.tertiaryLabel),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(stop.name, style: XploreText.bodyStrong.copyWith(color: XploreColors.white)),
          if (showCountry && stop.country.isNotEmpty)
            Text(stop.country, style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel)),
        ],
      ),
    );
  }
}

class _AddPlaceRow extends StatelessWidget {
  const _AddPlaceRow({required this.enabled, required this.continuesRail, required this.onTap});

  final bool enabled;
  final bool continuesRail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled ? 'Add a place' : 'Add a place. Up to $maxTripStops places per trip',
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: _TimelineRow(
          marker: const _DashedMarker(),
          lineAbove: continuesRail,
          lineBelow: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add a place',
                style: XploreText.bodyStrong.copyWith(
                  color: enabled ? XploreColors.secondaryLabel : XploreColors.tertiaryLabel,
                ),
              ),
              if (!enabled)
                Text(
                  'Up to $maxTripStops places',
                  style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One timeline row: the rail with its [marker] on the left (the line joining
/// neighbouring rows above and below it), then [child], then [trailing].
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.marker,
    required this.lineAbove,
    required this.lineBelow,
    required this.child,
    this.trailing,
  });

  final Widget marker;
  final bool lineAbove;
  final bool lineBelow;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    Widget line(bool visible) => Expanded(
      child: visible
          ? const Center(
              child: SizedBox(width: 2, child: ColoredBox(color: XploreColors.raised)),
            )
          : const SizedBox(),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowHeight),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _railWidth,
              child: Column(children: [line(lineAbove), marker, line(lineBelow)]),
            ),
            const SizedBox(width: _railGap),
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: child),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _StopMarker extends StatelessWidget {
  const _StopMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _railWidth,
      height: _railWidth,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: XploreColors.background,
        border: Border.all(color: XploreColors.accent, width: 3),
      ),
    );
  }
}

class _DashedMarker extends StatelessWidget {
  const _DashedMarker();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: _railWidth,
      child: CustomPaint(painter: _DashedRingPainter()),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter();

  static const _dashes = 8;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..color = XploreColors.tertiaryLabel
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawRect(Offset.zero & size, Paint()..color = XploreColors.background);
    const sweep = 2 * math.pi / _dashes;
    for (var i = 0; i < _dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter oldDelegate) => false;
}

class _RemoveBackground extends StatelessWidget {
  const _RemoveBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 16),
      color: XploreColors.error.withValues(alpha: 0.16),
      child: Text('Remove', style: XploreText.footnoteStrong.copyWith(color: XploreColors.error)),
    );
  }
}

/// One-tap places to add: popular ones before the first place, then places
/// often added alongside the trip's. Hidden when there are none.
class _PlaceSuggestions extends StatelessWidget {
  const _PlaceSuggestions({required this.stops});

  final List<TripStop> stops;

  @override
  Widget build(BuildContext context) {
    final places = stops.isEmpty
        ? placeCatalog.search('').take(_firstPlaceSuggestions).toList()
        : placeCatalog.suggestionsFor(stops);
    if (places.isEmpty) {
      return const SizedBox.shrink();
    }
    final cubit = context.read<TripCreationCubit>();

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CreateOverline(stops.isEmpty ? 'Popular' : 'Often added'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [for (final place in places) _SuggestionChip(place: place, onTap: () => cubit.addStop(place))],
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.place, required this.onTap});

  final CatalogPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add ${place.name}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        // The capsule is drawn smaller than the 44pt hit area it sits in.
        child: SizedBox(
          height: minTouchTarget,
          child: Center(
            widthFactor: 1,
            child: Container(
              height: 34,
              padding: const EdgeInsets.only(left: 10, right: 14),
              decoration: const ShapeDecoration(
                shape: StadiumBorder(side: BorderSide(color: XploreColors.separator)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 16, color: XploreColors.accent),
                  const SizedBox(width: 4),
                  Text(place.name, style: XploreText.footnoteStrong.copyWith(color: XploreColors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
