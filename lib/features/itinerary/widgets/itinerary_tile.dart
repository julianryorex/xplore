import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';

class ItineraryTile extends StatelessWidget {
  final LocationPlanModel locationPlan;
  final double width;
  final double height;

  const ItineraryTile({required this.locationPlan, required this.width, required this.height, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radiusMd))),
      clipBehavior: Clip.hardEdge,
      color: XploreColors.surfaceElevated,
      child: InkWell(
        onTap: () {
          // Being removed with the day page restyle.
        },
        child: Container(
          width: width - height - paddingUnit * 2, // minus row size && gap
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radiusMd),
            border: Border.all(color: XploreColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: paddingUnit),
            child: LayoutBuilder(
              builder: (context, bc) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: bc.maxWidth * 0.67,
                      child: Text(
                        locationPlan.name,
                        softWrap: true,
                        maxLines: 3,
                        style: XploreText.footnoteStrong.copyWith(color: XploreColors.white),
                      ),
                    ),
                    _buildIconBtn(Icons.map_rounded, () {}),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, dynamic callback) {
    return Material(
      color: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(100))),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: callback,
        child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(icon)),
      ),
    );
  }
}
