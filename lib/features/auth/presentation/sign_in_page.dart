import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/ambient_background.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/auth/services/auth_service.dart';

/// The hard-gate sign-in step (FEAT-001 §5). Google is the only provider for
/// now (interim); Apple slots in as a second button when its credentials exist.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await context.read<AuthCubit>().signInWithGoogle();
      // On success the AuthGate swaps the tree to Home; nothing to do here.
    } on AuthCancelledException {
      // User backed out — non-blocking, just restore the idle state.
    } on AuthFailureException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
                  'Sign in',
                  style: context.pText.displaySmall?.copyWith(
                    color: XploreColors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: paddingUnit),
                Text(
                  'Use your Google account to get started. Your trips and photos sync to your profile.',
                  style: context.pText.bodyLarge?.copyWith(color: XploreColors.mutedText),
                ),
                const Spacer(),
                if (_error != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: paddingUnit),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 18, color: XploreColors.error),
                        const SizedBox(width: paddingUnit * 0.5),
                        Expanded(
                          child: Text(_error!, style: context.pText.bodySmall?.copyWith(color: XploreColors.error)),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(
                  width: double.infinity,
                  child: GlassSurface(
                    strong: true,
                    borderRadius: radiusLg,
                    padding: const EdgeInsets.symmetric(vertical: paddingUnit * 1.25),
                    onTap: _loading ? null : _signInWithGoogle,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_loading)
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: XploreColors.white),
                          )
                        else ...[
                          const _GoogleGlyph(),
                          const SizedBox(width: paddingUnit * 0.75),
                          Text(
                            'Continue with Google',
                            style: context.pText.labelLarge?.copyWith(color: XploreColors.white),
                          ),
                        ],
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

/// A small "G" glyph on a white chip — a lightweight stand-in for the Google
/// mark (swap for the official asset before any public release).
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: const Text(
        'G',
        style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w700, fontSize: 15, height: 1.1),
      ),
    );
  }
}
