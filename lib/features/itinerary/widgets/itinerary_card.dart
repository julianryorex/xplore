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
                    const _SaveButton(),
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
                      Text(
                        dailyPlan.location,
                        style: context.pText.bodySmall?.copyWith(
                          color: XploreColors.white.withValues(alpha: 0.76),
                          letterSpacing: 0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

class _SaveButton extends StatelessWidget {
  const _SaveButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: XploreColors.black.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(radiusSm),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => log('liked!'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: paddingUnit, vertical: paddingUnit / 2),
          child: Text(
            'Save',
            style: context.pText.labelSmall?.copyWith(color: XploreColors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
