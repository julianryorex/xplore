import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';

/// The large question at the top of a create-trip step ("Where to?").
class CreateStepTitle extends StatelessWidget {
  const CreateStepTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: XploreText.title.copyWith(color: XploreColors.white)),
    );
  }
}

/// One supporting line under a [CreateStepTitle].
class CreateStepSubtitle extends StatelessWidget {
  const CreateStepSubtitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text, style: XploreText.body.copyWith(color: XploreColors.secondaryLabel)),
    );
  }
}

/// An uppercase tracked label that names a group of controls ("NIGHTS IN EACH PLACE").
class CreateOverline extends StatelessWidget {
  const CreateOverline(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: XploreText.overline.copyWith(color: XploreColors.secondaryLabel));
  }
}

/// The hairline that separates rows laid directly on the background.
class CreateHairline extends StatelessWidget {
  const CreateHairline({super.key});

  @override
  Widget build(BuildContext context) => const Divider(height: 1, thickness: 1, color: XploreColors.raised);
}

/// A +/- control for a stepper: an outlined 32pt circle inside a 44pt touch
/// target, announced to screen readers as [label]. A null [onTap] disables it.
class CreateStepperButton extends StatelessWidget {
  const CreateStepperButton({required this.icon, required this.label, required this.onTap, super.key});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    final handleTap = onTap == null
        ? null
        : () {
            HapticFeedback.selectionClick();
            onTap();
          };

    // The ink response's own semantics are excluded so the button is read as
    // just [label]; the tap action is re-attached here for screen readers.
    return Semantics(
      button: true,
      enabled: handleTap != null,
      label: label,
      onTap: handleTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: handleTap,
        radius: minTouchTarget / 2,
        child: SizedBox.square(
          dimension: minTouchTarget,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: XploreColors.raised),
              ),
              child: Icon(icon, size: 16, color: handleTap != null ? XploreColors.white : XploreColors.tertiaryLabel),
            ),
          ),
        ),
      ),
    );
  }
}

/// The number between two [CreateStepperButton]s. It never wraps, and holds a
/// fixed minimum width so the buttons stay put as the value changes.
class CreateStepperValue extends StatelessWidget {
  const CreateStepperValue(this.value, {required this.semanticsLabel, this.minWidth = 30, super.key});

  final int value;
  final String semanticsLabel;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: Text(
        '$value',
        textAlign: TextAlign.center,
        maxLines: 1,
        softWrap: false,
        semanticsLabel: semanticsLabel,
        style: XploreText.stat.copyWith(color: XploreColors.white),
      ),
    );
  }
}

/// Horizontal inset every create-trip step uses for its content.
const createStepGutter = 20.0;
