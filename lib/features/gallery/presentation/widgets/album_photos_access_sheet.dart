import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';

/// Explains that Save all needs Photos access and where to turn it on.
///
/// The app cannot deep-link into its Settings page, so the sheet names the path
/// and closes with a single acknowledgement.
Future<void> showPhotosAccessSheet(BuildContext context, {required String albumName}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: XploreColors.card,
    barrierColor: const Color(0x9E000000),
    showDragHandle: false,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl))),
    builder: (context) => _PhotosAccessSheet(albumName: albumName),
  );
}

class _PhotosAccessSheet extends StatelessWidget {
  const _PhotosAccessSheet({required this.albumName});

  final String albumName;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 34),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(color: XploreColors.tertiaryLabel, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 26),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: XploreColors.raised, borderRadius: BorderRadius.circular(radiusMd)),
              child: const Icon(Icons.no_photography_outlined, size: 28, color: XploreColors.white),
            ),
            const SizedBox(height: 18),
            Semantics(
              header: true,
              child: Text(
                'Xplore can\'t save to Photos',
                textAlign: TextAlign.center,
                style: XploreText.title.copyWith(fontSize: 24, letterSpacing: -0.6, color: XploreColors.white),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Photos access is turned off, so the album “$albumName” can\'t be created. '
              'Allow access in Settings, then press Save all again.',
              textAlign: TextAlign.center,
              style: XploreText.body.copyWith(color: XploreColors.secondaryLabel),
            ),
            const SizedBox(height: 18),
            const _SettingsPath(),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: XploreColors.white,
                  foregroundColor: XploreColors.background,
                  minimumSize: const Size(0, 50),
                  shape: const StadiumBorder(),
                  visualDensity: VisualDensity.standard,
                  textStyle: XploreText.bodyStrong.copyWith(fontWeight: FontWeight.w600),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsPath extends StatelessWidget {
  const _SettingsPath();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: XploreColors.raised, borderRadius: BorderRadius.circular(radiusMd)),
      child: Row(
        children: [
          const Icon(Icons.settings_outlined, size: 18, color: XploreColors.secondaryLabel),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Settings › Xplore › Photos',
              style: XploreText.footnote.copyWith(color: XploreColors.inactiveControl),
            ),
          ),
        ],
      ),
    );
  }
}
