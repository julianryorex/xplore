import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// SHA-256 of a photo's original bytes as lowercase hex: the photo's identity
/// for spotting the same file being added to a trip twice.
///
/// Only byte-identical files match; an edited, cropped or re-encoded copy is a
/// different photo as far as this is concerned.
String photoContentHash(Uint8List bytes) => sha256.convert(bytes).toString();

/// Runs [photoContentHash] on a background isolate; originals are several megabytes.
Future<String> photoContentHashAsync(Uint8List bytes) => compute(photoContentHash, bytes);
