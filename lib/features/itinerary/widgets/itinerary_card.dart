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

  const ItineraryCard({
    required this.dailyPlan,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: XploreColors.alternate,
      ),
      child: Material(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
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
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    XploreIconBtn(
                      onTapCallback: () => log('liked!'),
                      bgColor: XploreColors.tertiary,
                      icon: Icon(
                        Icons.favorite_border_rounded,
                        color: XploreColors.alternate,
                        size: 25,
                      ),
                    ),
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
                        style: context.pText.headlineSmall?.copyWith(height: 1),
                      ),
                      Text(
                        dailyPlan.location,
                        style: context.pText.headlineSmall?.copyWith(fontSize: 20, height: 1.3),
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
