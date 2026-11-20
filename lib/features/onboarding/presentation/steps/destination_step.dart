import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_buttons.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/models/nights_allocation.dart';

const _maxPopularPlaces = 6;
const _maxSearchResults = 5;

/// Organizer step: pick where the trip goes and, optionally, when. Continue
/// stays disabled until a place is picked.
class DestinationStep extends StatefulWidget {
  const DestinationStep({super.key});

  @override
  State<DestinationStep> createState() => _DestinationStepState();
}

class _DestinationStepState extends State<DestinationStep> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Coming back to this step keeps the place picked earlier.
    final place = context.read<OnboardingCubit>().state.destination;
    if (place != null) {
      _controller.text = _fieldText(place);
    }
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _fieldText(CatalogPlace place) => '${place.name}, ${place.country}';

  void _pick(CatalogPlace place) {
    HapticFeedback.selectionClick();
    context.read<OnboardingCubit>().setDestination(place);
    _controller.text = _fieldText(place);
    _focusNode.unfocus();
  }

  void _onQueryChanged(String _) {
    final cubit = context.read<OnboardingCubit>();
    // Any edit after picking means the user is searching again.
    if (cubit.state.destination != null) {
      cubit.setDestination(null);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final destination = context.select((OnboardingCubit cubit) => cubit.state.destination);
    final query = _controller.text.trim();

    return OnboardingStepScaffold(
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (destination != null) ...[_TripPreview(place: destination), const SizedBox(height: 16)],
          OnboardingPrimaryButton(label: 'Continue', onPressed: destination == null ? null : cubit.next),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OnboardingHeading(
            title: 'Where are you headed?',
            subtitle: 'Start with a place. Everything else can wait.',
          ),
          const SizedBox(height: 28),
          // The field carries this label for screen readers.
          const ExcludeSemantics(child: _Overline('Destination')),
          const SizedBox(height: 8),
          _DestinationField(
            controller: _controller,
            focusNode: _focusNode,
            picked: destination != null,
            onChanged: _onQueryChanged,
          ),
          if (destination == null)
            query.isEmpty
                ? _PopularPlaces(onPick: _pick)
                : _SearchResults(results: placeCatalog.search(query).take(_maxSearchResults).toList(), onPick: _pick),
          const SizedBox(height: 24),
          const _Overline('Dates · Optional'),
          const SizedBox(height: 8),
          const _DateFields(),
        ],
      ),
    );
  }
}

class _Overline extends StatelessWidget {
  const _Overline(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: XploreText.overline.copyWith(color: XploreColors.secondaryLabel));
  }
}

class _DestinationField extends StatelessWidget {
  const _DestinationField({
    required this.controller,
    required this.focusNode,
    required this.picked,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool picked;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = picked || focusNode.hasFocus;

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: XploreColors.card,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: active ? XploreColors.accent : XploreColors.card),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: XploreColors.inactiveControl),
          const SizedBox(width: paddingUnit),
          Expanded(
            child: Semantics(
              label: 'Destination',
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                textCapitalization: TextCapitalization.words,
                autocorrect: false,
                cursorColor: XploreColors.accent,
                style: XploreText.body.copyWith(fontSize: 16, color: XploreColors.white),
                decoration: InputDecoration.collapsed(
                  hintText: 'Search cities and countries',
                  hintStyle: XploreText.body.copyWith(fontSize: 16, color: XploreColors.secondaryLabel),
                ),
              ),
            ),
          ),
          if (picked) ...[
            const SizedBox(width: paddingUnit),
            const Icon(Icons.check_rounded, size: 20, color: XploreColors.accent, semanticLabel: 'Destination picked'),
          ],
        ],
      ),
    );
  }
}

class _PopularPlaces extends StatelessWidget {
  const _PopularPlaces({required this.onPick});

  final ValueChanged<CatalogPlace> onPick;

  @override
  Widget build(BuildContext context) {
    final places = placeCatalog.search('').take(_maxPopularPlaces);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        children: [for (final place in places) _PlaceChip(place: place, onTap: () => onPick(place))],
      ),
    );
  }
}

class _PlaceChip extends StatelessWidget {
  const _PlaceChip({required this.place, required this.onTap});

