import 'package:flutter/foundation.dart';

/// Firebase Storage bucket that holds gallery originals. Mirrors `storageBucket`
/// in `firebase_options.dart` and the bucket in the `fullUrl` pattern in `firestore.rules`.
const String kGalleryStorageBucket = 'xplore-a7012.appspot.com';

/// Whether [url] is a Firebase Storage download URL for exactly [storagePath] in
/// [kGalleryStorageBucket]: the only `fullUrl` a gallery doc may carry, so members'
/// devices never fetch a URL another member picked. Mirrors `firestore.rules`.
bool isGalleryDownloadUrl(String url, {required String storagePath}) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;

  // pathSegments decodes each segment, so the percent-encoded object name
  // (`gallery%2F...`) comes back as the single segment `gallery/...`.
  return uri.scheme == 'https' &&
      uri.host == 'firebasestorage.googleapis.com' &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment &&
      listEquals(uri.pathSegments, ['v0', 'b', kGalleryStorageBucket, 'o', storagePath]) &&
      uri.queryParameters['alt'] == 'media' &&
      (uri.queryParameters['token'] ?? '').isNotEmpty;
}
