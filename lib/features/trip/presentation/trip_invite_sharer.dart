import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/features/trip/services/invite_results.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

/// Creates an invite link for [trip] and opens the system share sheet with it,
/// anchored to the widget that owns [context]. Shows a snackbar naming whichever
/// step failed; does nothing when signed out.
Future<void> shareTripInvite(BuildContext context, TripModel trip) async {
  final messenger = ScaffoldMessenger.of(context);
  final tripService = context.read<TripService>();
  final uid = context.read<AuthService>().currentUid;
  if (uid == null) {
    return;
  }
  // Captured before the await so the sheet can still be anchored if the widget rebuilds meanwhile.
  final origin = shareOriginOf(context);

  final TripInviteHandle handle;
  try {
    handle = await tripService.createInvite(trip.id, uid);
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Couldn’t create an invite link. Please try again.')));
    return;
  }

  HapticFeedback.lightImpact();
  await openInviteShareSheet(messenger, tripTitle: trip.title, link: handle.link, origin: origin);
}

/// Opens the system share sheet with the invite message for [link]. [origin] anchors
/// the popover on iPad, where share_plus throws without one. Reports failures via [messenger].
Future<void> openInviteShareSheet(
  ScaffoldMessengerState messenger, {
  required String tripTitle,
  required String link,
  required Rect? origin,
}) async {
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Join "$tripTitle" on Xplore:\n$link',
        subject: 'Join my trip on Xplore',
        sharePositionOrigin: origin,
      ),
    );
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Couldn’t open the share sheet. Please try again.')));
  }
}

/// The global rect of the widget that owns [context], for anchoring the share sheet.
/// Returns `null` when the widget has not been laid out.
Rect? shareOriginOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) {
    return null;
  }
  return box.localToGlobal(Offset.zero) & box.size;
}
