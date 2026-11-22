import 'package:flutter/material.dart';

/// Fades [child] in while sliding it up by [distance], following [animation]
/// (0 to 1). Values past 1 from an overshooting curve only move it.
class OnboardingRiseIn extends StatelessWidget {
  const OnboardingRiseIn({required this.animation, required this.child, this.distance = 24, super.key});

  final Animation<double> animation;
  final double distance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, distance * (1 - animation.value)), child: child),
      ),
    );
  }
}
