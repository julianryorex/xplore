import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/features/itinerary/widgets/edit_fields.dart';

const _maxNameLength = 80;
const _maxNoteLength = 280;
const _labelGap = 8.0;
const _primaryButtonHeight = 50.0;
const _secondaryButtonHeight = 48.0;

/// Space between the blocks of a stop sheet (heading, card, fields), per the design.
const stopSheetSectionGap = 22.0;

/// The labelled free-text name of a custom stop.
class StopNameField extends StatelessWidget {
  const StopNameField({required this.controller, this.autofocus = false, this.onChanged, super.key});

  final TextEditingController controller;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const EditOverline('Name'),
        const SizedBox(height: _labelGap),
        EditTextField(
          controller: controller,
          semanticLabel: 'Stop name',
          hintText: 'What is the group doing?',
          maxLength: _maxNameLength,
          autofocus: autofocus,
          textInputAction: TextInputAction.next,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// The labelled three-line note the group sees on a stop.
class StopNoteField extends StatelessWidget {
  const StopNoteField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const EditOverline('Note for the group'),
        const SizedBox(height: _labelGap),
        EditTextField(
          controller: controller,
          semanticLabel: 'Note for the group',
          hintText: 'Meeting point, what to bring, when to be there',
          maxLines: 3,
          maxLength: _maxNoteLength,
        ),
      ],
    );
  }
}

/// The full-width white button that commits a stop sheet; disabled when [onPressed] is null.
class StopPrimaryButton extends StatelessWidget {
  const StopPrimaryButton({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Colours come from the app's primary button theme, which also styles the disabled state.
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(_primaryButtonHeight)),
      child: Text(label),
    );
  }
}

/// A full-width text button under the primary one: accent by default, [color] for destructive actions.
class StopSecondaryButton extends StatelessWidget {
  const StopSecondaryButton({
    required this.label,
    required this.onPressed,
    this.color = XploreColors.accent,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size.fromHeight(_secondaryButtonHeight),
        shape: const StadiumBorder(),
      ),
      child: Text(label),
    );
  }
}
