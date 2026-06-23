import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/routes.dart';

class ItineraryCard extends StatelessWidget {
  final DailyPlanModel dailyPlan;

  static const width = 230.0;
  static const height = 300.0;

  const ItineraryCard({required this.dailyPlan, super.key});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(radiusLg);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // Greens nudged toward the dark base to mute the saturation slightly,
          // and the dark brought in a touch earlier — keeps the brand feel but
          // tones the green down a notch.
          colors: [
            Color.lerp(XploreColors.alternate, XploreColors.primary, 0.12)!,
            Color.lerp(XploreColors.secondary, XploreColors.primary, 0.24)!,
            XploreColors.primary,
          ],
          stops: const [0, 0.5, 1],
        ),
        border: Border.all(color: XploreColors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: XploreColors.alternate.withValues(alpha: 0.16),
            blurRadius: 32,
            spreadRadius: -6,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Material(
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.pushNamed(context, Paths.itineraryOverview, arguments: dailyPlan);
          },
          child: Stack(
            children: [
              // Soft sheen sweeping across the top-left to give the surface depth.
              Positioned(
                top: -60,
                left: -40,
                child: IgnorePointer(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [XploreColors.white.withValues(alpha: 0.20), XploreColors.white.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(paddingUnit * 1.25),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _GlassChip(label: 'Daily plan', icon: Icons.route_rounded),
                        const _SaveButton(),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            dailyPlan.title,
                            style: context.pText.headlineSmall?.copyWith(height: 1.06, letterSpacing: -0.4),
                          ),
                          const SizedBox(height: paddingUnit / 2),
                          Row(
                            children: [
                              Icon(Icons.place_outlined, size: 15, color: XploreColors.white.withValues(alpha: 0.82)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  dailyPlan.location,
                                  style: context.pText.bodySmall?.copyWith(
                                    color: XploreColors.white.withValues(alpha: 0.82),
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _GlassChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: paddingUnit * 0.75, vertical: paddingUnit / 2),
      decoration: BoxDecoration(
        color: XploreColors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(radiusSm),
        border: Border.all(color: XploreColors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: XploreColors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: context.pText.labelSmall?.copyWith(color: XploreColors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: XploreColors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(radiusSm),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          log('liked!');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: paddingUnit * 0.75, vertical: paddingUnit / 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_outline_rounded, size: 13, color: XploreColors.white),
              const SizedBox(width: 5),
              Text(
                'Save',
                style: context.pText.labelSmall?.copyWith(color: XploreColors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
