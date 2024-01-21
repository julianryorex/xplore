import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';

class ItineraryTile extends StatelessWidget {
  final LocationPlanModel locationPlan;
  final double width;
  final double height;

  const ItineraryTile({
    required this.locationPlan,
    required this.width,
    required this.height,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width - height - paddingUnit * 2, // minus row size && gap
      height: 80,
      decoration: BoxDecoration(
        color: XploreColors.alternate,
        borderRadius: BorderRadius.circular(15),
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
                    style: context.pText.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildIconBtn(Icons.map_rounded, () {}),
                    _buildIconBtn(Icons.info, () {}),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, dynamic callback) {
    return Material(
      color: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(100)),
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: callback,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon),
        ),
      ),
    );
  }
}
