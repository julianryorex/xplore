import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xplore/features/auth/bloc/auth_cleanup_mixin.dart';
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
class ProfileCubit extends Cubit<ProfileState> with AuthCleanupMixin {
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
      // Wipe this device's profile data on sign-out and re-hydrate for the next
      // account, so a persistent cubit never bleeds one user's avatar/name into
      // another's session. Gated with `hydrate` so the Firebase-free test path
      // never attaches the listener.
      bindAuthCleanup(_authService);
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

  /// Sign-out cleanup (via [AuthCleanupMixin]): drop every trace of the current
  /// user's profile from this device — the live listener, the local avatar file,
  /// the cached profile, the generated map marker, and the in-memory state — so
  /// none of it bleeds into the next account that signs in here.
  @override
  Future<void> onSignedOut() async {
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    await _deleteLocalProfilePicture();
    await _profileRepository.clearAll();
    await markerService.deleteAll();
    if (!isClosed) {
      emit(const ProfileState(id: '', name: ''));
    }
    _logger.d('Cleared local profile data on sign-out');
  }

  /// Re-hydrate for the account that just signed in. The cubit is app-scoped, so
  /// without this an account switch would leave the previous (now-cleared) state
  /// in place until the next app launch.
  @override
  Future<void> onSignedIn(String uid) async {
    if (isClosed) return;
    emit(ProfileState(id: uid, name: _authService.currentUser?.displayName ?? ''));
    await hydrateProfile();
  }

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
    unawaited(_ensureLocalAvatarBytes(profile));
  }

  /// When the cloud profile has an avatar URL but this device has no local bytes
  /// (fresh install, or after a sign-out wiped the file), pull the bytes once and
  /// cache them. `profilePicture` is the single source the home avatar and map
  /// marker render from, so without this they'd stay blank even though the cloud
  /// URL is set (the profile page's `NetworkImage` fallback masked the gap).
  Future<void> _ensureLocalAvatarBytes(UserProfile profile) async {
    if (state.profilePicture != null) return;
    final url = profile.photoUrl;
    if (url == null || url.isEmpty) return;

    try {
      final bytes = await _profileService.downloadAvatar(profile.uid);
      if (bytes == null || isClosed || state.profilePicture != null) return;
      emit(state.copyWith(profilePicture: bytes));
      await saveProfilePicture(bytes);
    } catch (err) {
      _logger.w('Failed to fetch cloud avatar bytes: $err');
    }
  }

  @visibleForTesting
  Future<void> loadProfileInState() async {
    // Best-effort: a missing avatar (or platform channel in tests) must not
    // abort cloud hydration.
    try {
      final file = await _profilePictureFile();

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
    final file = await _profilePictureFile();
    await file.writeAsBytes(imageData);
  }

  /// The avatar is stored at a fixed (non-uid-scoped) path, so it must be deleted
  /// on sign-out or it would surface for the next account on this device.
  Future<void> _deleteLocalProfilePicture() async {
    try {
      final file = await _profilePictureFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (err) {
      _logger.w('Failed to delete local profile picture: $err');
    }
  }

  Future<File> _profilePictureFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/profile_picture.png');
  }

  @override
  Future<void> close() {
    _profileSubscription?.cancel();
    return super.close();
  }
}
