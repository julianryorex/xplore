import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/core/grouped_card.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/itinerary/widgets/edit_fields.dart';
import 'package:xplore/features/itinerary/widgets/itinerary_confirmations.dart';
import 'package:xplore/features/itinerary/widgets/save_status.dart';
import 'package:xplore/features/itinerary/widgets/stop_row.dart';
import 'package:xplore/routes.dart';
import 'package:xplore/screens/itinerary_overview_page.dart';

const _pagePadding = 18.0;

// Dark ink on the error red: white on it falls below WCAG AA (as in the confirm dialog).
const _onDestructive = Color(0xFF1A0604);

/// Edit mode for one day, owner only: rename it, delete and reorder its stops,
/// or remove the whole day. Every change saves as it is made.
class ItineraryDayEditPage extends StatelessWidget {
  const ItineraryDayEditPage({required this.dayIndex, super.key});

  final int dayIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<ItineraryCubit, ItineraryStates>(
          builder: (context, state) {
            final plans = state is LoadedItineraryState ? state.itinerary.dailyPlans : const <DailyPlanModel>[];
            if (dayIndex < 0 || dayIndex >= plans.length) {
              return const _Unavailable(message: 'This day is no longer available.');
            }
            if (state is! LoadedItineraryState || !state.canEdit) {
              return const _Unavailable(message: 'Only the trip owner can edit this day.');
            }
            return _DayEditor(day: plans[dayIndex], dayIndex: dayIndex);
          },
        ),
      ),
    );
  }
}

class _DayEditor extends StatefulWidget {
  const _DayEditor({required this.day, required this.dayIndex});

  final DailyPlanModel day;
  final int dayIndex;

  @override
  State<_DayEditor> createState() => _DayEditorState();
}

class _DayEditorState extends State<_DayEditor> {
  late final TextEditingController _title = TextEditingController(text: widget.day.title);
  final FocusNode _titleFocus = FocusNode();

  // Set once the day is removed: from then on dayIndex points at another day,
  // so leaving the page must not save the title onto it.
  bool _dayRemoved = false;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_onTitleFocusChanged);
  }

  @override
  void didUpdateWidget(_DayEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow a title changed elsewhere, but never overwrite what the owner is typing.
    if (widget.day.title != oldWidget.day.title && !_titleFocus.hasFocus) {
      _title.text = widget.day.title;
    }
  }

  @override
  void dispose() {
    _titleFocus.removeListener(_onTitleFocusChanged);
    _titleFocus.dispose();
    _title.dispose();
    super.dispose();
  }

  void _onTitleFocusChanged() {
    if (!_titleFocus.hasFocus) {
      _saveTitle();
    }
  }

  /// Saves the typed title; the cubit ignores it when nothing changed.
  void _saveTitle() {
    if (_dayRemoved) {
      return;
    }
    unawaited(context.read<ItineraryCubit>().renameDay(widget.dayIndex, _title.text));
  }

  Future<void> _removeDay() async {
    final stops = widget.day.plan.locations;
    final confirmed = await confirmRemoveDay(
      context,
      dayLabel: dayDisplayTitle(widget.day, widget.dayIndex),
      stopCount: stops.length,
    );
    if (!confirmed || !mounted) {
      return;
    }
    _dayRemoved = true;
    unawaited(context.read<ItineraryCubit>().removeDay(widget.dayIndex));
    // The day page beneath shows the same index, which now belongs to another day.
    Navigator.of(context).popUntil(
      (route) => route.settings.name != Paths.itineraryDayEdit && route.settings.name != Paths.itineraryOverview,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.day.plan.locations;
    // Saving on pop covers Done, the back gesture and anything else that closes the page.
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _saveTitle();
        }
      },
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(_pagePadding, 0, _pagePadding, 0),
            sliver: SliverList.list(
              children: [
                _EditHeader(dayIndex: widget.dayIndex),
                const SizedBox(height: 24),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: EditOverline('Day title')),
                const SizedBox(height: 8),
                EditTextField(
                  controller: _title,
                  focusNode: _titleFocus,
                  semanticLabel: 'Day title',
                  hintText: 'Day ${widget.dayIndex + 1}',
                  fillColor: XploreColors.card,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveTitle(),
                ),
                if (stops.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const _StopsLabel(),
                  const SizedBox(height: 8),
                  _ReorderableStops(stops: stops, dayIndex: widget.dayIndex),
                ],
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Changes save as you make them.',
                    style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
                  ),
                ),
                const SaveFailedSlot(padding: EdgeInsets.only(top: 18)),
              ],
            ),
          ),
          // Pins Remove this day to the bottom on tall screens, and lets it scroll on short ones.
          SliverFillRemaining(
            hasScrollBody: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(_pagePadding, 32, _pagePadding, MediaQuery.paddingOf(context).bottom + 16),
                child: _RemoveDayButton(onPressed: _removeDay),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditHeader extends StatelessWidget {
  const _EditHeader({required this.dayIndex});

  final int dayIndex;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Edit day ${dayIndex + 1}', style: XploreText.heading.copyWith(color: XploreColors.white)),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.maybePop(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, minTouchTarget),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.standard,
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopsLabel extends StatelessWidget {
  const _StopsLabel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          const Expanded(child: EditOverline('Stops')),
          Text('Drag to reorder', style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel)),
        ],
      ),
    );
  }
}