  final CatalogPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: place.name,
      hint: 'Picks ${place.name} as the destination',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // The capsule is drawn smaller than the 44pt hit area it sits in.
        child: SizedBox(
          height: minTouchTarget,
          child: Center(
            widthFactor: 1,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const ShapeDecoration(
                shape: StadiumBorder(side: BorderSide(color: XploreColors.separator)),
              ),
              // Centred with a width factor so the capsule hugs its label instead of filling the row.
              child: Center(
                widthFactor: 1,
                child: Text(place.name, style: XploreText.footnoteStrong.copyWith(color: XploreColors.white)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.results, required this.onPick});

  final List<CatalogPlace> results;
  final ValueChanged<CatalogPlace> onPick;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: paddingUnit),
        child: Text(
          'No matches. Only well-known destinations are available for now.',
          style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final place in results) _ResultRow(place: place, onTap: () => onPick(place))],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.place, required this.onTap});

  final CatalogPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      hint: 'Picks ${place.name} as the destination',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: XploreColors.raised)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(place.name, style: XploreText.bodyStrong.copyWith(color: XploreColors.white)),
              Text(place.country, style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Starts / Ends cells, then either "Clear dates" or a reassuring footnote.
class _DateFields extends StatelessWidget {
  const _DateFields();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final start = context.select((OnboardingCubit cubit) => cubit.state.startDate);
    final end = context.select((OnboardingCubit cubit) => cubit.state.endDate);
    final l10n = MaterialLocalizations.of(context);
    final hasDates = start != null && end != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 10,
          children: [
            Expanded(
              child: _DateCell(
                label: 'Starts',
                value: start == null ? null : _shortDate(l10n, start),
                onTap: () => _pickDates(context),
              ),
            ),
            Expanded(
              child: _DateCell(
                label: 'Ends',
                value: end == null ? null : _shortDate(l10n, end),
                onTap: () => _pickDates(context),
              ),
            ),
          ],
        ),
        if (hasDates)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: cubit.clearDates,
              style: TextButton.styleFrom(
                foregroundColor: XploreColors.secondaryLabel,
                minimumSize: const Size(0, minTouchTarget),
                padding: EdgeInsets.zero,
                textStyle: XploreText.footnote,
              ),
              child: const Text('Clear dates'),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: paddingUnit),
            child: Text(
              'No dates yet? You can add them later.',
              style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
            ),
          ),
      ],
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({required this.label, required this.value, required this.onTap});

  final String label;

  /// The formatted date, or null when none is set.
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, ${value ?? 'not set'}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: XploreColors.card,
        borderRadius: BorderRadius.circular(radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(label, style: XploreText.caption.copyWith(color: XploreColors.secondaryLabel)),
                Text(
                  value ?? 'Add',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: XploreText.heading.copyWith(
                    fontSize: 16,
                    color: value == null ? XploreColors.accent : XploreColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "YOUR TRIP" summary shown once a place is picked.
class _TripPreview extends StatelessWidget {
  const _TripPreview({required this.place});

  final CatalogPlace place;

  @override
  Widget build(BuildContext context) {
    final start = context.select((OnboardingCubit cubit) => cubit.state.startDate);
    final end = context.select((OnboardingCubit cubit) => cubit.state.endDate);
    final when = start != null && end != null ? _tripSpan(MaterialLocalizations.of(context), start, end) : null;

    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: XploreColors.card, borderRadius: BorderRadius.circular(radiusLg)),
        child: Row(
          spacing: 14,
          children: [
            _PlaceThumbnail(place: place),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Text('YOUR TRIP', style: XploreText.overline.copyWith(color: XploreColors.accent)),
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: XploreText.title.copyWith(fontSize: 20, letterSpacing: -0.5, color: XploreColors.white),
                  ),
                  Text(
                    when ?? 'Dates flexible',
                    style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The place's gradient, the catalog's stand-in for a photo, with a pin on it.
class _PlaceThumbnail extends StatelessWidget {
  const _PlaceThumbnail({required this.place});

  final CatalogPlace place;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [place.gradientStart, place.gradientEnd],
          ),
        ),
        child: const Icon(Icons.place_rounded, size: 24, color: XploreColors.white),
      ),
    );
  }
}

/// Opens the range picker the same way the create-trip flow does and stores
/// the result on the cubit.
Future<void> _pickDates(BuildContext context) async {
  final cubit = context.read<OnboardingCubit>();
  final today = dateOnly(DateTime.now());
  final lastDate = DateTime(today.year + 2, today.month, today.day);
  final start = cubit.state.startDate;
  final end = cubit.state.endDate;
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
    cubit.setDates(range.start, range.end);
  }
}

/// "Jun 3", with the year when it is not this year.
String _shortDate(MaterialLocalizations l10n, DateTime date) =>
    date.year == DateTime.now().year ? l10n.formatShortMonthDay(date) : l10n.formatShortDate(date);

/// "Jun 3 – 9 · 7 days" within a month, otherwise "Jun 28 – Jul 2 · 5 days".
String _tripSpan(MaterialLocalizations l10n, DateTime start, DateTime end) {
  final sameMonth = start.year == end.year && start.month == end.month;
  final endText = sameMonth ? '${end.day}' : _shortDate(l10n, end);
  final days = nightsBetween(start, end) + 1;
  return '${_shortDate(l10n, start)} – $endText · $days ${days == 1 ? 'day' : 'days'}';
}
