import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/widgets/edit_fields.dart';

const _maxTitleLength = 60;
const _saveButtonHeight = 50.0;

/// Opens a sheet to rename day [dayIndex], prefilled with its current title.
/// Saving an empty title is allowed: the day is then shown by its date.
Future<void> showRenameDaySheet(BuildContext context, {required int dayIndex}) {
  final state = context.read<ItineraryCubit>().state;
  if (state is! LoadedItineraryState || dayIndex < 0 || dayIndex >= state.itinerary.dailyPlans.length) {
    return Future.value();
  }
  final initialTitle = state.itinerary.dailyPlans[dayIndex].title;
  return showEditSheet<void>(
    context,
    builder: (_) => _RenameDaySheet(dayIndex: dayIndex, initialTitle: initialTitle),
  );
}

class _RenameDaySheet extends StatefulWidget {
  const _RenameDaySheet({required this.dayIndex, required this.initialTitle});

  final int dayIndex;
  final String initialTitle;

  @override
  State<_RenameDaySheet> createState() => _RenameDaySheetState();
}

class _RenameDaySheetState extends State<_RenameDaySheet> {
  late final _controller = TextEditingController(text: widget.initialTitle);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    // Saves optimistically; the future may not complete while offline, so the sheet never waits on it.
    unawaited(context.read<ItineraryCubit>().renameDay(widget.dayIndex, _controller.text.trim()));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return EditSheetBody(
      title: 'Rename day',
      children: [
        const SizedBox(height: 20),
        const EditOverline('Day title'),
        const SizedBox(height: 8),
        EditTextField(
          controller: _controller,
          semanticLabel: 'Day title',
          hintText: 'Asakusa and the river',
          maxLength: _maxTitleLength,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 8),
        Text(
          'Leave it empty to show the date instead.',
          style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(_saveButtonHeight),
            backgroundColor: XploreColors.white,
            foregroundColor: XploreColors.background,
            textStyle: XploreText.bodyStrong,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
