import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
import 'package:xplore/core/layout_padding.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/itinerary/widgets/itinerary_tile.dart';
import 'package:xplore/utilities/utilities.dart';

class ItineraryOverviewPage extends StatelessWidget {
  final DailyPlanModel dailyPlan;

  const ItineraryOverviewPage({required this.dailyPlan, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ItineraryHeroHeader(location: dailyPlan.location, imageUrl: _resolveHeroImageUrl(dailyPlan)),
                  LayoutPadding(
                    enableHeaderPadding: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dailyPlan.title, style: context.pText.headlineMedium),
                        const SizedBox(height: 30),
                        _renderChecklist(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Header(
                leadingWidget: XploreIconBtn(
                  bgColor: XploreColors.darkBg,
                  onTapCallback: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: headerIconSize),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderChecklist() {
    return LayoutBuilder(
      builder: (context, bc) {
        const rowSize = 60.0;

        return SizedBox(
          width: bc.maxWidth,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  ...dailyPlan.plan.locations.map(
                    (el) => Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 40),
                      child: _renderCheckOrCircle(el, rowSize),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: paddingUnit * 2),
              Column(
                children: [
                  ...dailyPlan.plan.locations.map(
                    (el) => Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: ItineraryTile(locationPlan: el, width: bc.maxWidth, height: rowSize),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Resolves the cover image for the day's hero header.
  ///
  /// The itinerary models ([DailyPlanModel] / [LocationPlanModel]) carry no
  /// image/photo/cover URL field today, so there is no real image to show and
  /// this returns `null`, which renders the neutral brand placeholder. When the
  /// data layer gains a real cover image (e.g. a place photo), return it here and
  /// [_ItineraryHeroHeader] will render it via `Image.network`.
  String? _resolveHeroImageUrl(DailyPlanModel dailyPlan) => null;

  Widget _renderCheckOrCircle(LocationPlanModel locationPlan, double rowSize) {
    if (locationPlan.completed) {
      return XploreIconBtn(
        icon: Icon(Icons.check, color: XploreColors.darkBg, size: 30),
        onTapCallback: () {},
        size: rowSize,
        borderRadius: 100,
      );
    }
    return XploreIconBtn(
      onTapCallback: () {},
      size: rowSize,
      borderColor: XploreColors.alternate,
      bgColor: XploreColors.darkBg,
      borderRadius: 100,
    );
  }
}

/// Hero header for the itinerary overview.
///
/// When a real [imageUrl] is available it renders the actual place photo via
/// `Image.network` (with loading + error fallbacks). Otherwise — or while the
/// image is loading / failed — it shows a neutral, brand-tinted placeholder
/// instead of any city-specific demo imagery.
class _ItineraryHeroHeader extends StatelessWidget {
  final String location;
  final String? imageUrl;

  const _ItineraryHeroHeader({required this.location, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final height = getScreenHeight(context: context, percent: 0.45);
    final url = imageUrl;
    final hasImage = url != null && url.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: hasImage
          ? Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _NeutralHeroBackdrop(location: location, showProgress: true);
              },
              errorBuilder: (context, error, stackTrace) => _NeutralHeroBackdrop(location: location),
            )
          : _NeutralHeroBackdrop(location: location),
    );
  }
}

/// Neutral, design-system-aligned placeholder used when there is no real cover
/// image (or while one is loading / has failed). A soft brand-tinted gradient
/// with an ambient glow and a subtle location label — deliberately free of any
/// city-specific imagery.
class _NeutralHeroBackdrop extends StatelessWidget {
  final String location;
  final bool showProgress;

  const _NeutralHeroBackdrop({required this.location, this.showProgress = false});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [XploreColors.primaryBg, XploreColors.tertiary, XploreColors.secondaryBg.withValues(alpha: 0.55)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      XploreColors.alternate.withValues(alpha: 0.28),
                      XploreColors.alternate.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.travel_explore, size: 48, color: XploreColors.subtleText),
                if (location.trim().isNotEmpty) ...[
                  const SizedBox(height: paddingUnit),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: paddingUnit * 2),
                    child: Text(
                      location,
                      textAlign: TextAlign.center,
                      style: context.pText.titleMedium?.copyWith(color: XploreColors.mutedText),
                    ),
                  ),
                ],
                if (showProgress) ...[
                  const SizedBox(height: paddingUnit * 1.5),
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: XploreColors.alternate),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
