import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';

/// A borderless card holding a list of rows separated by inset hairlines, as
/// on Home's itinerary section. Rows bring their own padding and ink.
class GroupedCard extends StatelessWidget {
  const GroupedCard({required this.children, this.separatorIndent = InsetSeparator.defaultIndent, super.key});

  final List<Widget> children;

  /// Where the hairlines start, so they line up with the rows' text.
  final double separatorIndent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: XploreColors.card,
      borderRadius: BorderRadius.circular(radiusLg),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) InsetSeparator(indent: separatorIndent),
            child,
          ],
        ],
      ),
    );
  }
}

/// The hairline between rows of a [GroupedCard], inset to clear the leading tile.
class InsetSeparator extends StatelessWidget {
  const InsetSeparator({this.indent = defaultIndent, super.key});

  static const defaultIndent = 68.0;

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: const ColoredBox(
        color: XploreColors.separator,
        child: SizedBox(height: 1, width: double.infinity),
      ),
    );
  }
}
