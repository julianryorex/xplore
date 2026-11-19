// Unit tests for the FEAT-011 gallery metadata layer (`GalleryService`),
// backed by `FakeFirebaseFirestore` (no Firebase / GUI).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/services/gallery_service.dart';
import 'package:xplore/features/gallery/services/image_compressor.dart';

/// The URL `getDownloadURL()` returns for [storagePath] (the iOS SDK keeps `:443`).
String downloadUrl(String storagePath) =>
    'https://firebasestorage.googleapis.com:443/v0/b/xplore-a7012.appspot.com/o/'
    '${Uri.encodeComponent(storagePath)}?alt=media&token=0b5c3f1e-8a7d-4c2b-9e1f-123456789abc';

void main() {
  final thumb = img.encodeJpg(img.Image(width: 8, height: 6));

  late FakeFirebaseFirestore firestore;
  late GalleryService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = GalleryService(firestore: firestore);
  });

  CollectionReference<Map<String, dynamic>> images(String tripId) =>
      firestore.collection('galleries').doc(tripId).collection('images');

  /// A well-formed doc as another member's device would have written it for `trip-1/[imageId]`.
  Map<String, dynamic> imageDoc(String imageId, {required Object? uploadedAt, String uploaderUid = 'user-1'}) {
    final storagePath = 'gallery/trip-1/$uploaderUid/$imageId';
    return {
      'uploaderUid': uploaderUid,
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 5, 1, 12)),
      'uploadedAt': uploadedAt,
      'fullUrl': downloadUrl(storagePath),
      'storagePath': storagePath,
      'thumb': Blob(thumb),
    };
  }

  Future<void> write(
    String tripId,
    String imageId, {
    String uploaderUid = 'user-1',
    String? uploaderName,
    String? contentHash,
  }) {
    final storagePath = 'gallery/$tripId/$uploaderUid/$imageId';
    return service.writeImageMetadata(
      tripId: tripId,
      imageId: imageId,
      uploaderUid: uploaderUid,
      uploaderName: uploaderName,
      contentHash: contentHash,
      createdAt: DateTime.utc(2026, 5, 1, 12),
      fullUrl: downloadUrl(storagePath),
      storagePath: storagePath,
      thumb: thumb,
    );
  }

  Timestamp at(int day) => Timestamp.fromDate(DateTime.utc(2026, 5, day));

  group('writeImageMetadata', () {
    test('writes the spec fields and round-trips into an ImageModel', () async {
      await write('trip-1', 'img-1', uploaderUid: 'user-7', uploaderName: 'Ana');

      final data = (await images('trip-1').doc('img-1').get()).data()!;
      expect(
        data.keys,
        unorderedEquals(['uploaderUid', 'uploaderName', 'createdAt', 'uploadedAt', 'fullUrl', 'storagePath', 'thumb']),
      );
      expect(data['uploadedAt'], isA<Timestamp>());
      expect(data['storagePath'], 'gallery/trip-1/user-7/img-1');

      final listed = await service.watchTripImages('trip-1').first;
      expect(listed, hasLength(1));
      final image = listed.single;
      expect(image.id, 'img-1');
      expect(image.createdAt.toUtc(), DateTime.utc(2026, 5, 1, 12));
      expect(image.lowResImage, thumb);
      expect(image.isUploading, EUploadStatus.complete);
      expect(image.downloadUrl, downloadUrl('gallery/trip-1/user-7/img-1'));
      expect(image.uploaderUid, 'user-7');
      expect(image.uploaderName, 'Ana');
    });

    test('carries the content hash so other devices can spot a duplicate', () async {
      await write('trip-1', 'img-1', contentHash: 'a' * 64);

      expect((await service.watchTripImages('trip-1').first).single.contentHash, 'a' * 64);
    });

    test('omits uploaderName when there is none', () async {
      await write('trip-1', 'img-1');

      final data = (await images('trip-1').doc('img-1').get()).data()!;
      expect(data.containsKey('uploaderName'), isFalse);
      expect((await service.watchTripImages('trip-1').first).single.uploaderName, isNull);
    });

    test('is idempotent: a retry of the same upload neither fails nor overwrites', () async {
      await write('trip-1', 'img-1');
      final firstUploadedAt = (await images('trip-1').doc('img-1').get()).data()!['uploadedAt'];

      await write('trip-1', 'img-1');

      final docs = (await images('trip-1').get()).docs;
      expect(docs, hasLength(1));
      expect(docs.single.data()['uploadedAt'], firstUploadedAt);
    });

    test('fails instead of adopting a doc another member wrote under the same id', () async {
      await images('trip-1').doc('img-1').set(imageDoc('img-1', uploadedAt: at(1), uploaderUid: 'attacker'));

      await expectLater(write('trip-1', 'img-1', uploaderUid: 'user-1'), throwsStateError);

      expect((await images('trip-1').doc('img-1').get()).data()!['uploaderUid'], 'attacker');
    });
  });

  group('watchTripImages', () {
    test('orders by uploadedAt, not by insertion or photo time', () async {
      await images('trip-1').doc('late').set(imageDoc('late', uploadedAt: at(3)));
      await images('trip-1').doc('early').set(imageDoc('early', uploadedAt: at(1)));
      await images('trip-1').doc('middle').set(imageDoc('middle', uploadedAt: at(2)));

      final listed = await service.watchTripImages('trip-1').first;

      expect(listed.map((image) => image.id), ['early', 'middle', 'late']);
    });

    test('keeps a just-written doc whose server timestamp is still pending (null)', () async {
      await images('trip-1').doc('settled').set(imageDoc('settled', uploadedAt: at(1)));
      await images('trip-1').doc('pending').set(imageDoc('pending', uploadedAt: null));

      final listed = await service.watchTripImages('trip-1').first;

      expect(listed.map((image) => image.id), containsAll(['settled', 'pending']));
    });

    test('skips malformed docs without failing the stream', () async {
      await images('trip-1').doc('good').set(imageDoc('good', uploadedAt: at(1)));
      await images('trip-1').doc('bad').set({...imageDoc('bad', uploadedAt: at(2)), 'thumb': 'not-bytes'});
      await images('trip-1').doc('missing').set({'uploadedAt': at(3)});

      final listed = await service.watchTripImages('trip-1').first;

      expect(listed.map((image) => image.id), ['good']);
    });

    test('skips docs whose fullUrl is not their own Storage object', () async {
      await images('trip-1').doc('good').set(imageDoc('good', uploadedAt: at(1)));
      await images('trip-1')
          .doc('foreign-host')
          .set({...imageDoc('foreign-host', uploadedAt: at(2)), 'fullUrl': 'https://attacker.example/x'});
      await images('trip-1')
          .doc('other-object')
          .set({...imageDoc('other-object', uploadedAt: at(3)), 'fullUrl': downloadUrl('gallery/trip-1/user-1/good')});
      await images('trip-1').doc('wrong-path').set({
        ...imageDoc('wrong-path', uploadedAt: at(4)),
        'storagePath': 'gallery/trip-1/someone-else/wrong-path',
        'fullUrl': downloadUrl('gallery/trip-1/someone-else/wrong-path'),
      });

      final listed = await service.watchTripImages('trip-1').first;

      expect(listed.map((image) => image.id), ['good']);
    });

    test('skips docs whose thumbnail is not a small JPEG', () async {
      await images('trip-1').doc('good').set(imageDoc('good', uploadedAt: at(1)));
      await images('trip-1')
          .doc('png')
          .set({...imageDoc('png', uploadedAt: at(2)), 'thumb': Blob(img.encodePng(img.Image(width: 8, height: 6)))});
      await images('trip-1').doc('huge').set({
        ...imageDoc('huge', uploadedAt: at(3)),
        'thumb': Blob(img.encodeJpg(img.Image(width: kGallerySyncThumbnailMaxEdge + 1, height: 4))),
      });

      final listed = await service.watchTripImages('trip-1').first;

      expect(listed.map((image) => image.id), ['good']);
    });

    test('only lists images for the requested trip', () async {
      await write('trip-1', 'img-a');
      await write('trip-2', 'img-b');

      final listed = await service.watchTripImages('trip-1').first;

      expect(listed.map((image) => image.id), ['img-a']);
    });

    test('emits again when another member adds a photo', () async {
      final emissions = service.watchTripImages('trip-1').map((list) => list.map((image) => image.id).toList());
      final expectation = expectLater(
        emissions,
        emitsInOrder([
          <String>[],
          ['img-1'],
        ]),
      );

      await Future<void>.delayed(Duration.zero);
      await write('trip-1', 'img-1', uploaderUid: 'user-2');

      await expectation;
    });
  });
}
