import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';

const _transitionDuration = Duration(milliseconds: 220);
const _backdropBlur = 8.0;
const _maxWidth = 360.0;
const _buttonHeight = 48.0;

// White on the error red falls below WCAG AA, so the destructive button uses near-black text.
const _onDestructive = Color(0xFF1A0604);

/// Shows the app's confirmation dialog over a blurred backdrop.
/// Resolves to true only when the user taps the confirm button; dismissing counts as cancel.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final confirmed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: XploreColors.background.withValues(alpha: 0.5),
    transitionDuration: _transitionDuration,
    pageBuilder: (_, _, _) => ConfirmDialog(
      icon: icon,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      final sigma = _backdropBlur * curved.value;
      // The filter only paints; taps outside the card still reach the dismissible barrier beneath.
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween<double>(begin: 0.94, end: 1).animate(curved), child: child),
        ),
      );
    },
  );
  return confirmed ?? false;
}

/// The card shown by [showConfirmDialog]: icon badge, title, message and stacked confirm / cancel buttons.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tone = destructive ? XploreColors.error : XploreColors.accent;

    return SafeArea(
      child: Align(
        // A dead-centred card looks like it is sagging, so it sits slightly above centre.
        alignment: const Alignment(0, -0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Semantics(
              scopesRoute: true,
              explicitChildNodes: true,
              child: Material(
                type: MaterialType.transparency,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: XploreColors.card,
                    // Capsule buttons inset by 12 sit concentric with this corner.
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(color: XploreColors.white.withValues(alpha: 0.09)),
                    boxShadow: [
                      BoxShadow(
                        color: XploreColors.background.withValues(alpha: 0.6),
                        blurRadius: 64,
                        offset: const Offset(0, 24),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 28, 12, 12),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: _IconBadge(icon: icon, tone: tone),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              children: [
                                Semantics(
                                  header: true,
                                  namesRoute: true,
                                  child: Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: XploreText.heading.copyWith(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.4,
                                      color: XploreColors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  message,
                                  textAlign: TextAlign.center,
                                  style: XploreText.body.copyWith(color: XploreColors.secondaryLabel),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(_buttonHeight),
                              backgroundColor: destructive ? XploreColors.error : null,
                              foregroundColor: destructive ? _onDestructive : null,
                            ),
                            child: Text(confirmLabel),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(_buttonHeight),
                              backgroundColor: XploreColors.raised,
                              foregroundColor: XploreColors.white,
                              textStyle: XploreText.bodyStrong,
                            ),
                            child: Text(cancelLabel),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.tone});

  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: tone.withValues(alpha: 0.16), shape: BoxShape.circle),
        child: Icon(icon, size: 24, color: tone),
      ),
    );
  }
}
