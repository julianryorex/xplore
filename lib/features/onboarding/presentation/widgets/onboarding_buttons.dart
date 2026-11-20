import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';

const _buttonHeight = 52.0;

// Bespoke size: onboarding's actions are a step larger than the app's 15pt
// button labels, since each screen has a single action to draw the eye to.
const _labelStyle = TextStyle(
  fontFamily: systemFontFamily,
  fontSize: 16,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.2,
);

/// The one main action of an onboarding screen: a full-width Jade capsule.
/// A null [onPressed] disables it; [loading] swaps the label for a spinner and
/// blocks taps.
class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: XploreColors.accent,
        foregroundColor: XploreColors.onAccent,
        // A loading button keeps its colour so the spinner stays legible.
        disabledBackgroundColor: loading ? XploreColors.accent : XploreColors.raised,
        disabledForegroundColor: loading ? XploreColors.onAccent : XploreColors.tertiaryLabel,
        minimumSize: const Size.fromHeight(_buttonHeight),
        shape: const StadiumBorder(),
        textStyle: _labelStyle,
      ),
      child: loading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: XploreColors.onAccent),
            )
          : _ButtonLabel(label: label, icon: icon),
    );
  }
}

/// A full-width outlined capsule for a screen's second, equally valid action.
class OnboardingSecondaryButton extends StatelessWidget {
  const OnboardingSecondaryButton({required this.label, required this.onPressed, this.icon, super.key});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: XploreColors.white,
        side: const BorderSide(color: XploreColors.separator),
        minimumSize: const Size.fromHeight(_buttonHeight),
        shape: const StadiumBorder(),
        textStyle: _labelStyle.copyWith(fontWeight: FontWeight.w500),
      ),
      child: _ButtonLabel(label: label, icon: icon),
    );
  }
}

/// A quiet full-width text action ("Not now", "I'll do this later").
class OnboardingTextButton extends StatelessWidget {
  const OnboardingTextButton({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: XploreColors.secondaryLabel,
        minimumSize: const Size.fromHeight(minTouchTarget),
        textStyle: XploreText.body,
      ),
      child: Text(label),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.label, required this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
