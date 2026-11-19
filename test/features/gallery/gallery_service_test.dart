// Unit tests for the FEAT-011 gallery metadata layer (`GalleryService`),
// backed by `FakeFirebaseFirestore` (no Firebase / GUI).

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/services/gallery_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late GalleryService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = GalleryService(firestore: firestore);
  });

  CollectionReference<Map<String, dynamic>> images(String tripId) =>
      firestore.collection('galleries').doc(tripId).collection('images');

  Map<String, dynamic> imageDoc({required Object? uploadedAt, String uploaderUid = 'user-1'}) => {
    'uploaderUid': uploaderUid,
    'createdAt': Timestamp.fromDate(DateTime.utc(2026, 5, 1, 12)),
    'uploadedAt': uploadedAt,
    'fullUrl': 'https://example.com/full.jpg',
    'storagePath': 'gallery/trip-1/$uploaderUid/img',
    'thumb': Blob(Uint8List.fromList([1, 2, 3])),
  };

  Future<void> write(String tripId, String imageId, {String uploaderUid = 'user-1'}) {
    return service.writeImageMetadata(
      tripId: tripId,
      imageId: imageId,
      uploaderUid: uploaderUid,
      createdAt: DateTime.utc(2026, 5, 1, 12),
      fullUrl: 'https://example.com/$imageId.jpg',
      storagePath: 'gallery/$tripId/$uploaderUid/$imageId',
      thumb: Uint8List.fromList([9, 8, 7]),
    );
  }

  group('writeImageMetadata', () {
    test('writes the spec fields and round-trips into an ImageModel', () async {
      await write('trip-1', 'img-1', uploaderUid: 'user-7');

      final data = (await images('trip-1').doc('img-1').get()).data()!;
      expect(data.keys, unorderedEquals(['uploaderUid', 'createdAt', 'uploadedAt', 'fullUrl', 'storagePath', 'thumb']));
      expect(data['uploadedAt'], isA<Timestamp>());
      expect(data['storagePath'], 'gallery/trip-1/user-7/img-1');

      final listed = await service.watchTripImages('trip-1').first;
      expect(listed, hasLength(1));
      final image = listed.single;
      expect(image.id, 'img-1');
      expect(image.createdAt.toUtc(), DateTime.utc(2026, 5, 1, 12));
      expect(image.lowResImage, [9, 8, 7]);
      expect(image.isUploading, EUploadStatus.complete);
      expect(image.downloadUrl, 'https://example.com/img-1.jpg');
      expect(image.uploaderUid, 'user-7');
    });

    test('is idempotent: a retry for the same image id neither fails nor overwrites', () async {
      await write('trip-1', 'img-1', uploaderUid: 'user-1');
      final firstUploadedAt = (await images('trip-1').doc('img-1').get()).data()!['uploadedAt'];

      await write('trip-1', 'img-1', uploaderUid: 'someone-else');

      final docs = (await images('trip-1').get()).docs;
      expect(docs, hasLength(1));
      expect(docs.single.data()['uploaderUid'], 'user-1');
      expect(docs.single.data()['uploadedAt'], firstUploadedAt);
    });
  });

  group('watchTripImages', () {
    test('orders by uploadedAt, not by insertion or photo time', () async {
      await images('trip-1').doc('late').set(imageDoc(uploadedAt: Timestamp.fromDate(DateTime.utc(2026, 5, 3))));
      await images('trip-1').doc('early').set(imageDoc(uploadedAt: Timestamp.fromDate(DateTime.utc(2026, 5, 1))));
      await images('trip-1').doc('middle').set(imageDoc(uploadedAt: Timestamp.fromDate(DateTime.utc(2026, 5, 2))));

      final listed = await service.watchTripImages('trip-1').first;

      expect(listed.map((image) => image.id), ['early', 'middle', 'late']);
    });

    test('keeps a just-written doc whose server timestamp is still pending (null)', () async {
      await images('trip-1').doc('settled').set(imageDoc(uploadedAt: Timestamp.fromDate(DateTime.utc(2026, 5, 1))));
      await images('trip-1').doc('pending').set(imageDoc(uploadedAt: null));

      final listed = await service.watchTripImages('trip-1').first;

      expect(listed.map((image) => image.id), containsAll(['settled', 'pending']));
    });

    test('skips malformed docs without failing the stream', () async {
      await images('trip-1').doc('good').set(imageDoc(uploadedAt: Timestamp.fromDate(DateTime.utc(2026, 5, 1))));
      await images('trip-1')
          .doc('bad')
          .set({...imageDoc(uploadedAt: Timestamp.fromDate(DateTime.utc(2026, 5, 2))), 'thumb': 'not-bytes'});
      await images('trip-1').doc('missing').set({'uploadedAt': Timestamp.fromDate(DateTime.utc(2026, 5, 3))});

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
