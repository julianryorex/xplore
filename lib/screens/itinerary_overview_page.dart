import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/core/grouped_card.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
import 'package:xplore/core/layout_padding.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/itinerary/widgets/save_status.dart';
import 'package:xplore/features/itinerary/widgets/stop_editor_sheet.dart';
import 'package:xplore/features/itinerary/widgets/stop_row.dart';
import 'package:xplore/routes.dart';

const _heroHeight = 272.0;
const _pagePadding = 18.0;

/// What a day is called on screen: its title, or "Day 3" when it has none.
String dayDisplayTitle(DailyPlanModel day, int dayIndex) {
  final title = day.title.trim();
  return title.isEmpty ? 'Day ${dayIndex + 1}' : title;
}

/// A single day's stops. Reads the day live from [ItineraryCubit] by
/// [dayIndex] so edits show instantly. The trip owner can check stops off, add
/// stops and open edit mode; everyone else sees a read-only list.
class ItineraryOverviewPage extends StatelessWidget {
  final int dayIndex;

  const ItineraryOverviewPage({required this.dayIndex, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ItineraryCubit, ItineraryStates>(
        builder: (context, state) {
          final day = _dayFor(state);
          if (state is! LoadedItineraryState || day == null) {
            return const _MissingDay();
          }
          return _DayBody(day: day, dayIndex: dayIndex, state: state);
        },
      ),
    );
  }

  /// The day at [dayIndex], or null if the itinerary isn't loaded or the index
  /// is out of range (e.g. the day was removed on another device).
  DailyPlanModel? _dayFor(ItineraryStates state) {
    if (state is! LoadedItineraryState) {
      return null;
    }
    final plans = state.itinerary.dailyPlans;
    if (dayIndex < 0 || dayIndex >= plans.length) {
      return null;
    }
    return plans[dayIndex];
  }
}

class _DayBody extends StatelessWidget {
  const _DayBody({required this.day, required this.dayIndex, required this.state});

  final DailyPlanModel day;
  final int dayIndex;
  final LoadedItineraryState state;

  @override
  Widget build(BuildContext context) {
    final stops = day.plan.locations;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Hero(dayIndex: dayIndex, canEdit: state.canEdit),
          Padding(
            padding: const EdgeInsets.fromLTRB(_pagePadding, 22, _pagePadding, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DayHeading(day: day, dayIndex: dayIndex, isSaving: state.isSaving),
                const SaveFailedSlot(padding: EdgeInsets.only(top: 18)),
                const SizedBox(height: 18),
                if (stops.isEmpty)
                  state.canEdit ? _EmptyDayCard(dayIndex: dayIndex) : const _QuietEmptyDayCard()
                else
                  _StopList(stops: stops, dayIndex: dayIndex, state: state),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The day photo with Back and, for the owner, Edit floating over it.
class _Hero extends StatelessWidget {
  const _Hero({required this.dayIndex, required this.canEdit});

  final int dayIndex;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Image(
            image: AssetImage('assets/placeholders/skytree.jpeg'),
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              bottom: false,
              child: Header(
                leadingWidget: const HeaderBackButton(),
                trailingWidget: canEdit
                    ? HeaderPillButton(
                        label: 'Edit',
                        onPressed: () => Navigator.pushNamed(context, Paths.itineraryDayEdit, arguments: dayIndex),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.day, required this.dayIndex, required this.isSaving});

  final DailyPlanModel day;
  final int dayIndex;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final place = day.location.trim();
    final overline = place.isEmpty ? 'DAY ${dayIndex + 1}' : 'DAY ${dayIndex + 1} · ${place.toUpperCase()}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(overline, style: XploreText.overline.copyWith(color: XploreColors.secondaryLabel)),
          const SizedBox(height: 6),
          Semantics(header: true, child: Text(dayDisplayTitle(day, dayIndex), style: context.pText.headlineMedium)),
          const SizedBox(height: 6),
          Text(_meta(day.plan.locations), style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel)),
        ],
      ),
    );
  }

  /// "5 stops · 1 done", "1 stop" or "No stops yet", plus " · Saving…" while a save is in flight.
  String _meta(List<LocationPlanModel> stops) {
    final done = stops.where((stop) => stop.completed).length;
    final count = switch (stops.length) {
      0 => 'No stops yet',
      1 => '1 stop',
      final total => '$total stops',
    };
    final progress = done > 0 ? '$count · $done done' : count;
    return isSaving ? '$progress · Saving…' : progress;
  }
}

class _StopList extends StatelessWidget {
  const _StopList({required this.stops, required this.dayIndex, required this.state});

  final List<LocationPlanModel> stops;
  final int dayIndex;
  final LoadedItineraryState state;

  @override
  Widget build(BuildContext context) {
    return GroupedCard(
      separatorIndent: stopRowTextIndent,
      children: [
        for (final (index, stop) in stops.indexed)
          _StopRow(
            stop: stop,
            dayIndex: dayIndex,
            stopIndex: index,
            canEdit: state.canEdit,
            unsaved: state.saveFailure?.marksStop(dayIndex, index) ?? false,
          ),
        if (state.canEdit) _AddStopRow(dayIndex: dayIndex),
      ],
    );
  }
}

