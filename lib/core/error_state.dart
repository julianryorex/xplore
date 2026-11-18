import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';

/// An inline error banner for failure states (e.g. a trip/itinerary section
/// that could not load).
///
/// An opaque card with a left accent strip, a tinted icon chip, a title +
/// message, and an optional "Retry" action. Using the accent rather than red
/// keeps it reading as a recoverable status, not a jarring alert.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.title,
    required this.message,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
    this.retryLabel = 'Retry',
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(radiusLg);

    return ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: XploreColors.card,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4, color: XploreColors.accent),
              const SizedBox(width: paddingUnit),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: paddingUnit * 1.25),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: XploreColors.accentSoft),
                  child: Icon(icon, size: 19, color: XploreColors.accent),
                ),
              ),
              const SizedBox(width: paddingUnit),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: paddingUnit * 1.25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title, style: context.pText.labelMedium),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: context.pText.bodySmall?.copyWith(color: XploreColors.secondaryLabel),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(width: paddingUnit * 0.5),
                Padding(
                  padding: const EdgeInsets.only(right: paddingUnit * 0.75),
                  child: TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: XploreColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: paddingUnit),
                      minimumSize: const Size(minTouchTarget, minTouchTarget),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(retryLabel),
                  ),
                ),
              ] else
                // Mirror the left inset (accent strip + gap) so the text isn't
                // flush against the right edge.
                const SizedBox(width: paddingUnit * 1.5),
            ],
          ),
        ),
      ),
    );
  }
}
