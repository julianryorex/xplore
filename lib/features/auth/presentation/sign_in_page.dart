import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/ambient_background.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/auth/services/auth_service.dart';

/// The hard-gate sign-in step (FEAT-001 §5). Apple is the primary provider
/// (App Store policy); Google is offered as a secondary option.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  /// The provider whose sign-in is currently in flight, or null when idle.
  /// Used to show a spinner on the right button and disable the others.
  String? _pending;
  String? _error;

  bool get _busy => _pending != null;

  Future<void> _signIn(String provider, Future<void> Function() action) async {
    setState(() {
      _pending = provider;
      _error = null;
    });

    try {
      await action();
      // On success the AuthGate swaps the tree to Home; nothing to do here.
    } on AuthCancelledException {
      // User backed out — non-blocking, just restore the idle state.
    } on AuthFailureException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  Future<void> _signInWithApple() => _signIn('apple', context.read<AuthCubit>().signInWithApple);

  Future<void> _signInWithGoogle() => _signIn('google', context.read<AuthCubit>().signInWithGoogle);

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
                  'Sign in to get started. Your trips and photos sync to your profile.',
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
                _AppleSignInButton(loading: _pending == 'apple', onTap: _busy ? null : _signInWithApple),
                const SizedBox(height: paddingUnit),
                SizedBox(
                  width: double.infinity,
                  child: GlassSurface(
                    strong: true,
                    borderRadius: radiusLg,
                    padding: const EdgeInsets.symmetric(vertical: paddingUnit * 1.25),
                    onTap: _busy ? null : _signInWithGoogle,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_pending == 'google')
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

/// The primary "Sign in with Apple" button. A solid surface with the Apple
/// glyph + label, following Apple's HIG that the Apple button reads as the
/// prominent option when other providers are offered alongside it.
class _AppleSignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;

  const _AppleSignInButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: XploreColors.white,
        borderRadius: BorderRadius.circular(radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (onTap == null) return;
            HapticFeedback.lightImpact();
            onTap!();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: paddingUnit * 1.25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                  )
                else ...[
                  const Icon(Icons.apple, size: 22, color: Colors.black),
                  const SizedBox(width: paddingUnit * 0.5),
                  Text(
                    'Sign in with Apple',
                    style: context.pText.labelLarge?.copyWith(color: Colors.black, fontWeight: FontWeight.w600),
                  ),
                ],
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
