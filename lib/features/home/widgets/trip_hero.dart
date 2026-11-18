import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/home/models/trip_overview.dart';

/// The top of the trip home: trip name, its place headline (`TripModel.headline`)
/// as a large title, and the date range with the trip's length.
class TripHero extends StatelessWidget {
  const TripHero({required this.overview, super.key});

  final TripOverview overview;

  @override
  Widget build(BuildContext context) {
    final trip = overview.trip;
    final destination = trip.headline;
    final hasDestination = destination != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasDestination) ...[
            Text(
              trip.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: XploreText.footnoteStrong.copyWith(color: XploreColors.accent),
            ),
            const SizedBox(height: 6),
          ],
          _HeroTitle(destination ?? trip.title),
          const SizedBox(height: 8),
          Text(_subtitle(), style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel)),
        ],
      ),
    );
  }

  String _subtitle() {
    final length = overview.lengthInDays;
    final lengthLabel = length == null ? null : '$length ${length == 1 ? 'day' : 'days'}';
    final range = overview.dateRangeLabel;
    if (range != null && lengthLabel != null) {
      return '$range · $lengthLabel';
    }
    return range ?? lengthLabel ?? 'Dates not set';
  }
}

/// The display-size title, stepped down in size when the name would not fit in
/// two lines or a single word would have to break mid-word.
class _HeroTitle extends StatelessWidget {
  const _HeroTitle(this.text);

  final String text;

  // Bespoke step-down sizes below XploreText.display, ending at the title size.
  static const _fontSizes = [40.0, 34.0, 28.0];
  static const _maxLines = 2;

  TextStyle _styleFor(double fontSize) =>
      XploreText.display.copyWith(fontSize: fontSize, letterSpacing: fontSize * -0.03, color: XploreColors.white);

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final style = _fontSizes
            .map(_styleFor)
            .firstWhere(
              (style) => _fits(style, constraints.maxWidth, textScaler, textDirection),
              orElse: () => _styleFor(_fontSizes.last),
            );
        return Text(text, maxLines: _maxLines, overflow: TextOverflow.ellipsis, style: style);
      },
    );
  }

  bool _fits(TextStyle style, double maxWidth, TextScaler textScaler, TextDirection textDirection) {
    TextPainter layout(String value, {int? maxLines}) => TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);

    final whole = layout(text, maxLines: _maxLines);
    final overflows = whole.didExceedMaxLines;
    whole.dispose();
    if (overflows) {
      return false;
    }
    for (final word in text.split(RegExp(r'\s+'))) {
      final painter = layout(word);
      final wraps = painter.computeLineMetrics().length > 1;
      painter.dispose();
      if (wraps) {
        return false;
      }
    }
    return true;
  }
}
