import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/icon_button.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/routes.dart';

class ItineraryCard extends StatelessWidget {
  final DailyPlanModel dailyPlan;

  static const width = 230.0;
  static const height = 300.0;

  const ItineraryCard({required this.dailyPlan, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [XploreColors.alternate, XploreColors.secondary, XploreColors.surfaceElevated],
          stops: const [0, 0.58, 1],
        ),
        boxShadow: [
          BoxShadow(color: XploreColors.alternate.withValues(alpha: 0.18), blurRadius: 28, offset: const Offset(0, 16)),
        ],
      ),
      child: Material(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
        clipBehavior: Clip.hardEdge,
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.pushNamed(context, Paths.itineraryOverview, arguments: dailyPlan);
          },
          child: Padding(
            padding: const EdgeInsets.all(paddingUnit),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: paddingUnit, vertical: paddingUnit / 2),
                      decoration: BoxDecoration(
                        color: XploreColors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(radiusSm),
                      ),
                      child: Text('Daily plan', style: context.pText.labelSmall?.copyWith(color: XploreColors.white)),
                    ),
                    XploreIconBtn(
                      onTapCallback: () => log('liked!'),
                      size: 40,
                      borderRadius: radiusSm,
                      bgColor: XploreColors.black.withValues(alpha: 0.22),
                      icon: Icon(Icons.favorite_border_rounded, color: XploreColors.white, size: 20),
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(dailyPlan.title, style: context.pText.headlineSmall?.copyWith(height: 1.08)),
                      const SizedBox(height: paddingUnit / 2),
                      Row(
                        children: [
                          Icon(Icons.place_outlined, size: 16, color: XploreColors.white.withValues(alpha: 0.76)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              dailyPlan.location,
                              style: context.pText.bodySmall?.copyWith(
                                color: XploreColors.white.withValues(alpha: 0.76),
                              ),
                              maxLines: 2,
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
        ),
      ),
    );
  }
}
