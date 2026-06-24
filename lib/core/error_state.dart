import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';

/// A liquid-glass error banner for inline failure states (e.g. a trip/itinerary
/// section that could not load).
///
/// The design: a teal-tinted frosted-glass panel that sits on a soft grounding
/// shadow, with a left brand accent strip, a nested glass icon chip, a title +
/// message, and an optional "Retry" action. The teal tint ties the surface to
/// the app's accent so the banner reads as an on-brand status rather than a
/// jarring red alert.
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
    final accent = XploreColors.alternate;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          // Soft grounding shadow lifts the panel off the page.
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: glassBlur, sigmaY: glassBlur),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                color: accent.withValues(alpha: 0.12),
                border: Border.all(color: accent.withValues(alpha: 0.24)),
              ),
              child: Stack(
                children: [
                  // Specular top highlight, the standard glass rim light.
                  Positioned(
                    top: 0,
                    left: radiusLg,
                    right: radiusLg,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            XploreColors.white.withValues(alpha: 0),
                            XploreColors.glassHighlight,
                            XploreColors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        // Left accent strip (frosted, brighter at the top).
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(radiusLg),
                            bottomLeft: Radius.circular(radiusLg),
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                            child: Container(
                              width: 6,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [accent.withValues(alpha: 0.50), accent.withValues(alpha: 0.18)],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: paddingUnit),
                        // Nested glass icon chip.
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: paddingUnit * 1.25),
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accent.withValues(alpha: 0.12),
                                  border: Border.all(color: accent.withValues(alpha: 0.30), width: 0.5),
                                ),
                                child: Icon(icon, size: 19, color: accent.withValues(alpha: 0.85)),
                              ),
                            ),
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
                                  style: context.pText.bodySmall?.copyWith(
                                    color: XploreColors.white.withValues(alpha: 0.60),
                                  ),
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
                            padding: const EdgeInsets.only(right: paddingUnit * 1.25),
                            child: TextButton(
                              onPressed: onRetry,
                              style: TextButton.styleFrom(
                                foregroundColor: accent.withValues(alpha: 0.85),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: paddingUnit,
                                  vertical: paddingUnit * 0.5,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text(retryLabel),
                            ),
                          ),
                        ] else
                          // Mirror the left inset (accent strip + gap) so the
                          // text isn't flush against the right edge.
                          const SizedBox(width: paddingUnit * 1.5),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
