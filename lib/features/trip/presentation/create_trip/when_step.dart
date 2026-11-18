import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/trip/bloc/trip_creation_cubit.dart';
import 'package:xplore/features/trip/models/nights_allocation.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/models/trip_stop.dart';
import 'package:xplore/features/trip/presentation/create_trip/create_trip_messages.dart';
import 'package:xplore/features/trip/presentation/create_trip/create_trip_widgets.dart';

/// Step 2: exact dates or a flexible length, and how the nights are spread
/// over the places.
class WhenStep extends StatelessWidget {
  const WhenStep({super.key});

  @override
  Widget build(BuildContext context) {
    final draft = context.select((TripCreationCubit cubit) => cubit.state.draft);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CreateStepTitle('When?'),
        const SizedBox(height: 24),
        if (draft.hasExactDates) _ExactDates(draft: draft) else _NoDates(draft: draft),
        if (draft.stops.isNotEmpty) ...[const SizedBox(height: 26), _NightsSection(draft: draft)],
      ],
    );
  }
}

Future<void> _pickDates(BuildContext context, TripDraft draft) async {
  final cubit = context.read<TripCreationCubit>();
  final today = dateOnly(DateTime.now());
  final lastDate = DateTime(today.year + 2, today.month, today.day);
  final start = draft.startDate;
  final end = draft.endDate;
  // The picker asserts its initial range lies within first/last date, so a
  // range that has slipped into the past is not pre-filled.
  final initial = start != null && end != null && !start.isBefore(today) && !end.isAfter(lastDate)
      ? DateTimeRange(start: start, end: end)
      : null;

  final range = await showDateRangePicker(
    context: context,
    firstDate: today,
    lastDate: lastDate,
    initialDateRange: initial,
    helpText: 'Trip dates',
    saveText: 'Done',
  );
  if (range != null && !cubit.isClosed) {
    cubit.setExactDates(range.start, range.end);
  }
}

/// "Apr 3", with the year when it is not this year.
String _day(MaterialLocalizations l10n, DateTime date) =>
    date.year == DateTime.now().year ? l10n.formatShortMonthDay(date) : l10n.formatShortDate(date);

/// "Apr 3 – 7" within a month, otherwise "Apr 28 – May 2".
String _stay(MaterialLocalizations l10n, StayRange range) {
  final sameMonth = range.start.year == range.end.year && range.start.month == range.end.month;
  final end = sameMonth ? '${range.end.day}' : _day(l10n, range.end);
  return '${_day(l10n, range.start)} – $end';
}

class _ExactDates extends StatelessWidget {
  const _ExactDates({required this.draft});

  final TripDraft draft;

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final start = _day(l10n, draft.startDate!);
    final end = _day(l10n, draft.endDate!);
    final nights = draft.targetNights!;
    final length = nights == 0 ? 'Day trip' : nightsLabel(nights);
    final dateStyle = XploreText.stat.copyWith(color: XploreColors.white);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: '$start to $end, $length. Change dates',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _pickDates(context, draft),
            // Wraps rather than overflows with years shown or large text sizes.
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(start, style: dateStyle),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward_rounded, size: 18, color: XploreColors.tertiaryLabel),
                ),
                Text(end, style: dateStyle),
              ],
            ),
          ),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('$length · ', style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel)),
            _InlineAction(label: 'Change dates', onTap: () => _pickDates(context, draft)),
          ],
        ),
        _InlineAction(
          label: 'I don’t have dates yet',
          color: XploreColors.secondaryLabel,
          onTap: context.read<TripCreationCubit>().setFlexible,
        ),
      ],
    );
  }
}

class _NoDates extends StatelessWidget {
  const _NoDates({required this.draft});

  final TripDraft draft;

  @override
  Widget build(BuildContext context) {
    final nights = draft.assignedNights;
    // Flexible trips last as long as their nights add up to.
    final length = draft.stops.isEmpty ? null : '${nightsLabel(nights)}, about ${draft.durationDays} days';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('No dates yet', style: XploreText.stat.copyWith(color: XploreColors.white)),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (length != null)
              Text('$length · ', style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel)),
            _InlineAction(label: 'Choose dates', onTap: () => _pickDates(context, draft)),
          ],
        ),
      ],
    );
  }
}

