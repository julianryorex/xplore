import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';

/// Shown above the plan when an edit could not be saved: says what the group
/// cannot see yet and offers Retry. The plan itself stays on screen.
class SaveFailedBanner extends StatelessWidget {
  const SaveFailedBanner({required this.failure, super.key});

  final ItinerarySaveFailure failure;

  /// What the group is missing, by the kind of edit that failed.
  static String detailFor(ItineraryEdit edit) {
    return switch (edit) {
      ItineraryEdit.addStop => "The group can't see the new stop yet.",
      ItineraryEdit.addDay => "The group can't see the new day yet.",
      ItineraryEdit.removeStop || ItineraryEdit.removeDay => 'The group still sees what you removed.',
      ItineraryEdit.reorderStops => 'The group still sees the old order.',
      ItineraryEdit.updateStop ||
      ItineraryEdit.completeStop ||
      ItineraryEdit.renameDay => "The group can't see your change yet.",
    };
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(color: XploreColors.card, borderRadius: BorderRadius.circular(radiusLg)),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: XploreColors.error.withValues(alpha: 0.16), shape: BoxShape.circle),
                child: const Icon(Icons.error_outline_rounded, size: 22, color: XploreColors.error),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Couldn't save your change", style: XploreText.bodyStrong.copyWith(color: XploreColors.white)),
                  const SizedBox(height: 1),
                  Text(
                    detailFor(failure.edit),
                    style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => context.read<ItineraryCubit>().retrySave(),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, minTouchTarget),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The save-failed banner for the current itinerary state with [padding]
/// around it, or nothing when the last save went through.
class SaveFailedSlot extends StatelessWidget {
  const SaveFailedSlot({this.padding = EdgeInsets.zero, super.key});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ItineraryCubit, ItineraryStates>(
      builder: (context, state) {
        final failure = state is LoadedItineraryState ? state.saveFailure : null;
        if (failure == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: padding,
          child: SaveFailedBanner(failure: failure),
        );
      },
    );
  }
}
