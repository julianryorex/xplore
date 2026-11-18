import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';

/// First word of a profile's display name, or null when it has none.
String? firstNameOf(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  return words.first.isEmpty ? null : words.first;
}

/// Phrases [question] as a greeting, e.g. "Where to first, Alex?", dropping
/// the name when the profile has none.
String greetingFor(String question, String profileName) {
  final name = firstNameOf(profileName);
  return name == null ? '$question?' : '$question, $name?';
}

/// The 52pt accent disc with xplore's sparkle that marks agent surfaces.
class AgentBadge extends StatelessWidget {
  const AgentBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox.square(
        dimension: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(color: XploreColors.accent, shape: BoxShape.circle),
          child: Icon(Icons.auto_awesome, size: 28, color: XploreColors.onAccent),
        ),
      ),
    );
  }
}

/// The badge above a large greeting, with an optional secondary line beneath.
class AgentHero extends StatelessWidget {
  const AgentHero({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AgentBadge(),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 40,
              height: 1.05,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
              color: XploreColors.white,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 14),
          Text(subtitle, style: const TextStyle(fontSize: 17, height: 1.4, color: XploreColors.secondaryLabel)),
        ],
      ],
    );
  }
}
