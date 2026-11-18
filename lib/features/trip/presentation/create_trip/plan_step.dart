import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/trip/bloc/trip_creation_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_creation_state.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/models/nights_allocation.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/models/trip_plan.dart';
import 'package:xplore/features/trip/presentation/create_trip/create_trip_widgets.dart';

/// "11 days across 4 places", "5 days in Lisbon" or "A day in Hakone".
String tripShapeSummary(TripDraft draft) {
  final days = draft.durationDays;
  if (draft.stops.length > 1) {
    return '$days days across ${draft.stops.length} places';
  }
  final place = draft.stops.isEmpty ? '' : ' in ${draft.stops.single.name}';
  return days == 1 ? 'A day$place' : '$days days$place';
}

/// "Apr 3 – Apr 13" for a trip on exact dates; null while the dates are flexible.
String? tripDateRangeLabel(TripDraft draft) {
  if (!draft.hasExactDates) {
    return null;
  }
  final start = draft.startDate!;
  final end = draft.endDate!;
  return start == end ? formatMonthDay(start) : '${formatMonthDay(start)} – ${formatMonthDay(end)}';
}

/// Step 4: names the trip and previews the outline plan, grouped by place.
/// The shell's "Create trip" button submits it.
class PlanStep extends StatelessWidget {
  const PlanStep({super.key});

  @override
  Widget build(BuildContext context) {
    final draft = context.select((TripCreationCubit cubit) => cubit.state.draft);
    final plan = context.select((TripCreationCubit cubit) => cubit.state.plan);
    final dates = tripDateRangeLabel(draft);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CreateStepTitle('Your plan'),
        CreateStepSubtitle(dates == null ? tripShapeSummary(draft) : '${tripShapeSummary(draft)} · $dates'),
        const SizedBox(height: 24),
        const CreateOverline('Trip name'),
        const _TripNameField(),
        const SizedBox(height: 4),
        if (plan == null)
          const _PlanUnavailable()
        else ...[
          if (plan.stops.length == 1) ...[
            const CreateHairline(),
            _DayList(plan: plan, dayIndexes: plan.stops.single.dayIndexes, tripStart: _tripStart(draft)),
            const CreateHairline(),
          ] else
            _PlaceList(plan: plan, tripStart: _tripStart(draft)),
          const SizedBox(height: 16),
          Text(
            'This is a starting outline. Once the trip is created you can fill in each day with places to go.',
            style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
          ),
        ],
      ],
    );
  }

  DateTime? _tripStart(TripDraft draft) => draft.hasExactDates ? draft.startDate : null;
}

/// The trip name, showing the suggested name as its value until the user types.
/// While untouched it follows the suggestion (which changes with places and
/// group); a cleared field falls back to the suggestion when it loses focus.
class _TripNameField extends StatefulWidget {
  const _TripNameField();

  @override
  State<_TripNameField> createState() => _TripNameFieldState();
}

class _TripNameFieldState extends State<_TripNameField> {
  late final TextEditingController _controller;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    final draft = context.read<TripCreationCubit>().state.draft;
    _controller = TextEditingController(text: draft.title.trim().isEmpty ? draft.suggestedTitle : draft.title);
    _focus.addListener(_restoreSuggestionWhenCleared);
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _restoreSuggestionWhenCleared() {
    if (!_focus.hasFocus && _controller.text.trim().isEmpty) {
      _controller.text = context.read<TripCreationCubit>().state.draft.suggestedTitle;
    }
  }

  void _onChanged(String text) {
    final draft = context.read<TripCreationCubit>().state.draft;
    // Typing the suggestion back counts as untouched, so it keeps following it.
    context.read<TripCreationCubit>().setTitle(text.trim() == draft.suggestedTitle ? '' : text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TripCreationCubit, TripCreationState>(
      listenWhen: (previous, current) =>
          current.draft.title.trim().isEmpty && previous.draft.suggestedTitle != current.draft.suggestedTitle,
      listener: (context, state) {
        if (!_focus.hasFocus) {
          _controller.text = state.draft.suggestedTitle;
        }
      },
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        // The cubit ignores edits once submitting; locking the field keeps what
        // is shown equal to the name the trip is created with.
        readOnly: context.select(
          (TripCreationCubit cubit) =>
              cubit.state.phase == TripCreationPhase.submitting || cubit.state.createdTrip != null,
        ),
        onChanged: _onChanged,
        maxLength: maxTripTitleLength,
        buildCounter: _titleCounter,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        style: XploreText.bodyStrong,
        cursorColor: XploreColors.accent,
        decoration: InputDecoration(
          hintText: context.select((TripCreationCubit cubit) => cubit.state.draft.suggestedTitle),
          hintStyle: XploreText.bodyStrong.copyWith(color: XploreColors.secondaryLabel),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.only(top: 6, bottom: 12),
        ),
      ),
    );
  }
}

/// Shows the count only near the limit; the field itself stops at the limit.
Widget? _titleCounter(BuildContext context, {required int currentLength, required bool isFocused, int? maxLength}) {
  final limit = maxLength ?? maxTripTitleLength;
  if (currentLength < limit - 20) {
    return null;
  }
  return Text('$currentLength / $limit', style: XploreText.caption.copyWith(color: XploreColors.secondaryLabel));
}

