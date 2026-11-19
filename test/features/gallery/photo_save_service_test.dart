import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gal/gal.dart';
// ignore: implementation_imports
import 'package:gal/src/gal_platform_interface.dart';
import 'package:xplore/features/gallery/services/photo_save_service.dart';

/// Fake platform for `gal`, the seam the package provides for tests.
final class _FakeGalPlatform extends GalPlatform {
  _FakeGalPlatform({this.albumGranted = false, this.addOnlyGranted = false, this.putError});

  final bool albumGranted;
  final bool addOnlyGranted;
  final Object? putError;
  final List<bool> permissionRequests = [];

  @override
  Future<bool> requestPermission({bool toAlbum = false}) async {
    permissionRequests.add(toAlbum);
    return toAlbum ? albumGranted : addOnlyGranted;
  }

  @override
  Future<void> putImage(String path, {String? album}) async {
    if (putError != null) throw putError!;
  }
}

GalException _galException(GalExceptionType type) => GalException(
  type: type,
  platformException: PlatformException(code: type.code),
  stackTrace: StackTrace.empty,
);

void main() {
  group('tripAlbumName', () {
    test('prefixes the trimmed trip name', () {
      expect(tripAlbumName('  Lisbon 2026 '), 'Xplore – Lisbon 2026');
    });

    test('falls back to the app name for a blank trip name', () {
      expect(tripAlbumName('   '), 'Xplore');
    });
  });

  group('GalPhotoSaveService.requestAccess', () {
    late GalPlatform original;
    setUp(() => original = GalPlatform.instance);
    tearDown(() => GalPlatform.instance = original);

    test('returns album without asking for add-only when album access is granted', () async {
      final fake = _FakeGalPlatform(albumGranted: true, addOnlyGranted: true);
      GalPlatform.instance = fake;

      expect(await const GalPhotoSaveService().requestAccess(), EPhotoLibraryAccess.album);
      expect(fake.permissionRequests, [true]);
    });

    test('falls back to add-only when album access is refused', () async {
      final fake = _FakeGalPlatform(addOnlyGranted: true);
      GalPlatform.instance = fake;

      expect(await const GalPhotoSaveService().requestAccess(), EPhotoLibraryAccess.addOnly);
      expect(fake.permissionRequests, [true, false]);
    });

    test('returns denied when both are refused', () async {
      GalPlatform.instance = _FakeGalPlatform();

      expect(await const GalPhotoSaveService().requestAccess(), EPhotoLibraryAccess.denied);
    });
  });

  group('GalPhotoSaveService.saveImage', () {
    late GalPlatform original;
    setUp(() => original = GalPlatform.instance);
    tearDown(() => GalPlatform.instance = original);

    test('wraps plugin failures in a PhotoSaveException', () async {
      GalPlatform.instance = _FakeGalPlatform(putError: _galException(GalExceptionType.notEnoughSpace));

      expect(
        () => const GalPhotoSaveService().saveImage(File('/tmp/photo.jpg'), album: 'Xplore – Lisbon'),
        throwsA(isA<PhotoSaveException>().having((e) => e.cause, 'cause', isA<GalException>())),
      );
    });
  });
}
