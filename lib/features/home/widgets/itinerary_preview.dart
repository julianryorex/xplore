import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/core/error_state.dart';
import 'package:xplore/features/agent/presentation/agent_page.dart';
import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/home/widgets/capsule_button.dart';
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
          const SizedBox(height: 10),
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
      LoadedItineraryState() when days.isEmpty => const _QuietCard(message: 'No days planned yet.'),
      LoadedItineraryState() => _DayList(
        overview: widget.overview,
        dayCount: _expanded ? days.length : days.length.clamp(0, _collapsedDayCount),
      ),
    };
  }
}

class _DayList extends StatelessWidget {
  const _DayList({required this.overview, required this.dayCount});

  final TripOverview overview;
  final int dayCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: XploreColors.card,
      borderRadius: BorderRadius.circular(radiusLg),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < dayCount; index++) ...[
            if (index > 0) const _InsetSeparator(),
            _DayRow(overview: overview, dayIndex: index),
          ],
        ],
      ),
    );
  }
}

class _InsetSeparator extends StatelessWidget {
  const _InsetSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 72),
      child: ColoredBox(
        color: XploreColors.separator,
        child: SizedBox(height: 1, width: double.infinity),
      ),
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
    final title = day.title.trim().isEmpty ? overview.dayLabel(dayIndex) : day.title;
    return InkWell(
      onTap: () => Navigator.pushNamed(context, Paths.itineraryOverview, arguments: dayIndex),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        child: Row(
          children: [
            _DateTile(overview: overview, dayIndex: dayIndex, planned: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: XploreColors.white,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    stopSummary(stopNames),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: XploreColors.secondaryLabel),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          _DateTile(overview: overview, dayIndex: dayIndex, planned: false),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Nothing planned',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 17, color: XploreColors.secondaryLabel),
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
              arguments: AgentPageArgs(initialPrompt: 'Plan ${overview.dayLabel(dayIndex)} for me'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Month over day number for a dated trip, or "DAY" over the 1-based index.
class _DateTile extends StatelessWidget {
  const _DateTile({required this.overview, required this.dayIndex, required this.planned});

  final TripOverview overview;
  final int dayIndex;
  final bool planned;

  @override
  Widget build(BuildContext context) {
    final date = overview.dateOfDay(dayIndex);
    final caption = date == null ? 'DAY' : monthAbbreviation(date).toUpperCase();
    final number = date == null ? '${dayIndex + 1}' : '${date.day}';
    final foreground = planned ? XploreColors.accent : XploreColors.secondaryLabel;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: planned ? XploreColors.accentSoft : XploreColors.raised,
        borderRadius: BorderRadius.circular(radiusSm),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            caption,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: foreground),
          ),
          Text(
            number,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.05, color: foreground),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  // Roughly three day rows, so the section does not jump once days load.
  static const _height = 206.0;

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(color: XploreColors.card, borderRadius: BorderRadius.circular(radiusLg)),
      child: Text(message, style: const TextStyle(fontSize: 15, color: XploreColors.secondaryLabel)),
    );
  }
}
