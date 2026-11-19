// Unit tests for the client-side check on a gallery doc's `fullUrl`, which must
// agree with the `galleryDownloadUrlPattern` rule in `infra/rules/firestore.rules`.

import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/gallery/services/gallery_download_url.dart';

void main() {
  const storagePath = 'gallery/trip-1/user-1/0b5c3f1e-8a7d-4c2b-9e1f-123456789abc';
  const object = 'gallery%2Ftrip-1%2Fuser-1%2F0b5c3f1e-8a7d-4c2b-9e1f-123456789abc';
  const query = 'alt=media&token=4f2a1b3c-aaaa-bbbb-cccc-0123456789ab';

  bool accepts(String url) => isGalleryDownloadUrl(url, storagePath: storagePath);

  test('accepts the URL getDownloadURL returns, with or without the explicit :443', () {
    expect(accepts('https://firebasestorage.googleapis.com:443/v0/b/$kGalleryStorageBucket/o/$object?$query'), isTrue);
    expect(accepts('https://firebasestorage.googleapis.com/v0/b/$kGalleryStorageBucket/o/$object?$query'), isTrue);
  });

  test('rejects other hosts, buckets, objects and token-less URLs', () {
    expect(accepts('https://attacker.example/v0/b/$kGalleryStorageBucket/o/$object?$query'), isFalse);
    expect(accepts('http://firebasestorage.googleapis.com/v0/b/$kGalleryStorageBucket/o/$object?$query'), isFalse);
    expect(
      accepts('https://firebasestorage.googleapis.com:8443/v0/b/$kGalleryStorageBucket/o/$object?$query'),
      isFalse,
    );
    expect(accepts('https://firebasestorage.googleapis.com/v0/b/evil.appspot.com/o/$object?$query'), isFalse);
    expect(
      accepts(
        'https://firebasestorage.googleapis.com/v0/b/$kGalleryStorageBucket/o/gallery%2Ftrip-1%2Fuser-2%2Fx?$query',
      ),
      isFalse,
    );
    expect(accepts('https://firebasestorage.googleapis.com/v0/b/$kGalleryStorageBucket/o/$object?alt=media'), isFalse);
    expect(accepts('not a url'), isFalse);
  });
}
