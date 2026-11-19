import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/features/gallery/models/image_models.dart';

/// Who added a photo, as the gallery shows it: a short label and a stable tint.
///
/// Members cannot read each other's profiles, so identity comes from what the
/// photo itself carries (uploader uid and first name) rather than profile data.
@immutable
class PhotoUploader {
  const PhotoUploader({required this.uid, required this.label, required this.tint, this.isCurrentUser = false});

  /// Resolves the uploader of [image]; [currentUid] is the signed-in member.
  factory PhotoUploader.of(ImageModel image, {required String? currentUid}) {
    final uid = image.uploaderUid;
    if (uid != null && uid == currentUid) {
      return PhotoUploader(uid: uid, label: 'You', tint: XploreColors.accent, isCurrentUser: true);
    }
    final name = image.uploaderName?.trim() ?? '';
    return PhotoUploader(uid: uid, label: name.isEmpty ? 'Member' : name, tint: _tintFor(uid));
  }

  final String? uid;
  final String label;
  final Color tint;

  /// Whether the signed-in member added the photo.
  final bool isCurrentUser;

  String get initial => label.characters.first.toUpperCase();

  static const _memberTints = [Color(0xFFE0A458), Color(0xFF6FA8DC), Color(0xFFC58BD8), Color(0xFFE8836B)];

  // Derived from the uid so a member keeps the same colour on every device.
  static Color _tintFor(String? uid) {
    if (uid == null || uid.isEmpty) return XploreColors.inactiveControl;
    final hash = uid.codeUnits.fold<int>(0, (sum, unit) => (sum * 31 + unit) & 0x7fffffff);
    return _memberTints[hash % _memberTints.length];
  }

  // The name is stamped on each photo at upload time and can change between uploads, so the uid decides
  // identity; the label only does for legacy photos that carry no uid.
  @override
  bool operator ==(Object other) =>
      other is PhotoUploader && (uid != null ? other.uid == uid : other.uid == null && other.label == label);

  @override
  int get hashCode => uid != null ? uid.hashCode : label.hashCode;
}

/// The distinct uploaders of [images], in first-appearance order.
List<PhotoUploader> distinctUploaders(Iterable<ImageModel> images, {required String? currentUid}) {
  return {for (final image in images) PhotoUploader.of(image, currentUid: currentUid)}.toList();
}

/// A tinted initial circle for a photo's uploader.
class UploaderAvatar extends StatelessWidget {
  const UploaderAvatar({required this.uploader, this.size = 24, this.borderColor, super.key});

  final PhotoUploader uploader;
  final double size;

  /// Ring that separates the avatar from what it sits on (a photo or a neighbour).
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: uploader.tint,
        border: borderColor == null ? null : Border.all(color: borderColor!, width: 2),
      ),
      child: ExcludeSemantics(
        child: Text(
          uploader.initial,
          // Sized to the fixed circle; it is decorative, so it must not grow with Dynamic Type and overflow.
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: size * 0.42,
            height: 1,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111111),
          ),
        ),
      ),
    );
  }
}

/// Overlapping [UploaderAvatar]s, capped at [maxVisible].
class UploaderAvatarStack extends StatelessWidget {
  const UploaderAvatarStack({required this.uploaders, this.size = 24, this.maxVisible = 5, super.key});

  final List<PhotoUploader> uploaders;
  final double size;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final visible = uploaders.take(maxVisible).toList();
    final step = size * 0.75;

    return Semantics(
      label: 'Added by ${uploaders.map((uploader) => uploader.label).join(', ')}',
      child: SizedBox(
        width: visible.isEmpty ? 0 : size + step * (visible.length - 1),
        height: size,
        child: Stack(
          children: [
            for (var i = 0; i < visible.length; i++)
              Positioned(
                left: step * i,
                child: UploaderAvatar(uploader: visible[i], size: size, borderColor: XploreColors.background),
              ),
          ],
        ),
      ),
    );
  }
}
