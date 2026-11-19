import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/trip/bloc/trip_creation_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_creation_state.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/presentation/create_trip/create_trip_widgets.dart';

/// Smallest group the stepper allows for friends and family: one person is a
/// solo trip and should be picked as such.
const minGroupSize = 2;

/// Largest group the stepper offers; bigger groups are rare enough that the
/// count stops being a useful planning signal.
const maxGroupSize = 20;

/// Step 3: who is coming, what they are into, the pace, and free-text notes.
/// Every input has a default; only notes over [maxTripNotesLength] block Continue.
class WhoAndVibeStep extends StatelessWidget {
  const WhoAndVibeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CreateStepTitle('Who’s coming?'),
        SizedBox(height: 22),
        _GroupPicker(),
        _GroupSizeRow(),
        SizedBox(height: 28),
        CreateOverline('Interests'),
        SizedBox(height: 10),
        _InterestChips(),
        SizedBox(height: 26),
        CreateOverline('Pace'),
        SizedBox(height: 4),
        _PaceSelector(),
        SizedBox(height: 28),
        CreateOverline('Anything else?'),
        _NotesField(),
      ],
    );
  }
}

class _GroupPicker extends StatelessWidget {
  const _GroupPicker();

  @override
  Widget build(BuildContext context) {
    final draft = context.select((TripCreationCubit cubit) => cubit.state.draft);
    final kinds = TripGroupKind.values;

    Widget tile(TripGroupKind kind) => Expanded(
      child: _GroupTile(kind: kind, selected: draft.groupKind == kind, onTap: () => _select(context, draft, kind)),
    );

    return Column(
      children: [
        for (var row = 0; row < kinds.length; row += 2) ...[
          if (row > 0) const SizedBox(height: 8),
          // Tiles grow with large text; keep both tiles in a row the same height.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [tile(kinds[row]), const SizedBox(width: 8), tile(kinds[row + 1])],
            ),
          ),
        ],
      ],
    );
  }

  void _select(BuildContext context, TripDraft draft, TripGroupKind kind) {
    if (draft.groupKind == kind) {
      return;
    }
    // A count tuned for friends still fits when switching to family and back;
    // any other switch takes the new kind's default.
    final keepSize = _hasAdjustableSize(draft.groupKind) && _hasAdjustableSize(kind);
    context.read<TripCreationCubit>().setGroup(kind, size: keepSize ? draft.groupSize : null);
  }
}

bool _hasAdjustableSize(TripGroupKind kind) => kind == TripGroupKind.friends || kind == TripGroupKind.family;

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.kind, required this.selected, required this.onTap});

  final TripGroupKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: selected ? XploreColors.accent : XploreColors.raised),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? XploreColors.accentSoft : Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kind.label, style: XploreText.bodyStrong),
                  const SizedBox(height: 2),
                  Text(
                    kind.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: XploreText.caption.copyWith(color: XploreColors.secondaryLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Only friends and family have a count to choose: solo is one and a couple is
/// two by definition, so the row is hidden for them rather than shown disabled.
class _GroupSizeRow extends StatelessWidget {
  const _GroupSizeRow();

  @override
  Widget build(BuildContext context) {
    final kind = context.select((TripCreationCubit cubit) => cubit.state.draft.groupKind);
    final size = context.select((TripCreationCubit cubit) => cubit.state.draft.groupSize);
    final cubit = context.read<TripCreationCubit>();

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: !_hasAdjustableSize(kind)
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                children: [
                  SizedBox(
                    height: 54,
                    child: Row(
                      children: [
                        const Expanded(child: Text('How many of you?', style: XploreText.bodyStrong)),
                        CreateStepperButton(
                          icon: Icons.remove_rounded,
                          label: 'Fewer people',
                          onTap: size > minGroupSize ? () => cubit.setGroupSize(size - 1) : null,
                        ),
                        CreateStepperValue(size, semanticsLabel: '$size people', minWidth: 34),
                        CreateStepperButton(
                          icon: Icons.add_rounded,
                          label: 'More people',
                          onTap: size < maxGroupSize ? () => cubit.setGroupSize(size + 1) : null,
                        ),
                      ],
                    ),
                  ),
                  const CreateHairline(),
                ],
              ),
            ),
    );
  }
}

