import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';

/// A 44pt pill button with a solid fill, used for Home's inline actions
/// (Invite, Plan day). Pass a null [onPressed] to disable it.
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

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: backgroundColor.withValues(alpha: backgroundColor.a * 0.6),
        disabledForegroundColor: foregroundColor.withValues(alpha: 0.6),
        minimumSize: const Size(0, minTouchTarget),
        maximumSize: const Size(double.infinity, minTouchTarget),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        shape: const StadiumBorder(),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
