import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';

/// The large question at the top of a create-trip step ("Where to?").
class CreateStepTitle extends StatelessWidget {
  const CreateStepTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: XploreText.title.copyWith(color: XploreColors.white)),
    );
  }
}

/// One supporting line under a [CreateStepTitle].
class CreateStepSubtitle extends StatelessWidget {
  const CreateStepSubtitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text, style: XploreText.body.copyWith(color: XploreColors.secondaryLabel)),
    );
  }
}

/// An uppercase tracked label that names a group of controls ("NIGHTS IN EACH PLACE").
class CreateOverline extends StatelessWidget {
  const CreateOverline(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: XploreText.overline.copyWith(color: XploreColors.secondaryLabel));
  }
}

/// The hairline that separates rows laid directly on the background.
class CreateHairline extends StatelessWidget {
  const CreateHairline({super.key});

  @override
  Widget build(BuildContext context) => const Divider(height: 1, thickness: 1, color: XploreColors.raised);
}

/// Horizontal inset every create-trip step uses for its content.
const createStepGutter = 20.0;