class _ReorderableStops extends StatelessWidget {
  const _ReorderableStops({required this.stops, required this.dayIndex});

  final List<LocationPlanModel> stops;
  final int dayIndex;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: XploreColors.card,
      borderRadius: BorderRadius.circular(radiusLg),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: stops.length,
        // onReorderItem already reports the final position, which is what the cubit expects.
        onReorderItem: (oldIndex, newIndex) =>
            unawaited(context.read<ItineraryCubit>().reorderLocations(dayIndex, oldIndex, newIndex)),
        proxyDecorator: _liftedRow,
        itemBuilder: (context, index) => _EditableStopRow(
          // Stops have no ids; the instance identifies a stop across a reorder.
          key: ObjectKey(stops[index]),
          stop: stops[index],
          dayIndex: dayIndex,
          stopIndex: index,
          showSeparator: index < stops.length - 1,
        ),
      ),
    );
  }

  Widget _liftedRow(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final lift = Curves.easeOut.transform(animation.value);
        return Material(
          type: MaterialType.transparency,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: XploreColors.raised,
              borderRadius: BorderRadius.circular(radiusMd),
              boxShadow: [
                BoxShadow(
                  color: XploreColors.background.withValues(alpha: 0.55 * lift),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _EditableStopRow extends StatelessWidget {
  const _EditableStopRow({
    required this.stop,
    required this.dayIndex,
    required this.stopIndex,
    required this.showSeparator,
    super.key,
  });

  final LocationPlanModel stop;
  final int dayIndex;
  final int stopIndex;
  final bool showSeparator;

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<ItineraryCubit>();
    if (await confirmDeleteStop(context, stopName: stop.name)) {
      unawaited(cubit.removeLocation(dayIndex, stopIndex));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: stopRowMinHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            child: Row(
              children: [
                _DeleteStopButton(stopName: stop.name, onPressed: () => _delete(context)),
                const SizedBox(width: 12),
                Expanded(child: StopText(stop: stop)),
                const SizedBox(width: 12),
                ReorderableDragStartListener(
                  index: stopIndex,
                  child: Semantics(
                    label: 'Reorder ${stop.name}',
                    child: const SizedBox.square(
                      dimension: minTouchTarget,
                      child: Icon(CupertinoIcons.line_horizontal_3, size: 20, color: XploreColors.secondaryLabel),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showSeparator) const InsetSeparator(indent: stopRowTextIndent),
      ],
    );
  }
}

class _DeleteStopButton extends StatelessWidget {
  const _DeleteStopButton({required this.stopName, required this.onPressed});

  final String stopName;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'Delete $stopName',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onPressed,
        radius: minTouchTarget / 2,
        child: SizedBox.square(
          dimension: minTouchTarget,
          child: Center(
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(color: XploreColors.error, shape: BoxShape.circle),
              child: const Icon(Icons.remove_rounded, size: 18, color: _onDestructive),
            ),
          ),
        ),
      ),
    );
  }
}

class _RemoveDayButton extends StatelessWidget {
  const _RemoveDayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: XploreColors.card,
        foregroundColor: XploreColors.error,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
        textStyle: XploreText.bodyStrong,
      ),
      child: const Text('Remove this day'),
    );
  }
}

/// Shown instead of the editor when there is no day to edit or the user may not edit it.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: XploreText.body.copyWith(color: XploreColors.secondaryLabel),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.maybePop(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, minTouchTarget),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}
