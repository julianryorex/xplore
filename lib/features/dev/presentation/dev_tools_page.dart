import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/ambient_background.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/layout_padding.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/routes.dart';

/// Developer-only utilities (FEAT-008), moved off the production Home screen.
/// Reached from a `kDebugMode`-gated entry in Profile; the page itself assumes
/// it's only ever pushed in debug builds.
class DevToolsPage extends StatelessWidget {
  const DevToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XploreColors.primaryBg,
      body: AmbientBackground(
        child: SafeArea(
          bottom: false,
          child: LayoutPadding(
            header: Header(
              leadingWidget: GlassIconButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
              titleWidget: Text('Developer', textAlign: TextAlign.center, style: context.pText.headlineSmall),
              trailingWidget: const SizedBox(width: headerIconButtonSize),
            ),
            child: ListView(
              children: [
                const SizedBox(height: paddingUnit),
                Text(
                  'Debug utilities. These are only available in debug builds.',
                  style: context.pText.bodySmall?.copyWith(color: XploreColors.mutedText),
                ),
                const SizedBox(height: paddingUnit * 1.5),
                _DevTile(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Upload sample to gallery',
                  subtitle: 'Opens the gallery and uploads a test image.',
                  onTap: () async {
                    final gallery = context.read<GalleryCubit>();
                    context.push(Paths.gallery);
                    await gallery.uploadToGallery();
                  },
                ),
                _DevTile(
                  icon: Icons.delete_sweep_outlined,
                  title: 'Delete Hive caches',
                  subtitle: 'Clears local gallery + profile/marker caches.',
                  onTap: () {
                    context.read<GalleryCubit>().deleteAll();
                    context.read<ProfileCubit>().deleteAll();
                  },
                ),
                _DevTile(
                  icon: Icons.bug_report_outlined,
                  title: 'Trigger trip error state',
                  subtitle: 'Forces TripCubit into its error banner for preview.',
                  onTap: () => context.read<TripCubit>().debugTriggerError(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DevTile extends StatelessWidget {
  const _DevTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: paddingUnit),
      child: GlassSurface(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(paddingUnit * 0.75),
              decoration: BoxDecoration(
                color: XploreColors.alternate.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(radiusSm),
                border: Border.all(color: XploreColors.alternate.withValues(alpha: 0.32)),
              ),
              child: Icon(icon, size: 22, color: XploreColors.alternate),
            ),
            const SizedBox(width: paddingUnit),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.pText.labelLarge),
                  const SizedBox(height: 2),
                  Text(subtitle, style: context.pText.bodySmall?.copyWith(color: XploreColors.mutedText)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: XploreColors.mutedText),
          ],
        ),
      ),
    );
  }
}
