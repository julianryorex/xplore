import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/models/trip_model.dart';

/// Capsule showing the active trip's title. With more than one trip it opens a
/// sheet to pick another, which becomes the app-wide active trip.
class TripSwitcher extends StatelessWidget {
  const TripSwitcher({required this.active, required this.trips, super.key});

  final TripModel active;
  final List<TripModel> trips;

  @override
  Widget build(BuildContext context) {
    final canSwitch = trips.length > 1;
    return Semantics(
      button: canSwitch,
      label: canSwitch ? 'Current trip: ${active.title}. Switch trip' : 'Current trip: ${active.title}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: canSwitch ? () => _pickTrip(context) : null,
        child: Container(
          height: minTouchTarget,
          padding: EdgeInsets.only(left: 16, right: canSwitch ? 12 : 16),
          decoration: BoxDecoration(color: XploreColors.card, borderRadius: BorderRadius.circular(22)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  active.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: XploreColors.white),
                ),
              ),
              if (canSwitch) ...[
                const SizedBox(width: 6),
                const Icon(CupertinoIcons.chevron_down, size: 14, color: XploreColors.secondaryLabel),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTrip(BuildContext context) async {
    final tripCubit = context.read<TripCubit>();
    final pickedId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: XploreColors.card,
      showDragHandle: true,
      builder: (_) => _TripPickerSheet(trips: trips, activeId: active.id),
    );
    if (pickedId != null && pickedId != active.id && _isStillLoaded(tripCubit.state, pickedId)) {
      tripCubit.setActiveTrip(pickedId);
    }
  }

  // The sheet lists a snapshot of the trips, and setActiveTrip keeps an unknown
  // id as pending, so a trip removed while the sheet was open must be ignored.
  bool _isStillLoaded(TripState state, String tripId) =>
      state is TripLoaded && state.all.any((trip) => trip.id == tripId);
}

class _TripPickerSheet extends StatelessWidget {
  const _TripPickerSheet({required this.trips, required this.activeId});

  final List<TripModel> trips;
  final String activeId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Switch trip',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: XploreColors.white),
            ),
          ),
          for (final trip in trips)
            _TripRow(trip: trip, selected: trip.id == activeId, onTap: () => Navigator.pop(context, trip.id)),
        ],
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.trip, required this.selected, required this.onTap});

  final TripModel trip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    trip.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, color: XploreColors.white),
                  ),
                ),
                if (selected) const Icon(CupertinoIcons.checkmark_alt, size: 20, color: XploreColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
