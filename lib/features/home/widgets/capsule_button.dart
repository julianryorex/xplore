import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';

/// A 36pt pill button with a solid fill, used for Home's inline actions
/// (Invite, Plan day). Its tap target is padded out to at least
/// [minTouchTarget]. Pass a null [onPressed] to disable it.
class CapsuleButton extends StatelessWidget {
  const CapsuleButton({
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.leading,
    this.horizontalPadding = 16,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  /// Optional icon or spinner shown before the label.
  final Widget? leading;
  final double horizontalPadding;

  static const _height = 36.0;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: backgroundColor.withValues(alpha: backgroundColor.a * 0.6),
        disabledForegroundColor: foregroundColor.withValues(alpha: 0.6),
        minimumSize: const Size(0, _height),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        shape: const StadiumBorder(),
        // A padded target is 48pt at standard density; pinning the density keeps
        // macOS's compact default from shrinking it below minTouchTarget.
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: XploreText.bodyStrong,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Text(label),
        ],
      ),
    );
  }
}
