import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/core/ambient_background.dart';
import 'package:xplore/features/auth/presentation/sign_in_buttons.dart';

/// The hard-gate sign-in step (FEAT-001 §5). Apple is the primary provider
/// (App Store policy); Google is offered as a secondary option. On success the
/// AuthGate swaps the tree to Home, so this page never navigates itself.
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

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
                Text('Sign in', style: XploreText.title.copyWith(color: XploreColors.white)),
                const SizedBox(height: paddingUnit),
                Text(
                  'Sign in to get started. Your trips and photos sync to your profile.',
                  style: context.pText.bodyLarge?.copyWith(color: XploreColors.mutedText),
                ),
                const Spacer(),
                const SignInButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
