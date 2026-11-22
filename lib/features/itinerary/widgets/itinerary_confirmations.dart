import 'package:flutter/material.dart';
import 'package:xplore/core/confirm_dialog.dart';

/// Asks before deleting the stop called [stopName]. Resolves to true on confirm.
Future<bool> confirmDeleteStop(BuildContext context, {required String stopName}) {
  return showConfirmDialog(
    context,
    icon: Icons.delete_outline_rounded,
    title: 'Delete this stop?',
    message: '“$stopName” comes off the plan for everyone on the trip.',
    confirmLabel: 'Delete stop',
    destructive: true,
  );
}

/// Asks before removing the day shown as [dayLabel], spelling out that its
/// [stopCount] stops go with it. Resolves to true on confirm.
Future<bool> confirmRemoveDay(BuildContext context, {required String dayLabel, required int stopCount}) {
  final stops = switch (stopCount) {
    0 => '',
    1 => ' and its 1 stop',
    _ => ' and its $stopCount stops',
  };
  final verb = stopCount == 0 ? 'comes' : 'come';
  return showConfirmDialog(
    context,
    icon: Icons.delete_outline_rounded,
    title: 'Remove this day?',
    message: '“$dayLabel”$stops $verb off the plan for everyone on the trip. Later days move up a day.',
    confirmLabel: 'Remove day',
    destructive: true,
  );
}
