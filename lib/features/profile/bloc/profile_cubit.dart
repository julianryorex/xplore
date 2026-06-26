import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/map/services/marker_service.dart';
import 'package:xplore/features/profile/models/profile_models.dart';
import 'package:xplore/features/profile/repository/profile_repository.dart';
import 'package:xplore/features/profile/services/profile_service.dart';
import 'package:xplore/utilities/utilities.dart';

part '../../../generated/features/profile/bloc/profile_cubit.freezed.dart';
part 'profile_state.dart';

/// Drives the user's profile off the cloud (FEAT-015).
///
/// Created behind the auth gate, it hydrates `users/{uid}` offline-first (Hive
/// cache → live Firestore listener) so name/handle/avatar load on login and on
/// returning-session app open, online or offline. The listener is the **only**
/// writer to the cache; write methods go to Firestore and let the snapshot echo
/// back (mirrors `ItineraryCubit`). [ProfileService] is created lazily so the
/// Firebase-free test path can construct the cubit with `hydrate: false`.
class ProfileCubit extends Cubit<ProfileState> {
  final _logger = createLogger('Profile');
  final AuthService _authService;
  final ProfileRepository _profileRepository;
  ProfileService? _service;
  late final MarkerService markerService;
  StreamSubscription<UserProfile?>? _profileSubscription;

  ProfileCubit(
    this._authService, {
    ProfileService? profileService,
    ProfileRepository? profileRepository,
    @visibleForTesting bool hydrate = true,
  }) : _service = profileService,
       _profileRepository = profileRepository ?? ProfileRepository(),
       super(ProfileState(id: _authService.currentUid ?? '', name: _authService.currentUser?.displayName ?? '')) {
    markerService = MarkerService();
    if (hydrate) {
      hydrateProfile();
    }
  }

  /// The active Firebase UID, or null when unauthenticated.
  String? get _uid => _authService.currentUid;

  /// Lazily created so the test path (`hydrate: false`) never touches Firebase.
  ProfileService get _profileService => _service ??= ProfileService();

  //! -------------------------------------------------------------------------
  //! Public Methods
  //! -------------------------------------------------------------------------

  Future<void> changeProfilePicture() async {
    final picker = ImagePicker();
    // Bound the source at pick time (FEAT-046): no multi-MB full-res bytes.
    final pickedImage = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedImage == null) {
      _logger.d('No picture selected');
      return;
    }

    final pictureAsBytes = await pickedImage.readAsBytes();
    emit(state.copyWith(profilePicture: pictureAsBytes));
    await saveProfilePicture(pictureAsBytes);

    final uid = _uid;
    if (uid == null) {
      _logger.w('changeProfilePicture skipped cloud + marker update: not authenticated');
      return;
    }

    // Sync the avatar to the cloud so it survives reinstall / new devices.
    try {
      final url = await _profileService.uploadAvatar(uid, pictureAsBytes);
      await _profileService.setPhotoUrl(uid, url);
      _logger.d('Avatar synced to cloud');
    } catch (e) {
      _logger.w('Avatar cloud sync failed: $e');
    }

    // Regenerate the map marker from the new avatar widget.
    await wait(1000);
    final iconBytes = await markerService.convertMarkerWidgetToBytes();
    _logger.d('Generated iconBytes (${iconBytes?.length} bytes)');
    if (iconBytes != null) {
      await markerService.updateMarkerIcon(uid, iconBytes);
    }
  }

  Future<void> deleteAll() async => await markerService.deleteAll();

  //! -------------------------------------------------------------------------
  //! Private Methods
  //! -------------------------------------------------------------------------

  /// Offline-first hydration: local avatar bytes + cached profile, then a live
  /// `users/{uid}` listener that is the sole writer to the Hive cache.
  @visibleForTesting
  Future<void> hydrateProfile() async {
    final uid = _uid;
    if (uid == null) {
      _logger.w('hydrateProfile skipped: not authenticated');
      return;
    }

    await loadProfileInState();

    final cached = await _profileRepository.loadFromCache(uid);
    if (cached != null) {
      _applyProfile(cached);
    }

    await _profileSubscription?.cancel();
    _profileSubscription = _profileService.watchUserProfile(uid).listen((profile) {
      if (profile == null) return;
      _applyProfile(profile);
      _profileRepository.cacheProfile(profile);
    }, onError: (Object error) => _logger.w('Profile stream error: $error'));
  }

  void _applyProfile(UserProfile profile) {
    emit(
      state.copyWith(
        id: profile.uid,
        // Display name is provider-sourced; keep the seeded value if the cloud
        // copy is momentarily empty.
        name: profile.displayName.isNotEmpty ? profile.displayName : state.name,
        username: profile.username,
        photoUrl: profile.photoUrl,
      ),
    );
  }

  @visibleForTesting
  Future<void> loadProfileInState() async {
    // Best-effort: a missing avatar (or platform channel in tests) must not
    // abort cloud hydration.
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(('${directory.path}/profile_picture.png'));

      if (!await file.exists()) {
        _logger.w('No local profile picture found');
        return;
      }

      final pictureInBytes = await file.readAsBytes();
      emit(state.copyWith(profilePicture: pictureInBytes));
    } catch (err) {
      _logger.w('Failed to load local profile picture: $err');
    }
  }

  @visibleForTesting
  Future<void> saveProfilePicture(Uint8List imageData) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(('${directory.path}/profile_picture.png'));
    await file.writeAsBytes(imageData);
  }

  @override
  Future<void> close() {
    _profileSubscription?.cancel();
    return super.close();
  }
}
