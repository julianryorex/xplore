import 'package:flutter/material.dart';
import 'package:xplore/features/itinerary/widgets/edit_fields.dart';
import 'package:xplore/features/itinerary/widgets/stop_form_fields.dart';

/// How the custom stop sheet was left, other than by dismissing it.
sealed class CustomStopOutcome {
  const CustomStopOutcome();
}

/// The person committed a custom stop called [name] with [note] for the group.
final class CustomStopSubmitted extends CustomStopOutcome {
  const CustomStopSubmitted({required this.name, required this.note});

  final String name;
  final String note;
}

/// The person wants to search for a real place after all; [name] is what they had typed.
final class CustomStopSearchInstead extends CustomStopOutcome {
  const CustomStopSearchInstead(this.name);

  final String name;
}

/// Opens the custom stop sheet prefilled with [initialName], committing with
/// a button labelled [submitLabel]. Completes with the outcome, or null when dismissed.
Future<CustomStopOutcome?> showCustomStopSheet(
  BuildContext context, {
  required String submitLabel,
  String initialName = '',
}) {
  return showEditSheet<CustomStopOutcome>(
    context,
    builder: (_) => _CustomStopSheet(submitLabel: submitLabel, initialName: initialName),
  );
}

class _CustomStopSheet extends StatefulWidget {
  const _CustomStopSheet({required this.submitLabel, required this.initialName});

  final String submitLabel;
  final String initialName;

  @override
  State<_CustomStopSheet> createState() => _CustomStopSheetState();
}

class _CustomStopSheetState extends State<_CustomStopSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  final _note = TextEditingController();

  bool get _canSubmit => _name.text.trim().isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(CustomStopSubmitted(name: _name.text.trim(), note: _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return EditSheetBody(
      title: 'Custom stop',
      subtitle: "It won't have a map pin, opening hours or directions.",
      children: [
        const SizedBox(height: stopSheetSectionGap),
        StopNameField(controller: _name, autofocus: true, onChanged: (_) => setState(() {})),
        const SizedBox(height: stopSheetSectionGap),
        StopNoteField(controller: _note),
        const SizedBox(height: 24),
        StopPrimaryButton(label: widget.submitLabel, onPressed: _canSubmit ? _submit : null),
        const SizedBox(height: 4),
        StopSecondaryButton(
          label: 'Search for a place instead',
          onPressed: () => Navigator.of(context).pop(CustomStopSearchInstead(_name.text.trim())),
        ),
      ],
    );
  }
}