/// One stop: its completion circle, then name and details opening the stop page.
class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.dayIndex,
    required this.stopIndex,
    required this.canEdit,
    required this.unsaved,
  });

  final LocationPlanModel stop;
  final int dayIndex;
  final int stopIndex;
  final bool canEdit;
  final bool unsaved;

  @override
  Widget build(BuildContext context) {
    final indicator = CompletionIndicator(completed: stop.completed, unsaved: unsaved);
    // The whole row opens the stop; the owner's circle sits on top and wins its own taps.
    return InkWell(
      onTap: () =>
          Navigator.pushNamed(context, Paths.itineraryFocusView, arguments: (dayIndex: dayIndex, stopIndex: stopIndex)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: stopRowMinHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 14, 6),
          child: Row(
            children: [
              if (canEdit)
                _CompletionToggle(stop: stop, dayIndex: dayIndex, stopIndex: stopIndex, indicator: indicator)
              else
                SizedBox.square(
                  dimension: minTouchTarget,
                  child: Center(child: indicator),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: StopText(stop: stop, completed: stop.completed, unsaved: unsaved),
              ),
              const SizedBox(width: 12),
              const Icon(CupertinoIcons.chevron_right, size: 16, color: XploreColors.tertiaryLabel),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionToggle extends StatelessWidget {
  const _CompletionToggle({
    required this.stop,
    required this.dayIndex,
    required this.stopIndex,
    required this.indicator,
  });

  final LocationPlanModel stop;
  final int dayIndex;
  final int stopIndex;
  final Widget indicator;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'Mark ${stop.name} ${stop.completed ? 'not done' : 'done'}',
      excludeSemantics: true,
      child: InkResponse(
        onTap: () => unawaited(context.read<ItineraryCubit>().toggleLocationCompleted(dayIndex, stopIndex)),
        radius: minTouchTarget / 2,
        child: SizedBox.square(
          dimension: minTouchTarget,
          child: Center(child: indicator),
        ),
      ),
    );
  }
}

class _AddStopRow extends StatelessWidget {
  const _AddStopRow({required this.dayIndex});

  final int dayIndex;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => unawaited(showAddStopFlow(context, dayIndex: dayIndex)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: stopRowMinHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 14, 6),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: minTouchTarget,
                  child: Center(
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(color: XploreColors.accentSoft, shape: BoxShape.circle),
                      child: const Icon(Icons.add_rounded, size: 18, color: XploreColors.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Add stop', style: XploreText.bodyStrong.copyWith(color: XploreColors.accent)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The owner's empty day: an invitation to add the first stop.
class _EmptyDayCard extends StatelessWidget {
  const _EmptyDayCard({required this.dayIndex});

  final int dayIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(color: XploreColors.card, borderRadius: BorderRadius.circular(radiusLg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('Nothing planned', style: XploreText.heading.copyWith(color: XploreColors.white)),
          ),
          const SizedBox(height: 4),
          Text(
            'Add the first stop and the group will see it straight away.',
            style: XploreText.body.copyWith(color: XploreColors.secondaryLabel),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => unawaited(showAddStopFlow(context, dayIndex: dayIndex)),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, minTouchTarget),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add stop'),
          ),
        ],
      ),
    );
  }
}

class _QuietEmptyDayCard extends StatelessWidget {
  const _QuietEmptyDayCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(color: XploreColors.card, borderRadius: BorderRadius.circular(radiusLg)),
      child: Text('Nothing planned yet.', style: XploreText.body.copyWith(color: XploreColors.secondaryLabel)),
    );
  }
}

class _MissingDay extends StatelessWidget {
  const _MissingDay();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: LayoutPadding(
            child: Text(
              'This day is no longer available.',
              textAlign: TextAlign.center,
              style: context.pText.bodyMedium,
            ),
          ),
        ),
        const SafeArea(child: Header(leadingWidget: HeaderBackButton())),
      ],
    );
  }
}

/// The round Back button floating in itinerary page headers.
class HeaderBackButton extends StatelessWidget {
  const HeaderBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      excludeSemantics: true,
      child: XploreIconBtn(
        bgColor: XploreColors.card,
        onTapCallback: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, size: headerIconSize),
      ),
    );
  }
}

/// A 44pt card-coloured pill for a header action such as "Edit", with the
/// same soft drop shadow as [HeaderBackButton] so both read over a photo.
class HeaderPillButton extends StatelessWidget {
  const HeaderPillButton({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(minTouchTarget / 2),
        boxShadow: [
          BoxShadow(color: XploreColors.background.withValues(alpha: 0.24), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: XploreColors.card,
          foregroundColor: XploreColors.white,
          minimumSize: const Size(0, minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
          textStyle: XploreText.bodyStrong,
        ),
        child: Text(label),
      ),
    );
  }
}
