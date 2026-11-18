import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';

/// The "Try asking" inset grouped list. Tapping a row hands its text to
/// [onSelected]; the list itself sends nothing.
class AgentSuggestionList extends StatelessWidget {
  const AgentSuggestionList({required this.suggestions, required this.onSelected, super.key});

  final List<String> suggestions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Try asking',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: XploreColors.secondaryLabel),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(radiusLg),
          child: Material(
            color: XploreColors.card,
            child: Column(
              children: [
                for (var i = 0; i < suggestions.length; i++) ...[
                  if (i > 0) const _InsetHairline(),
                  _SuggestionRow(text: suggestions[i], onTap: () => onSelected(suggestions[i])),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(text, style: const TextStyle(fontSize: 17, color: XploreColors.white)),
              ),
              const SizedBox(width: 12),
              const Icon(CupertinoIcons.arrow_up_right, size: 18, color: XploreColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsetHairline extends StatelessWidget {
  const _InsetHairline();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 16),
      child: Divider(height: 1, thickness: 1, color: XploreColors.separator),
    );
  }
}