class _NightsSection extends StatelessWidget {
  const _NightsSection({required this.draft});

  final TripDraft draft;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TripCreationCubit>();
    final stops = draft.stops;
    final exact = draft.hasExactDates;
    final allocation = draft.nightsAllocation;

    if (stops.length == 1 && exact) {
      // One place simply gets every night; only say something when that fails.
      return _AllocationStatus(allocation: allocation, showValid: false);
    }

    final single = stops.length == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: CreateOverline(single ? 'How many nights?' : 'Nights in each place')),
            if (exact) _InlineAction(label: 'Split evenly', onTap: cubit.splitNightsEvenly),
          ],
        ),
        if (!exact) const SizedBox(height: 8),
        for (var i = 0; i < stops.length; i++)
          _NightsRow(
            stop: stops[i],
            stay: draft.stayRangeFor(i),
            onChanged: (nights) => cubit.setStopNights(stops[i].id, nights),
          ),
        const CreateHairline(),
        const SizedBox(height: 12),
        _AllocationStatus(allocation: allocation, showValid: exact),
      ],
    );
  }
}

class _NightsRow extends StatelessWidget {
  const _NightsRow({required this.stop, required this.stay, required this.onChanged});

  final TripStop stop;
  final StayRange? stay;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final stay = this.stay;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: XploreColors.raised)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(stop.name, style: XploreText.bodyStrong.copyWith(color: XploreColors.white)),
                if (stay != null)
                  Text(
                    _stay(MaterialLocalizations.of(context), stay),
                    style: XploreText.caption.copyWith(color: XploreColors.secondaryLabel, fontWeight: FontWeight.w400),
                  ),
              ],
            ),
          ),
          _NightsStepper(value: stop.nights, placeName: stop.name, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _NightsStepper extends StatelessWidget {
  const _NightsStepper({required this.value, required this.placeName, required this.onChanged});

  final int value;
  final String placeName;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: Icons.remove_rounded,
          label: 'Fewer nights in $placeName',
          onTap: value > 1 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 30,
          child: Semantics(
            label: '${nightsLabel(value)} in $placeName',
            excludeSemantics: true,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: XploreText.stat.copyWith(color: XploreColors.white),
            ),
          ),
        ),
        _StepperButton(
          icon: Icons.add_rounded,
          label: 'More nights in $placeName',
          onTap: value < maxTripNights ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

/// An outlined 32pt circle inside a 44pt hit area; [onTap] null disables it.
class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        child: SizedBox.square(
          dimension: minTouchTarget,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: XploreColors.raised),
              ),
              child: Icon(icon, size: 16, color: enabled ? XploreColors.white : XploreColors.tertiaryLabel),
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether the nights add up: a Jade check when they do (if [showValid]),
/// otherwise the same fix the primary button's reason names.
class _AllocationStatus extends StatelessWidget {
  const _AllocationStatus({required this.allocation, required this.showValid});

  final NightsAllocation allocation;
  final bool showValid;

  @override
  Widget build(BuildContext context) {
    final issue = nightsIssueMessage(allocation);
    if (issue == null && !showValid) {
      return const SizedBox.shrink();
    }
    final counts = '${allocation.assigned} of ${allocation.target} nights assigned';

    final (icon, color, text) = switch (allocation.issue) {
      null => (Icons.check_rounded, XploreColors.accent, counts),
      NightsIssue.unassigned ||
      NightsIssue.overassigned => (Icons.error_outline_rounded, XploreColors.warning, '$counts · $issue'),
      _ => (Icons.error_outline_rounded, XploreColors.warning, issue!),
    };

    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: XploreText.footnoteStrong.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

/// A small text action ("Change dates") with a full-height touch target.
class _InlineAction extends StatelessWidget {
  const _InlineAction({required this.label, required this.onTap, this.color = XploreColors.accent});

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minTouchTarget),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: Text(label, style: XploreText.footnoteStrong.copyWith(color: color)),
          ),
        ),
      ),
    );
  }
}
