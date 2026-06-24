import 'package:flutter/material.dart';

/// An [IndexedStack] that cross-fades when [index] changes and only builds a
/// child once it has first been selected.
///
/// Top-level destinations (the bottom-tab screens) are *siblings*, not a
/// push/pop hierarchy, so switching between them should never feel like
/// forward/back navigation. A short, directionless fade is the Material
/// "fade through" cue for moving between unrelated destinations.
///
/// Children that have been shown stay alive (their state — scroll offset, the
/// live Google Map camera, etc. — is preserved) while children that have never
/// been visited are not built at all, so an expensive tab (the map) doesn't pay
/// its init cost until the user actually opens it.
class FadeIndexedStack extends StatefulWidget {
  const FadeIndexedStack({
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOutCubic,
    super.key,
  });

  final int index;
  final List<Widget> children;
  final Duration duration;
  final Curve curve;

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<bool> _activated;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1,
    );
    _activated = List<bool>.generate(
      widget.children.length,
      (i) => i == widget.index,
    );
  }

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _activated[widget.index] = true;
      // Fade the newly revealed tab in from transparent. Because the stack only
      // paints the selected child, this reads as a soft fade-through.
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller.drive(CurveTween(curve: widget.curve)),
      child: IndexedStack(
        index: widget.index,
        sizing: StackFit.expand,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            _activated[i] ? widget.children[i] : const SizedBox.shrink(),
        ],
      ),
    );
  }
}
