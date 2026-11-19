import 'dart:io';

import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

/// How much of the device photo library the app may write to.
enum EPhotoLibraryAccess {
  /// Full (or limited) library access: photos can go into a named album.
  album,

  /// Add-only access: photos can be saved, but only loose in the library.
  addOnly,

  /// No access: nothing can be saved.
  denied,
}

/// Thrown when a photo could not be saved to the photo library.
class PhotoSaveException implements Exception {
  final String message;
  final Object? cause;

  const PhotoSaveException(this.message, {this.cause});

  @override
  String toString() => 'PhotoSaveException: $message${cause == null ? '' : ' ($cause)'}';
}

const _albumPrefix = 'Xplore';

/// Name of the Photos album a trip's photos are saved into, e.g. `Xplore – Lisbon`.
/// Falls back to `Xplore` when [tripName] is blank.
String tripAlbumName(String tripName) {
  final trimmed = tripName.trim();
  return trimmed.isEmpty ? _albumPrefix : '$_albumPrefix – $trimmed';
}

/// Saves images into the device photo library (Apple Photos on iOS and macOS).
abstract class PhotoSaveService {
  /// Asks for photo library access, preferring album-level access.
  Future<EPhotoLibraryAccess> requestAccess();

  /// Saves [file] to the photo library, into [album] when given.
  /// Throws a [PhotoSaveException] on failure.
  Future<void> saveImage(File file, {String? album});

  /// Opens the device's Photos app.
  Future<void> openPhotosApp();
}

/// [PhotoSaveService] backed by the `gal` plugin.
class GalPhotoSaveService implements PhotoSaveService {
  const GalPhotoSaveService();

  @override
  Future<EPhotoLibraryAccess> requestAccess() async {
    try {
      // Album access maps to PhotoKit read/write (limited counts too); only if the user
      // refuses that do we fall back to the narrower add-only prompt.
      if (await Gal.requestPermission(toAlbum: true)) return EPhotoLibraryAccess.album;
      if (await Gal.requestPermission()) return EPhotoLibraryAccess.addOnly;
      return EPhotoLibraryAccess.denied;
    } on GalException {
      return EPhotoLibraryAccess.denied;
    } on MissingPluginException {
      // Platforms without a gal implementation (e.g. Linux test hosts) simply can't save.
      return EPhotoLibraryAccess.denied;
    }
  }

  @override
  Future<void> saveImage(File file, {String? album}) async {
    try {
      await Gal.putImage(file.path, album: album);
    } on GalException catch (e) {
      throw PhotoSaveException('${e.type.message} Could not save ${file.path}.', cause: e);
    } on MissingPluginException catch (e) {
      throw PhotoSaveException('Saving to the photo library is not supported on this platform.', cause: e);
    }
  }

  @override
  Future<void> openPhotosApp() async {
    try {
      await Gal.open();
    } on Exception {
      // Purely a shortcut; nothing to recover if the Photos app can't be opened.
    }
  }
}
