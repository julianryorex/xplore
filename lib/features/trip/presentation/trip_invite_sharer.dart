import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

/// Creates an invite link for [trip] and opens the system share sheet with it.
/// Shows a snackbar if the link could not be created; does nothing when signed out.
Future<void> shareTripInvite(BuildContext context, TripModel trip) async {
  final messenger = ScaffoldMessenger.of(context);
  final tripService = context.read<TripService>();
  final uid = context.read<AuthService>().currentUid;
  if (uid == null) {
    return;
  }

  try {
    final handle = await tripService.createInvite(trip.id, uid);
    HapticFeedback.lightImpact();
    await SharePlus.instance.share(
      ShareParams(text: 'Join "${trip.title}" on Xplore:\n${handle.link}', subject: 'Join my trip on Xplore'),
    );
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Couldn’t create an invite link. Please try again.')));
  }
}
