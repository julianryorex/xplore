import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/features/trip/bloc/trip_creation_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_creation_state.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/presentation/create_trip/create_trip_widgets.dart';

const _monthAbbr = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Lightweight "MMM d" formatter — avoids pulling in `intl` as a direct
/// dependency just for two labels.
String _formatShortDate(DateTime date) => '${_monthAbbr[date.month - 1]} ${date.day}';

/// Bucket 1 — Destination. Anchors cover art, map center, and generation.
class DestinationStep extends StatefulWidget {
  const DestinationStep({super.key});

  @override
  State<DestinationStep> createState() => _DestinationStepState();
}

class _DestinationStepState extends State<DestinationStep> {
  late final TextEditingController _controller;

  static const _suggestions = ['Tokyo', 'Paris', 'Lisbon', 'Bali', 'New York', 'Reykjavík'];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: context.read<TripCreationCubit>().state.draft.destination);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TripCreationCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          eyebrow: 'Step 1',
          title: 'Where to?',
          subtitle: 'Pick the city you want to explore. You can fine-tune everything else next.',
        ),
        const SizedBox(height: paddingUnit * 2),
        TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onChanged: cubit.setDestination,
          decoration: const InputDecoration(
            labelText: 'Destination',
            hintText: 'e.g. Tokyo',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: paddingUnit * 1.5),
        Text('Popular right now', style: context.pText.labelMedium?.copyWith(color: XploreColors.subtleText)),
        const SizedBox(height: paddingUnit),
        BlocBuilder<TripCreationCubit, TripCreationState>(
          buildWhen: (a, b) => a.draft.destination != b.draft.destination,
          builder: (context, state) {
            return Wrap(
              spacing: paddingUnit * 0.75,
              runSpacing: paddingUnit * 0.75,
              children: [
                for (final city in _suggestions)
                  SelectableChip(
                    label: city,
                    selected: state.draft.destination.trim().toLowerCase() == city.toLowerCase(),
                    onTap: () {
                      _controller.text = city;
                      cubit.setDestination(city);
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Bucket 2 — Dates & duration. Forgiving: an exact range OR a flexible
/// "~N days". Duration (not exact dates) drives the itinerary length.
class DatesStep extends StatelessWidget {
  const DatesStep({super.key});

  Future<void> _pickRange(BuildContext context) async {
    final cubit = context.read<TripCreationCubit>();
    final now = DateTime.now();
    final draft = cubit.state.draft;
    final initial = (!draft.datesAreFlexible && draft.startDate != null && draft.endDate != null)
        ? DateTimeRange(start: draft.startDate!, end: draft.endDate!)
        : null;

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
      initialDateRange: initial,
    );
    if (range != null) {
      cubit.setExactDates(range.start, range.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TripCreationCubit>();

    return BlocBuilder<TripCreationCubit, TripCreationState>(
      buildWhen: (a, b) => a.draft != b.draft,
      builder: (context, state) {
        final draft = state.draft;
        final flexible = draft.datesAreFlexible;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StepHeader(
              eyebrow: 'Step 2',
              title: 'When are you going?',
              subtitle: 'Not sure yet? Keep it flexible — we only need a rough length to plan around.',
            ),
            const SizedBox(height: paddingUnit * 2),
            Row(
              children: [
                Expanded(
                  child: SelectableChip(
                    label: 'Flexible',
                    icon: Icons.auto_awesome_rounded,
                    selected: flexible,
                    onTap: () => cubit.setFlexibleDuration(draft.flexibleDurationDays),
                  ),
                ),
                const SizedBox(width: paddingUnit),
                Expanded(
                  child: SelectableChip(
                    label: 'Exact dates',
                    icon: Icons.calendar_month_rounded,
                    selected: !flexible,
                    onTap: () => _pickRange(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: paddingUnit * 1.5),
            if (flexible)
              _DurationStepper(days: draft.flexibleDurationDays, onChanged: cubit.setFlexibleDuration)
            else
              GlassSurface(
                onTap: () => _pickRange(context),
                child: Row(
                  children: [
                    Icon(Icons.date_range_rounded, color: XploreColors.alternate),
                    const SizedBox(width: paddingUnit),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            draft.startDate != null && draft.endDate != null
                                ? '${_formatShortDate(draft.startDate!)} – ${_formatShortDate(draft.endDate!)}'
                                : 'Choose your dates',
                            style: context.pText.labelLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${draft.durationDays} ${draft.durationDays == 1 ? 'day' : 'days'}',
                            style: context.pText.bodySmall?.copyWith(color: XploreColors.subtleText),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: XploreColors.mutedText),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DurationStepper extends StatelessWidget {
  const _DurationStepper({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trip length', style: context.pText.labelLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Roughly how many days?',
                      style: context.pText.bodySmall?.copyWith(color: XploreColors.subtleText),
                    ),
                  ],
                ),
              ),
              _RoundIconButton(icon: Icons.remove_rounded, onTap: days > 1 ? () => onChanged(days - 1) : null),
              SizedBox(
                width: 64,
                child: Text(
                  '$days',
                  textAlign: TextAlign.center,
                  style: context.pText.headlineMedium?.copyWith(color: XploreColors.white),
                ),
              ),
              _RoundIconButton(icon: Icons.add_rounded, onTap: days < 30 ? () => onChanged(days + 1) : null),
            ],
          ),
          const SizedBox(height: paddingUnit),
          Wrap(
            spacing: paddingUnit * 0.75,
            children: [
              for (final preset in const [3, 5, 7, 10])
                SelectableChip(label: '$preset days', selected: days == preset, onTap: () => onChanged(preset)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: GlassSurface(
        strong: true,
        borderRadius: 40,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Center(child: Icon(icon, size: 20, color: onTap == null ? XploreColors.subtleText : XploreColors.white)),
      ),
    );
  }
}

/// Bucket 3 — Who's coming. Group *context* as a generation signal; solo is a
/// first-class default with no group gate.
class GroupStep extends StatelessWidget {
  const GroupStep({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TripCreationCubit>();

    return BlocBuilder<TripCreationCubit, TripCreationState>(
      buildWhen: (a, b) => a.draft.groupKind != b.draft.groupKind || a.draft.groupSize != b.draft.groupSize,
      builder: (context, state) {
        final draft = state.draft;
        final showSize = draft.groupKind == TripGroupKind.friends || draft.groupKind == TripGroupKind.family;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StepHeader(
              eyebrow: 'Step 3',
              title: 'Who\u2019s coming?',
              subtitle: 'This just helps us tailor suggestions — you can invite people later (or keep it solo).',
            ),
            const SizedBox(height: paddingUnit * 2),
            for (final kind in TripGroupKind.values) ...[
              SelectableTile(
                title: kind.label,
                description: kind.description,
                leading: _groupIcon(kind),
                selected: draft.groupKind == kind,
                onTap: () => cubit.setGroup(kind),
              ),
              const SizedBox(height: paddingUnit * 0.75),
            ],
            if (showSize) ...[
              const SizedBox(height: paddingUnit * 0.5),
              GlassSurface(
                child: Row(
                  children: [
                    Expanded(child: Text('How many of you?', style: context.pText.labelLarge)),
                    _RoundIconButton(
                      icon: Icons.remove_rounded,
                      onTap: draft.groupSize > 1 ? () => cubit.setGroupSize(draft.groupSize - 1) : null,
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        '${draft.groupSize}',
                        textAlign: TextAlign.center,
                        style: context.pText.headlineSmall?.copyWith(color: XploreColors.white),
                      ),
                    ),
                    _RoundIconButton(icon: Icons.add_rounded, onTap: () => cubit.setGroupSize(draft.groupSize + 1)),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  IconData _groupIcon(TripGroupKind kind) => switch (kind) {
    TripGroupKind.solo => Icons.person_rounded,
    TripGroupKind.couple => Icons.favorite_rounded,
    TripGroupKind.friends => Icons.groups_rounded,
    TripGroupKind.family => Icons.family_restroom_rounded,
  };
}

/// Bucket 4 — Vibe & preferences. Interests + pace + budget + free text.
class VibeStep extends StatefulWidget {
  const VibeStep({super.key});

  @override
  State<VibeStep> createState() => _VibeStepState();
}

class _VibeStepState extends State<VibeStep> {
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(text: context.read<TripCreationCubit>().state.draft.notes);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TripCreationCubit>();

    return BlocBuilder<TripCreationCubit, TripCreationState>(
      buildWhen: (a, b) => a.draft != b.draft,
      builder: (context, state) {
        final draft = state.draft;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StepHeader(
              eyebrow: 'Step 4',
              title: 'What\u2019s the vibe?',
              subtitle: 'Pick a few interests and set the pace — three or so is plenty.',
            ),
            const SizedBox(height: paddingUnit * 1.5),
            Text('Interests', style: context.pText.labelMedium?.copyWith(color: XploreColors.subtleText)),
            const SizedBox(height: paddingUnit * 0.75),
            Wrap(
              spacing: paddingUnit * 0.75,
              runSpacing: paddingUnit * 0.75,
              children: [
                for (final interest in TripInterest.values)
                  SelectableChip(
                    label: interest.label,
                    icon: tripInterestIcon(interest),
                    selected: draft.interests.contains(interest),
                    onTap: () => cubit.toggleInterest(interest),
                  ),
              ],
            ),
            const SizedBox(height: paddingUnit * 1.5),
            Text('Pace', style: context.pText.labelMedium?.copyWith(color: XploreColors.subtleText)),
            const SizedBox(height: paddingUnit * 0.75),
            Wrap(
              spacing: paddingUnit * 0.75,
              runSpacing: paddingUnit * 0.75,
              children: [
                for (final pace in TripPace.values)
                  SelectableChip(label: pace.label, selected: draft.pace == pace, onTap: () => cubit.setPace(pace)),
              ],
            ),
            const SizedBox(height: paddingUnit * 1.5),
            Text('Budget', style: context.pText.labelMedium?.copyWith(color: XploreColors.subtleText)),
            const SizedBox(height: paddingUnit * 0.75),
            Row(
              children: [
                for (final budget in TripBudget.values) ...[
                  Expanded(
                    child: SelectableChip(
                      label: '${budget.label}  ·  ${budget.description}',
                      selected: draft.budget == budget,
                      onTap: () => cubit.setBudget(budget),
                    ),
                  ),
                  if (budget != TripBudget.values.last) const SizedBox(width: paddingUnit * 0.5),
                ],
              ],
            ),
            const SizedBox(height: paddingUnit * 1.5),
            Text('Anything else?', style: context.pText.labelMedium?.copyWith(color: XploreColors.subtleText)),
            const SizedBox(height: paddingUnit * 0.75),
            TextField(
              controller: _notes,
              onChanged: cubit.setNotes,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Describe your ideal trip in a sentence or two…',
                alignLabelWithHint: true,
              ),
            ),
          ],
        );
      },
    );
  }
}
