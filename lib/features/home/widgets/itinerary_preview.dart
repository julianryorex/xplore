import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/core/error_state.dart';
import 'package:xplore/core/grouped_card.dart';
import 'package:xplore/features/agent/presentation/agent_page.dart';
import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/home/widgets/capsule_button.dart';
import 'package:xplore/features/home/widgets/day_date_tile.dart';
import 'package:xplore/features/home/widgets/home_section_header.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/routes.dart';

/// Subtitle for an itinerary day with stops: "5 stops · Tsukiji, Senso-ji, SkyTree",
/// naming at most the first three, or "1 stop so far" for a single stop.
String stopSummary(List<String> stopNames) {
  if (stopNames.length == 1) {
    return '1 stop so far';
  }
  final named = stopNames.map((name) => name.trim()).where((name) => name.isNotEmpty).take(3);
  final count = '${stopNames.length} stops';
  return named.isEmpty ? count : '$count · ${named.join(', ')}';
}

/// Home's itinerary section: the first few days as an inset grouped list that
/// expands in place to every day, plus the loading / empty / error states.
class ItineraryPreview extends StatefulWidget {
  const ItineraryPreview({required this.state, required this.overview, super.key});

  final ItineraryStates state;
  final TripOverview overview;

  @override
  State<ItineraryPreview> createState() => _ItineraryPreviewState();
}

class _ItineraryPreviewState extends State<ItineraryPreview> {
  static const _collapsedDayCount = 3;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final days = widget.overview.dailyPlans;
    final canExpand = widget.state is LoadedItineraryState && days.length > _collapsedDayCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: HomeSectionHeader(
              title: 'Itinerary',
              actionLabel: canExpand ? (_expanded ? 'Show Less' : 'See All') : null,
              onAction: () => setState(() => _expanded = !_expanded),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _body(days),
          ),
        ],
      ),
    );
  }

  Widget _body(List<DailyPlanModel> days) {
    return switch (widget.state) {
      InitialItineraryState() || LoadingItineraryState() => const _LoadingCard(),
      EmptyItineraryState() => const _QuietCard(message: 'Your itinerary will show up here.'),
      ErrorItineraryState() => ErrorState(
        title: 'Unable to load itinerary',
        message: 'Something went wrong. Please try again.',
        onRetry: () => context.read<ItineraryCubit>().retry(),
      ),
      LoadedItineraryState(:final canEdit) when days.isEmpty => _NoDaysCard(canEdit: canEdit),
      LoadedItineraryState(:final canEdit) => _DayList(
        overview: widget.overview,
        dayCount: _expanded ? days.length : days.length.clamp(0, _collapsedDayCount),
        canEdit: canEdit,
      ),
    };
  }
}

class _DayList extends StatelessWidget {
  const _DayList({required this.overview, required this.dayCount, required this.canEdit});

  final TripOverview overview;
  final int dayCount;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return GroupedCard(
      children: [
        for (var index = 0; index < dayCount; index++) _DayRow(overview: overview, dayIndex: index),
        if (canEdit) const _EditDaysRow(),
      ],
    );
  }
}

/// The owner's way into the days list, as the last row of the itinerary card.
class _EditDaysRow extends StatelessWidget {
  const _EditDaysRow();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, Paths.itineraryDays),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: XploreColors.raised, borderRadius: BorderRadius.circular(radiusSm)),
                  child: const Icon(Icons.edit_outlined, size: 18, color: XploreColors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Edit days', style: XploreText.bodyStrong.copyWith(color: XploreColors.white)),
                ),
                const SizedBox(width: 12),
                const Icon(CupertinoIcons.chevron_right, size: 16, color: XploreColors.tertiaryLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "No days planned yet.", with the way to add the first day under it for the owner.
class _NoDaysCard extends StatelessWidget {
  const _NoDaysCard({required this.canEdit});

  static const _message = 'No days planned yet.';

  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    if (!canEdit) {
      return const _QuietCard(message: _message);
    }
    return const GroupedCard(
      children: [
        _QuietMessage(message: _message),
        _EditDaysRow(),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.overview, required this.dayIndex});

  final TripOverview overview;
  final int dayIndex;

  @override
  Widget build(BuildContext context) {
    final day = overview.dailyPlans[dayIndex];
    final stopNames = [for (final stop in day.plan.locations) stop.name];
    return stopNames.isEmpty ? _emptyDay(context) : _plannedDay(context, day, stopNames);
  }

  Widget _plannedDay(BuildContext context, DailyPlanModel day, List<String> stopNames) {
    final title = overview.dayTitle(dayIndex);
    return InkWell(
      onTap: () => Navigator.pushNamed(context, Paths.itineraryOverview, arguments: dayIndex),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 14, 8),
        child: Row(
          children: [
            DayDateTile(overview: overview, dayIndex: dayIndex, planned: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: XploreText.bodyStrong.copyWith(color: XploreColors.white),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    stopSummary(stopNames),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(CupertinoIcons.chevron_right, size: 16, color: XploreColors.tertiaryLabel),
          ],
        ),
      ),
    );
  }

  Widget _emptyDay(BuildContext context) {
    return Padding(
      // Less vertical padding than a planned row: the pill's padded tap target
      // is taller than the date tile, and both rows should end up the same height.
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
      child: Row(
        children: [
          DayDateTile(overview: overview, dayIndex: dayIndex, planned: false),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nothing planned',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: XploreText.body.copyWith(color: XploreColors.secondaryLabel),
            ),
          ),
          const SizedBox(width: 12),
          CapsuleButton(
            label: 'Plan day',
            backgroundColor: XploreColors.accentSoft,
            foregroundColor: XploreColors.accent,
            onPressed: () => Navigator.pushNamed(
              context,
              Paths.agent,
              arguments: AgentPageArgs(initialPrompt: overview.planDayPrompt(dayIndex)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  // Roughly three day rows, so the section does not jump once days load.
  static const _height = 170.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: XploreColors.card, borderRadius: BorderRadius.circular(radiusLg)),
      child: const CircularProgressIndicator(),
    );
  }
}

class _QuietCard extends StatelessWidget {
  const _QuietCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: XploreColors.card, borderRadius: BorderRadius.circular(radiusLg)),
      child: _QuietMessage(message: message),
    );
  }
}

class _QuietMessage extends StatelessWidget {
  const _QuietMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Text(message, style: XploreText.body.copyWith(color: XploreColors.secondaryLabel)),
    );
  }
}
