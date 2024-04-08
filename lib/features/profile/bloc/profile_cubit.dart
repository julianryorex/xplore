import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/features/map/services/marker_service.dart';
import 'package:xplore/utilities/utilities.dart';

part '../../../generated/features/profile/bloc/profile_cubit.freezed.dart';
part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final _logger = createLogger('Profile');
  late final MarkerService markerService;

  ProfileCubit() : super(const ProfileState(id: userId, name: 'Julian Rechsteiner')) {
    markerService = MarkerService();
    loadProfileInState();
  }

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

    final iconBytes = await markerService.convertMarkerWidgetToBytes();
    _logger.d('Generated iconBytes (${iconBytes?.length} bytes)');

    markerService.updateMarkerIcon(userId, iconBytes!);
  }

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
