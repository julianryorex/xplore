import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/map/services/marker_service.dart';
import 'package:xplore/utilities/utilities.dart';

part '../../../generated/features/profile/bloc/profile_cubit.freezed.dart';
part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final _logger = createLogger('Profile');
  final AuthService _authService;
  late final MarkerService markerService;

  // The profile cubit is only created behind the auth gate, so `currentUid` is
  // normally set; the empty-string default is a defensive pre-auth placeholder
  // and is never surfaced (the id isn't rendered; marker ops read `_uid` live).
  ProfileCubit(
    this._authService, {
    @visibleForTesting bool loadLocalProfile = true,
  }) : super(
         ProfileState(
           id: _authService.currentUid ?? '',
           name: 'Julian Rechsteiner',
         ),
       ) {
    markerService = MarkerService();
    if (loadLocalProfile) {
      loadProfileInState();
    }
  }

  /// The active Firebase UID, or null when unauthenticated.
  String? get _uid => _authService.currentUid;

  //! -------------------------------------------------------------------------
  //! Public Methods
  //! -------------------------------------------------------------------------

  Future<void> changeProfilePicture() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage == null) {
      _logger.d('No picture selected');
      return;
    }

    // change profile picture in state
    final pictureAsBytes = await pickedImage.readAsBytes();
    emit(state.copyWith(profilePicture: pictureAsBytes));
    saveProfilePicture(pictureAsBytes);
    await wait(1000);

    final uid = _uid;
    if (uid == null) {
      _logger.w('changeProfilePicture skipped marker update: not authenticated');
      return;
    }

    final iconBytes = await markerService.convertMarkerWidgetToBytes();
    _logger.d('Generated iconBytes (${iconBytes?.length} bytes)');

    markerService.updateMarkerIcon(uid, iconBytes!);
  }

  Future<void> deleteAll() async => await markerService.deleteAll();

  //! -------------------------------------------------------------------------
  //! Private Methods
  //! -------------------------------------------------------------------------

  @visibleForTesting
  Future<void> loadProfileInState() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(('${directory.path}/profile_picture.png'));

    if (!await file.exists()) {
      _logger.w('No profile picture found');
      return;
    }

    final pictureInBytes = await file.readAsBytes();
    emit(state.copyWith(profilePicture: pictureInBytes));
  }

  @visibleForTesting
  Future<void> saveProfilePicture(Uint8List imageData) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(('${directory.path}/profile_picture.png'));
    await file.writeAsBytes(imageData);
  }
}
