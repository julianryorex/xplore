import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/features/agent/models/quick_menu_entries.dart';
import 'package:xplore/features/agent/presentation/agent_page.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/routes.dart';

const _panelWidth = 280.0;
const _panelRadius = BorderRadius.all(Radius.circular(radiusLg));

/// The agent quick menu: a dimming scrim plus a glass panel anchored above the
/// tab bar's agent button. Lay it over the shell body, beneath the tab bar.
///
/// It animates itself in and out as [isOpen] changes and builds nothing while closed.
class AgentQuickMenu extends StatefulWidget {
  const AgentQuickMenu({required this.isOpen, required this.onClose, required this.bottomOffset, super.key});

  final bool isOpen;

  /// Called when the scrim is tapped or an entry is chosen.
  final VoidCallback onClose;

  /// Distance from the bottom of the screen to the bottom of the panel.
  final double bottomOffset;

  @override
  State<AgentQuickMenu> createState() => _AgentQuickMenuState();
}

class _AgentQuickMenuState extends State<AgentQuickMenu> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    reverseDuration: const Duration(milliseconds: 150),
    value: widget.isOpen ? 1 : 0,
  );
  late final _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  late final _panelScale = Tween<double>(begin: 0.9, end: 1).animate(_progress);

  @override
  void didUpdateWidget(AgentQuickMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen == widget.isOpen) return;

    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.isOpen ? 1 : 0;
    } else if (widget.isOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isDismissed) return const SizedBox.shrink();

        return Stack(
          children: [
            Positioned.fill(
              child: FadeTransition(
                opacity: _progress,
                child: ModalBarrier(
                  color: XploreColors.background.withValues(alpha: 0.5),
                  onDismiss: widget.onClose,
                  semanticsLabel: 'Close menu',
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: widget.bottomOffset,
              width: _panelWidth,
              child: FadeTransition(
                opacity: _progress,
                child: ScaleTransition(
                  alignment: Alignment.bottomRight,
                  scale: _panelScale,
                  child: _QuickMenuPanel(onClose: widget.onClose),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickMenuPanel extends StatelessWidget {
  const _QuickMenuPanel({required this.onClose});

  final VoidCallback onClose;

  void _open(BuildContext context, String route, {Object? arguments}) {
    onClose();
    Navigator.of(context).pushNamed(route, arguments: arguments);
  }

  @override
  Widget build(BuildContext context) {
    final entries = QuickMenuEntries.from(
      trip: context.watch<TripCubit>().state,
      itinerary: context.watch<ItineraryCubit>().state,
    );
    final planDayPrompt = entries.planDayPrompt;

    return _FrostedPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _QuickMenuRow(
            label: 'Plan a new trip',
            icon: CupertinoIcons.globe,
            onTap: () => _open(context, Paths.createTrip),
          ),
          const _GroupBand(),
          if (planDayPrompt != null) ...[
            _QuickMenuRow(
              label: planDayPrompt,
              icon: Icons.auto_awesome,
              accent: true,
              onTap: () => _open(context, Paths.agent, arguments: AgentPageArgs(initialPrompt: planDayPrompt)),
            ),
            const _Hairline(),
          ],
          _QuickMenuRow(
            label: 'Ask anything',
            icon: CupertinoIcons.chat_bubble,
            accent: true,
            onTap: () => _open(context, Paths.agent),
          ),
        ],
      ),
    );
  }
}

class _FrostedPanel extends StatelessWidget {
  const _FrostedPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _panelRadius,
        boxShadow: [
          BoxShadow(color: XploreColors.background.withValues(alpha: 0.6), offset: const Offset(0, 16), blurRadius: 48),
        ],
      ),
      child: ClipRRect(
        borderRadius: _panelRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: XploreColors.glassChromeStrong,
              borderRadius: _panelRadius,
              border: Border.all(color: XploreColors.glassChromeBorder),
            ),
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
  }
}

class _QuickMenuRow extends StatelessWidget {
  const _QuickMenuRow({required this.label, required this.icon, required this.onTap, this.accent = false});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Agent entries are drawn in the accent colour to set them apart from plain actions.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? XploreColors.accent : XploreColors.white;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(fontSize: 17, color: color, fontWeight: accent ? FontWeight.w600 : FontWeight.w400),
                  ),
                ),
                Icon(icon, size: 20, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: XploreColors.glassChromeBorder, child: SizedBox(height: 1));
}

/// The darker band that separates plain actions from the agent entries.
class _GroupBand extends StatelessWidget {
  const _GroupBand();

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: XploreColors.background.withValues(alpha: 0.35), child: const SizedBox(height: 8));
}
