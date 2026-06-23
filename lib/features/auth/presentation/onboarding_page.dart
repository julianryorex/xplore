import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/ambient_background.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/features/auth/presentation/sign_in_page.dart';

/// Placeholder onboarding (FEAT-001 §3). Real content lands in FEAT-005; for now
/// it's a single "Next" step that advances to the sign-in gate, preserving the
/// routing shape.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: XploreColors.primaryBg,
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              paddingUnit * 2,
              paddingUnit * 2,
              paddingUnit * 2,
              bottomInset + paddingUnit * 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  'Welcome to\nXplore',
                  style: context.pText.displaySmall?.copyWith(
                    color: XploreColors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: paddingUnit),
                Text(
                  'Plan trips, share moments, and see your group on the map — all in one place.',
                  style: context.pText.bodyLarge?.copyWith(color: XploreColors.mutedText),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: GlassSurface(
                    strong: true,
                    borderRadius: radiusLg,
                    padding: const EdgeInsets.symmetric(vertical: paddingUnit * 1.25),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SignInPage()));
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Next', style: context.pText.labelLarge?.copyWith(color: XploreColors.white)),
                        const SizedBox(width: paddingUnit * 0.5),
                        Icon(Icons.arrow_forward_rounded, size: 18, color: XploreColors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
