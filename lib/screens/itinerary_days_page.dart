import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/core/error_state.dart';
import 'package:xplore/core/grouped_card.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/home/widgets/day_date_tile.dart';
import 'package:xplore/features/home/widgets/itinerary_preview.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/widgets/itinerary_confirmations.dart';
import 'package:xplore/features/itinerary/widgets/rename_day_sheet.dart';
import 'package:xplore/features/itinerary/widgets/save_status.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/routes.dart';

const _rowMinHeight = 60.0;

/// Every day of the active trip's itinerary. The owner adds, renames and
/// removes days here; everyone else sees the same list read-only.
class ItineraryDaysPage extends StatelessWidget {
  const ItineraryDaysPage({super.key});

  @override
  Widget build(BuildContext context) {
    final trip = context.select<TripCubit, TripModel?>(
      (cubit) => switch (cubit.state) {
        TripLoaded(:final active) => active,
        _ => null,
      },
    );

    return Scaffold(
      backgroundColor: XploreColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Header(
              leadingWidget: Semantics(
                button: true,
                label: 'Back',
                child: XploreIconBtn(
                  bgColor: XploreColors.darkBg,
                  onTapCallback: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: headerIconSize, color: XploreColors.white),
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<ItineraryCubit, ItineraryStates>(
                builder: (context, state) => _body(context, state, trip),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ItineraryStates state, TripModel? trip) {
    return switch (state) {
      LoadedItineraryState(:final itinerary, :final canEdit) when trip != null => _DaysList(
        overview: TripOverview(trip: trip, dailyPlans: itinerary.dailyPlans),
        canEdit: canEdit,
      ),
      ErrorItineraryState() => Padding(
        padding: const EdgeInsets.all(paddingUnit * 1.5),
        child: Align(
          alignment: Alignment.topCenter,
          child: ErrorState(
            title: 'Unable to load itinerary',
            message: 'Something went wrong. Please try again.',
            onRetry: () => context.read<ItineraryCubit>().retry(),
          ),
        ),
      ),
      EmptyItineraryState() => Center(
        child: Text('No trip to show.', style: XploreText.body.copyWith(color: XploreColors.secondaryLabel)),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _DaysList extends StatelessWidget {
  const _DaysList({required this.overview, required this.canEdit});

  final TripOverview overview;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final dateRange = overview.dateRangeLabel;
    final subtitle = dateRange == null ? overview.trip.title : '${overview.trip.title} · $dateRange';
    final dayCount = overview.dailyPlans.length;

    return ListView(
      padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.viewPaddingOf(context).bottom + 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('Days', style: XploreText.title.copyWith(color: XploreColors.white)),
              ),
              const SizedBox(height: 8),
              Text(subtitle, style: XploreText.body.copyWith(color: XploreColors.secondaryLabel)),
            ],
          ),
        ),
        const SaveFailedSlot(padding: EdgeInsets.only(bottom: 12)),
        if (dayCount > 0 || canEdit)
          GroupedCard(
            children: [
              for (var index = 0; index < dayCount; index++)
                _DayRow(overview: overview, dayIndex: index, canEdit: canEdit),
              if (canEdit) const _AddDayRow(),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('No days planned yet.', style: XploreText.body.copyWith(color: XploreColors.secondaryLabel)),
          ),
      ],
    );
  }
}

/// One day: opens the day on tap; the owner also gets its More menu.
class _DayRow extends StatelessWidget {
  const _DayRow({required this.overview, required this.dayIndex, required this.canEdit});

  final TripOverview overview;
  final int dayIndex;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final day = overview.dailyPlans[dayIndex];
    final stopNames = [for (final stop in day.plan.locations) stop.name];
    final planned = stopNames.isNotEmpty;
    // An empty day keeps its title here, so a rename is visible before any stop is added.
    final titled = planned || day.title.trim().isNotEmpty;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, Paths.itineraryOverview, arguments: dayIndex),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _rowMinHeight),
          child: Padding(
            // The More button carries its own 44pt padding, so the row's right inset is smaller with it.
            padding: EdgeInsets.fromLTRB(16, 8, canEdit ? 4 : 14, 8),
            child: Row(
              children: [
                DayDateTile(overview: overview, dayIndex: dayIndex, planned: planned),
                const SizedBox(width: 12),
                Expanded(
                  child: titled ? _titledLabel(planned ? stopSummary(stopNames) : 'Nothing planned') : _emptyLabel(),
                ),
                const SizedBox(width: 12),
                if (canEdit)
                  _DayMenuButton(overview: overview, dayIndex: dayIndex, stopCount: stopNames.length)
                else
                  const Icon(CupertinoIcons.chevron_right, size: 16, color: XploreColors.tertiaryLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _titledLabel(String summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          overview.dayTitle(dayIndex),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: XploreText.bodyStrong.copyWith(color: XploreColors.white),
        ),
        const SizedBox(height: 1),
        Text(
          summary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
        ),
      ],
    );
  }

  Widget _emptyLabel() {
    return Text(
      'Nothing planned',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: XploreText.body.copyWith(color: XploreColors.secondaryLabel),
    );
  }
}

/// The owner's "More" button on a day row and the menu it opens.
class _DayMenuButton extends StatelessWidget {
  const _DayMenuButton({required this.overview, required this.dayIndex, required this.stopCount});

  final TripOverview overview;
  final int dayIndex;
  final int stopCount;

  static const _menuWidth = 220.0;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(-_menuWidth + minTouchTarget, 4),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(XploreColors.glassChromeStrong),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(XploreColors.background.withValues(alpha: 0.6)),
        elevation: const WidgetStatePropertyAll(16),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        minimumSize: const WidgetStatePropertyAll(Size(_menuWidth, 0)),
        maximumSize: const WidgetStatePropertyAll(Size(_menuWidth, double.infinity)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            side: const BorderSide(color: XploreColors.glassChromeBorder),
          ),
        ),
      ),
      menuChildren: [
        _MenuAction(label: 'Rename', icon: Icons.edit_outlined, onPressed: () => _rename(context)),
        const _MenuDivider(),
        _MenuAction(label: 'Add a day after', icon: Icons.add, onPressed: () => _addDayAfter(context)),
        const _MenuDivider(),
        _MenuAction(
          label: 'Remove day',
          icon: Icons.delete_outline_rounded,
          color: XploreColors.error,
          onPressed: () => _remove(context),
        ),
      ],
      builder: (context, controller, _) {
        final isOpen = controller.isOpen;
        return Semantics(
          expanded: isOpen,
          child: IconButton(
            onPressed: () => isOpen ? controller.close() : controller.open(),
            constraints: const BoxConstraints.tightFor(width: minTouchTarget, height: minTouchTarget),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(backgroundColor: isOpen ? XploreColors.raised : Colors.transparent),
            icon: Icon(
              Icons.more_horiz,
              size: 20,
              color: isOpen ? XploreColors.white : XploreColors.secondaryLabel,
              semanticLabel: 'More for ${overview.dayLabel(dayIndex)}',
            ),
          ),
        );
      },
    );
  }

  void _rename(BuildContext context) => unawaited(showRenameDaySheet(context, dayIndex: dayIndex));

  void _addDayAfter(BuildContext context) => unawaited(context.read<ItineraryCubit>().addDay(afterIndex: dayIndex));

  Future<void> _remove(BuildContext context) async {
    final cubit = context.read<ItineraryCubit>();
    final confirmed = await confirmRemoveDay(context, dayLabel: overview.dayTitle(dayIndex), stopCount: stopCount);
    if (confirmed) {
      // Saves optimistically; the future may not complete while offline, so nothing waits on it.
      unawaited(cubit.removeDay(dayIndex));
    }
  }
}

/// A menu row: label on the left, icon on the right, in [color].
class _MenuAction extends StatelessWidget {
  const _MenuAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = XploreColors.white,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      onPressed: onPressed,
      trailingIcon: Icon(icon, size: 18, color: color),
      style: MenuItemButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        padding: const EdgeInsets.fromLTRB(16, 0, 14, 0),
        foregroundColor: color,
        iconColor: color,
        textStyle: XploreText.body,
      ),
      child: Text(label),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: XploreColors.glassChromeBorder);
  }
}

/// The owner's last row: appends an empty day to the end of the trip.
class _AddDayRow extends StatelessWidget {
  const _AddDayRow();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => unawaited(context.read<ItineraryCubit>().addDay()),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _rowMinHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: XploreColors.accentSoft,
                    borderRadius: BorderRadius.circular(radiusSm),
                  ),
                  child: const Icon(Icons.add, size: 18, color: XploreColors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Add day', style: XploreText.bodyStrong.copyWith(color: XploreColors.accent)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
