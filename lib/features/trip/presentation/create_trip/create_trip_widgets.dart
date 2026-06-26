import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';

/// Maps a [TripInterest] to a Material icon for the vibe step. Lives in the
/// presentation layer so the model stays Flutter-free.
IconData tripInterestIcon(TripInterest interest) => switch (interest) {
  TripInterest.food => Icons.restaurant_rounded,
  TripInterest.culture => Icons.museum_rounded,
  TripInterest.nightlife => Icons.nightlife_rounded,
  TripInterest.nature => Icons.park_rounded,
  TripInterest.shopping => Icons.shopping_bag_rounded,
  TripInterest.relaxation => Icons.spa_rounded,
};

/// A pill-shaped multi/single select chip used for interests, pace, budget.
class SelectableChip extends StatelessWidget {
  const SelectableChip({required this.label, required this.selected, required this.onTap, this.icon, super.key});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fill = selected ? XploreColors.alternate.withValues(alpha: 0.22) : XploreColors.white.withValues(alpha: 0.06);
    final border = selected ? XploreColors.alternate : XploreColors.glassBorder;
    final foreground = selected ? XploreColors.white : XploreColors.mutedText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radiusLg),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: paddingUnit * 1.1, vertical: paddingUnit * 0.85),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radiusLg),
            border: Border.all(color: border, width: selected ? 1.4 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 17, color: foreground), const SizedBox(width: paddingUnit * 0.5)],
              Text(
                label,
                style: context.pText.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-width selectable row with a title + supporting description, used for
/// the "who's coming" / pace choices where one option is picked at a time.
class SelectableTile extends StatelessWidget {
  const SelectableTile({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.leading,
    super.key,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final border = selected ? XploreColors.alternate : XploreColors.glassBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radiusMd),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(paddingUnit * 1.1),
          decoration: BoxDecoration(
            color: selected
                ? XploreColors.alternate.withValues(alpha: 0.16)
                : XploreColors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(radiusMd),
            border: Border.all(color: border, width: selected ? 1.4 : 1),
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                Icon(leading, size: 22, color: selected ? XploreColors.alternate : XploreColors.mutedText),
                const SizedBox(width: paddingUnit),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.pText.labelLarge?.copyWith(color: XploreColors.white)),
                    const SizedBox(height: 2),
                    Text(description, style: context.pText.bodySmall?.copyWith(color: XploreColors.subtleText)),
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: selected ? 1 : 0,
                child: Icon(Icons.check_circle_rounded, color: XploreColors.alternate, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standard header (eyebrow + title + subtitle) shown at the top of every step
/// body, keeping the flow visually consistent.
class StepHeader extends StatelessWidget {
  const StepHeader({required this.eyebrow, required this.title, required this.subtitle, super.key});

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: context.pText.labelSmall?.copyWith(color: XploreColors.alternate, letterSpacing: 1.4),
        ),
        const SizedBox(height: paddingUnit * 0.5),
        Text(title, style: context.pText.headlineMedium?.copyWith(letterSpacing: -0.5, height: 1.05)),
        const SizedBox(height: paddingUnit * 0.5),
        Text(subtitle, style: context.pText.bodyMedium?.copyWith(color: XploreColors.mutedText)),
      ],
    );
  }
}
