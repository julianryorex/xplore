import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';

/// The 56pt capsule text field with a round accent send button used by the
/// agent screen and the first-trip Home. A null [onSend] dims and disables send.
class AgentComposer extends StatelessWidget {
  const AgentComposer({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    this.borderColor = XploreColors.accent,
    this.onSend,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final Color borderColor;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 20, right: 6),
      decoration: BoxDecoration(
        color: XploreColors.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              cursorColor: XploreColors.accent,
              textInputAction: onSend == null ? TextInputAction.done : TextInputAction.send,
              onSubmitted: onSend == null ? null : (_) => onSend!(),
              style: const TextStyle(fontSize: 17, color: XploreColors.white),
              decoration: InputDecoration.collapsed(
                hintText: placeholder,
                hintStyle: const TextStyle(fontSize: 17, color: XploreColors.secondaryLabel),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(onPressed: onSend),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Send',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: minTouchTarget,
          child: Center(
            child: AnimatedOpacity(
              opacity: enabled ? 1 : 0.35,
              duration: const Duration(milliseconds: 150),
              child: const SizedBox.square(
                dimension: 40,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: XploreColors.accent, shape: BoxShape.circle),
                  child: Icon(CupertinoIcons.arrow_up, size: 20, color: XploreColors.onAccent),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pins [child] to the bottom edge with 16pt side margins, sitting just above
/// the home indicator, or 12pt above the keyboard while it is open.
///
/// Expects the enclosing [Scaffold] to resize for the keyboard (its default),
/// so only the gap changes here, not the position.
class ComposerDock extends StatefulWidget {
  const ComposerDock({required this.child, super.key});

  final Widget child;

  @override
  State<ComposerDock> createState() => _ComposerDockState();
}

class _ComposerDockState extends State<ComposerDock> with WidgetsBindingObserver {
  static const _minGap = 12.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => setState(() {});

  // Reads the window's raw insets because an enclosing Scaffold strips the
  // bottom padding and keyboard inset from the MediaQuery its body sees.
  double _bottomGap() {
    final window = MediaQueryData.fromView(View.of(context));
    if (window.viewInsets.bottom > 0) {
      return _minGap;
    }
    return math.max(_minGap, window.viewPadding.bottom - 8);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, _bottomGap()), child: widget.child);
  }
}
