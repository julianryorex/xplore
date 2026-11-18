import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';

/// A Home section title ("Itinerary", "Shared gallery") with an optional
/// accent text action on the trailing edge.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({required this.title, this.actionLabel, this.onAction, super.key});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: XploreText.heading.copyWith(color: XploreColors.white)),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: XploreColors.accent,
              minimumSize: const Size(minTouchTarget, minTouchTarget),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: XploreText.footnoteStrong,
            ),
            child: Text(actionLabel),
          ),
      ],
    );
  }
}
