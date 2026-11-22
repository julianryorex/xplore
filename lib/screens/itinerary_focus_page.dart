import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/itinerary/models/stop_display.dart';
import 'package:xplore/features/itinerary/widgets/stop_editor_sheet.dart';
import 'package:xplore/screens/itinerary_overview_page.dart';

const _pagePadding = 18.0;

/// One stop's detail page: its place, details, the note for the group and the
/// stop's gallery. Reads the stop live from [ItineraryCubit]; the trip owner
/// also gets Edit. Closes itself when the stop is deleted.
class ItineraryFocusPage extends StatefulWidget {
  final int dayIndex;
  final int stopIndex;

  const ItineraryFocusPage({required this.dayIndex, required this.stopIndex, super.key});

  @override
  State<ItineraryFocusPage> createState() => _ItineraryFocusPageState();
}

class _ItineraryFocusPageState extends State<ItineraryFocusPage> {
  bool _closing = false;

  LocationPlanModel? _stopFor(ItineraryStates state) {
    if (state is! LoadedItineraryState) {
      return null;
    }
    final plans = state.itinerary.dailyPlans;
    if (widget.dayIndex < 0 || widget.dayIndex >= plans.length) {
      return null;
    }
    final stops = plans[widget.dayIndex].plan.locations;
    if (widget.stopIndex < 0 || widget.stopIndex >= stops.length) {
      return null;
    }
    return stops[widget.stopIndex];
  }

  /// Leaves the page once its stop is gone. Done after the frame because it
  /// is noticed during build, and only once however often the page rebuilds.
  void _closeAfterFrame() {
    if (_closing) {
      return;
    }
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final route = ModalRoute.of(context);
      // A sheet may still be closing above this page; remove this route rather than popping the sheet.
      if (route == null || route.isCurrent) {
        unawaited(Navigator.maybePop(context));
      } else {
        Navigator.of(context).removeRoute(route);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<ItineraryCubit, ItineraryStates>(
          builder: (context, state) {
            final stop = _stopFor(state);
            if (stop == null) {
              _closeAfterFrame();
            }
            final canEdit = stop != null && state is LoadedItineraryState && state.canEdit;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Header(
                  leadingWidget: const HeaderBackButton(),
                  trailingWidget: canEdit
                      ? HeaderPillButton(
                          label: 'Edit',
                          onPressed: () => unawaited(
                            showStopEditor(context, dayIndex: widget.dayIndex, stopIndex: widget.stopIndex),
                          ),
                        )
                      : null,
                ),
                if (stop != null) Expanded(child: _StopDetails(stop: stop)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StopDetails extends StatelessWidget {
  const _StopDetails({required this.stop});

  final LocationPlanModel stop;

  @override
  Widget build(BuildContext context) {
    final meta = stopSubtitle(stop, withHours: true);
    final note = stop.description.trim();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(_pagePadding, 18, _pagePadding, MediaQuery.paddingOf(context).bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!stop.isCustom) ...[const _PlacePhoto(), const SizedBox(height: 22)],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(stop.name, style: context.pText.headlineMedium)),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(meta, style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel)),
                ],
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(note, style: XploreText.body.copyWith(color: XploreColors.secondaryLabel)),
                ],
                const SizedBox(height: 32),
                Semantics(
                  header: true,
                  child: Text('Gallery', style: XploreText.heading.copyWith(color: XploreColors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const _EmptyGallery(),
        ],
      ),
    );
  }
}

/// Stands in for the place photo: stage 1 has no way to load one yet.
class _PlacePhoto extends StatelessWidget {
  const _PlacePhoto();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(color: XploreColors.raised, borderRadius: BorderRadius.circular(radiusLg)),
      child: const Icon(Icons.place_outlined, size: 36, color: XploreColors.tertiaryLabel),
    );
  }
}

class _EmptyGallery extends StatelessWidget {
  const _EmptyGallery();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(color: XploreColors.card, borderRadius: BorderRadius.circular(radiusLg)),
      child: Column(
        children: [
          const Icon(Icons.photo_camera_outlined, size: 30, color: XploreColors.accent),
          const SizedBox(height: 12),
          Text(
            'Photos from this stop will appear here.',
            textAlign: TextAlign.center,
            style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
          ),
        ],
      ),
    );
  }
}