/// Every place as a row on hairlines; tapping one shows its days in place. The
/// first place starts open so the shape of a plan is visible straight away.
class _PlaceList extends StatefulWidget {
  const _PlaceList({required this.plan, required this.tripStart});

  final TripPlan plan;
  final DateTime? tripStart;

  @override
  State<_PlaceList> createState() => _PlaceListState();
}

class _PlaceListState extends State<_PlaceList> {
  // Keyed by stop id so the open places survive the plan being rebuilt.
  late final Set<String> _expanded = {widget.plan.stops.first.stop.id};

  void _toggle(String id) {
    setState(() {
      if (!_expanded.remove(id)) {
        _expanded.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final stopPlan in plan.stops) ...[
          const CreateHairline(),
          _PlaceRow(
            stopPlan: stopPlan,
            days: [for (final index in stopPlan.dayIndexes) plan.days[index]],
            expanded: _expanded.contains(stopPlan.stop.id),
            onTap: () => _toggle(stopPlan.stop.id),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded.contains(stopPlan.stop.id)
                ? Padding(
                    padding: const EdgeInsets.only(left: _photoSize + _rowGap, bottom: 8),
                    child: _DayList(plan: plan, dayIndexes: stopPlan.dayIndexes, tripStart: widget.tripStart),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
        const CreateHairline(),
      ],
    );
  }
}

const _photoSize = 52.0;
const _rowGap = 14.0;

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.stopPlan, required this.days, required this.expanded, required this.onTap});

  final StopPlan stopPlan;
  final List<DailyPlanModel> days;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = XploreText.caption.copyWith(color: XploreColors.secondaryLabel, fontWeight: FontWeight.w400);
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              _PlacePhoto(placeId: stopPlan.stop.id),
              const SizedBox(width: _rowGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          (stopPlan.stopIndex + 1).toString().padLeft(2, '0'),
                          style: XploreText.overline.copyWith(color: XploreColors.accent, letterSpacing: 0.4),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            stopPlan.stop.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: XploreText.bodyStrong,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(_stayLabel(stopPlan), style: secondary),
                    Text(_dayTitlesPreview(days), maxLines: 1, overflow: TextOverflow.ellipsis, style: secondary),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: expanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.chevron_right_rounded, size: 18, color: XploreColors.tertiaryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _dayTitlesPreview(List<DailyPlanModel> days) =>
      days.map((day) => day.title.trim()).where((title) => title.isNotEmpty).toSet().join(', ');
}

/// "3 nights · Apr 8 – 11", "1 night" for flexible dates, or "Day trip" for a
/// stop without nights.
String _stayLabel(StopPlan stopPlan) {
  final stay = stopPlan.stay;
  final nights = stopPlan.nights;
  final length = nights == 0 ? 'Day trip' : '$nights ${nights == 1 ? 'night' : 'nights'}';
  if (stay == null) {
    return length;
  }
  return '$length · ${_stayDates(stay)}';
}

String _stayDates(StayRange stay) {
  if (stay.start == stay.end) {
    return formatMonthDay(stay.start);
  }
  final end = stay.start.month == stay.end.month ? '${stay.end.day}' : formatMonthDay(stay.end);
  return '${formatMonthDay(stay.start)} – $end';
}

/// The catalog's two colours for the place, standing in for a photo until
/// places carry real images. Uncatalogued places get a neutral grey.
class _PlacePhoto extends StatelessWidget {
  const _PlacePhoto({required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context) {
    final place = placeCatalog.byId(placeId);
    return Container(
      width: _photoSize,
      height: _photoSize,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: XploreColors.white.withValues(alpha: 0.1)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.45, 1],
          colors: [Color(0x00000000), Color(0x66000000)],
        ),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [place?.gradientStart ?? XploreColors.raised, place?.gradientEnd ?? XploreColors.card],
        ),
      ),
    );
  }
}

/// The days at [dayIndexes], each an outline with a title and no stops yet,
/// which the hollow marker conveys.
class _DayList extends StatelessWidget {
  const _DayList({required this.plan, required this.dayIndexes, required this.tripStart});

  final TripPlan plan;
  final List<int> dayIndexes;
  final DateTime? tripStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final index in dayIndexes) _DayRow(index: index, day: plan.days[index], date: _dateOf(index))],
    );
  }

  DateTime? _dateOf(int dayIndex) {
    final start = tripStart;
    return start == null ? null : DateTime(start.year, start.month, start.day + dayIndex);
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.index, required this.day, required this.date});

  final int index;
  final DailyPlanModel day;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final label = date == null ? 'Day ${index + 1}' : 'Day ${index + 1} · ${formatMonthDay(date!)}';
    final title = day.title.trim().isEmpty ? 'Free day' : day.title;
    return Semantics(
      label: '$label. $title. Outline, no places added yet.',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: XploreColors.secondaryLabel, width: 1.2),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(), style: XploreText.overline.copyWith(color: XploreColors.secondaryLabel)),
                  const SizedBox(height: 3),
                  Text(title, style: XploreText.body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanUnavailable extends StatelessWidget {
  const _PlanUnavailable();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CreateHairline(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'The day-by-day outline isn’t ready yet. You can still create the trip and plan each day afterwards.',
            style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
          ),
        ),
      ],
    );
  }
}
