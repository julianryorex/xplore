import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';

/// The first-trip "Ways to start" grid: a full-width "Describe your trip" tile
/// above "Step by step" and "Join a trip".
class EmptyHomeStartTiles extends StatelessWidget {
  const EmptyHomeStartTiles({required this.onDescribe, required this.onStepByStep, required this.onJoin, super.key});

  final VoidCallback onDescribe;
  final VoidCallback onStepByStep;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DescribeTile(onTap: onDescribe),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SmallTile(
                  icon: CupertinoIcons.list_bullet,
                  title: 'Step by step',
                  subtitle: 'Fill in the details yourself',
                  onTap: onStepByStep,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallTile(
                  icon: CupertinoIcons.link,
                  title: 'Join a trip',
                  subtitle: 'Use a friend’s invite link',
                  onTap: onJoin,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DescribeTile extends StatelessWidget {
  const _DescribeTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TileSurface(
      color: XploreColors.accentSoft,
      minHeight: 104,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: const Row(
        children: [
          Icon(CupertinoIcons.chat_bubble, size: 28, color: XploreColors.accent),
          SizedBox(width: 14),
          Expanded(
            child: _TileText(
              title: 'Describe your trip',
              subtitle: 'Say where and when, and get a day-by-day draft',
              titleStyle: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: XploreColors.white,
              ),
              subtitleStyle: TextStyle(fontSize: 14, height: 1.35, color: XploreColors.inactiveControl),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallTile extends StatelessWidget {
  const _SmallTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TileSurface(
      color: XploreColors.card,
      minHeight: 116,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 24, color: XploreColors.white),
          const SizedBox(height: 12),
          _TileText(
            title: title,
            subtitle: subtitle,
            titleStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: XploreColors.white,
            ),
            subtitleStyle: const TextStyle(fontSize: 13, color: XploreColors.secondaryLabel),
          ),
        ],
      ),
    );
  }
}

class _TileText extends StatelessWidget {
  const _TileText({required this.title, required this.subtitle, required this.titleStyle, required this.subtitleStyle});

  final String title;
  final String subtitle;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: titleStyle),
        const SizedBox(height: 2),
        Text(subtitle, style: subtitleStyle),
      ],
    );
  }
}

class _TileSurface extends StatelessWidget {
  const _TileSurface({
    required this.color,
    required this.minHeight,
    required this.padding,
    required this.onTap,
    required this.child,
  });

  final Color color;
  final double minHeight;
  final EdgeInsets padding;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