class _InterestChips extends StatelessWidget {
  const _InterestChips();

  @override
  Widget build(BuildContext context) {
    final interests = context.select((TripCreationCubit cubit) => cubit.state.draft.interests);
    final cubit = context.read<TripCreationCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final interest in TripInterest.values)
              _InterestChip(
                label: interest.label,
                selected: interests.contains(interest),
                onTap: () => cubit.toggleInterest(interest),
              ),
          ],
        ),
        if (interests.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Pick none and we’ll plan a bit of everything.',
              style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
            ),
          ),
      ],
    );
  }
}

/// A 34pt pill centred in a 44pt-tall tap target.
class _InterestChip extends StatelessWidget {
  const _InterestChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = selected
        ? XploreText.footnoteStrong.copyWith(color: XploreColors.accent)
        : XploreText.footnote.copyWith(fontWeight: FontWeight.w500);

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          height: minTouchTarget,
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? XploreColors.accentSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: selected ? XploreColors.accent : XploreColors.raised),
              ),
              child: Center(widthFactor: 1, child: Text(label, style: style)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three equal tabs on a hairline; the selected one is underlined in white,
/// with its description beneath.
class _PaceSelector extends StatelessWidget {
  const _PaceSelector();

  @override
  Widget build(BuildContext context) {
    final pace = context.select((TripCreationCubit cubit) => cubit.state.draft.pace);
    final cubit = context.read<TripCreationCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: XploreColors.raised)),
          ),
          child: Row(
            children: [
              for (final option in TripPace.values)
                Expanded(
                  child: _PaceTab(pace: option, selected: option == pace, onTap: () => cubit.setPace(option)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(pace.description, style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel)),
      ],
    );
  }
}

class _PaceTab extends StatelessWidget {
  const _PaceTab({required this.pace, required this.selected, required this.onTap});

  final TripPace pace;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (selected) {
            return;
          }
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          height: minTouchTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: selected ? XploreColors.white : Colors.transparent, width: 2)),
          ),
          child: Text(
            pace.label,
            style: selected
                ? XploreText.bodyStrong.copyWith(fontWeight: FontWeight.w600)
                : XploreText.bodyStrong.copyWith(color: XploreColors.secondaryLabel),
          ),
        ),
      ),
    );
  }
}

/// Optional free text, seeded from the draft (the home composer can pass a
/// description in). The cubit is the source of truth; the controller is only
/// overwritten when the draft changes from outside this field.
class _NotesField extends StatefulWidget {
  const _NotesField();

  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: context.read<TripCreationCubit>().state.draft.notes);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TripCreationCubit>();
    return BlocListener<TripCreationCubit, TripCreationState>(
      listenWhen: (previous, current) => previous.draft.notes != current.draft.notes,
      listener: (context, state) {
        if (state.draft.notes != _controller.text) {
          _controller.text = state.draft.notes;
        }
      },
      child: Column(
        children: [
          TextField(
            controller: _controller,
            onChanged: cubit.setNotes,
            minLines: 2,
            maxLines: 6,
            maxLength: maxTripNotesLength,
            // Notes seeded from home may already be over the limit; let the user
            // see all of it and trim it rather than silently cutting it.
            maxLengthEnforcement: MaxLengthEnforcement.none,
            buildCounter: _notesCounter,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: XploreText.body,
            cursorColor: XploreColors.accent,
            decoration: InputDecoration(
              hintText: 'Must-sees, dietary needs, a birthday dinner…',
              hintStyle: XploreText.body.copyWith(color: XploreColors.secondaryLabel),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const CreateHairline(),
        ],
      ),
    );
  }

  /// Stays out of the way until the notes approach the limit. Counts trimmed
  /// text, as the Continue blocker does, so both agree on what is too long.
  Widget? _notesCounter(BuildContext context, {required int currentLength, required bool isFocused, int? maxLength}) {
    final length = _controller.text.trim().length;
    const limit = maxTripNotesLength;
    if (length < limit - 50) {
      return null;
    }
    final over = length - limit;
    return Text(
      over > 0 ? '$over ${over == 1 ? 'character' : 'characters'} over the limit' : '$length / $limit',
      style: XploreText.caption.copyWith(color: over > 0 ? XploreColors.error : XploreColors.secondaryLabel),
    );
  }
}
