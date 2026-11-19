import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/presentation/widgets/album_action_bar.dart';
import 'package:xplore/features/gallery/presentation/widgets/album_status_bar.dart';

ImageModel _photo(String id, [EUploadStatus status = EUploadStatus.complete]) =>
    ImageModel(id: id, createdAt: DateTime(2025, 9, 16), lowResImage: Uint8List(0), isUploading: status);

GalleryState _album(List<ImageModel> photos, {Set<String> saved = const {}, PhotoSaveProgress? save}) => GalleryState(
  imageMap: {for (final photo in photos) photo.id: photo},
  savedToPhotosIds: saved,
  saveProgress: save,
  hasSyncedWithCloud: true,
);

void main() {
  group('AlbumStatus.of', () {
    final mixed = [_photo('ok'), _photo('broken', EUploadStatus.failed), _photo('sending', EUploadStatus.uploading)];

    test('a Save-all run outranks upload problems', () {
      final status = AlbumStatus.of(
        _album(
          mixed,
          save: const PhotoSaveProgress(phase: EPhotoSavePhase.saving, total: 4, saved: 1, album: 'Amalfi'),
        ),
      )!;
      expect(status.kind, AlbumStatusKind.saving);
      expect(status.title, 'Saving 2 of 4');
      expect(status.progress, 0.25);
    });

    test('skipped duplicates are reported ahead of upload progress', () {
      final status = AlbumStatus.of(_album(mixed).copyWith(duplicatesSkipped: 2))!;
      expect(status.kind, AlbumStatusKind.duplicatesSkipped);
      expect(status.title, '2 photos were already in the album');
    });

    test('failed uploads outrank uploads in progress', () {
      final status = AlbumStatus.of(_album(mixed))!;
      expect(status.kind, AlbumStatusKind.uploadsFailed);
      expect(status.title, '1 photo didn\'t upload');
      expect(status.subtitle, '1 of 3 are in the album');
    });

    test('reports uploads in progress, then nothing once all are up', () {
      expect(AlbumStatus.of(_album([_photo('a'), _photo('b', EUploadStatus.notStarted)]))?.title, 'Uploading 1 photo');
      expect(AlbumStatus.of(_album([_photo('a')])), isNull);
    });

    test('a partial save says where the saved photos went, in the right number', () {
      String? subtitle(PhotoSaveProgress save) => AlbumStatus.of(_album(const [], save: save))!.subtitle;

      expect(
        subtitle(const PhotoSaveProgress(phase: EPhotoSavePhase.done, total: 3, saved: 1, failed: 2, album: 'Amalfi')),
        '1 is in “Amalfi”',
      );
      expect(
        subtitle(const PhotoSaveProgress(phase: EPhotoSavePhase.done, total: 5, saved: 3, failed: 2)),
        '3 are in your Photos library',
      );
    });

    test('a finished save with nothing to do says so; a denial is left to the sheet', () {
      final done = AlbumStatus.of(_album(const [], save: const PhotoSaveProgress(phase: EPhotoSavePhase.done)))!;
      expect((done.kind, done.title), (AlbumStatusKind.saveDone, 'Already in Photos'));
      expect(AlbumStatus.of(_album(const [], save: const PhotoSaveProgress(phase: EPhotoSavePhase.denied))), isNull);
    });
  });

  group('SaveAllMode.of', () {
    final photos = [_photo('a'), _photo('b'), _photo('c', EUploadStatus.uploading)];

    test('is unavailable during first sync or before any photo has uploaded', () {
      expect(SaveAllMode.of(_album(photos), isFirstSync: true), SaveAllMode.unavailable);
      expect(
        SaveAllMode.of(_album([_photo('c', EUploadStatus.uploading)]), isFirstSync: false),
        SaveAllMode.unavailable,
      );
    });

    test('offers all, then only the new ones, then reports all saved', () {
      expect(SaveAllMode.of(_album(photos), isFirstSync: false), SaveAllMode.saveAll);
      expect(SaveAllMode.of(_album(photos, saved: {'a'}), isFirstSync: false), SaveAllMode.saveNew);
      expect(SaveAllMode.of(_album(photos, saved: {'a', 'b'}), isFirstSync: false), SaveAllMode.allSaved);
    });

    test('shows a running save regardless of the album', () {
      final state = _album(const [], save: const PhotoSaveProgress(phase: EPhotoSavePhase.saving));
      expect(SaveAllMode.of(state, isFirstSync: true), SaveAllMode.saving);
    });
  });
}
