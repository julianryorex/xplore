import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/auth/services/auth_service.dart';

const _buttonHeight = 52.0;
const _spinnerSize = 20.0;

// Bespoke size: matches the onboarding action buttons these sit beside.
const _labelStyle = TextStyle(
  fontFamily: systemFontFamily,
  fontSize: 16,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.2,
);

enum _Provider { apple, google }

/// The Apple and Google sign-in buttons with their in-flight and error states.
/// Apple is the primary option (App Store policy). Success is not handled here:
/// whoever listens to [AuthCubit] moves the user on once they are signed in.
class SignInButtons extends StatefulWidget {
  const SignInButtons({super.key});

  @override
  State<SignInButtons> createState() => _SignInButtonsState();
}

class _SignInButtonsState extends State<SignInButtons> {
  /// The provider whose sign-in is in flight, or null when idle. It gets the
  /// spinner; every button is disabled meanwhile.
  _Provider? _pending;
  String? _error;

  bool get _busy => _pending != null;

  Future<void> _signIn(_Provider provider, Future<void> Function() action) async {
    setState(() {
      _pending = provider;
      _error = null;
    });

    try {
      await action();
    } on AuthCancelledException {
      // The user backed out; just return to idle.
    } on AuthFailureException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  void _signInWithApple() {
    unawaited(HapticFeedback.lightImpact());
    unawaited(_signIn(_Provider.apple, context.read<AuthCubit>().signInWithApple));
  }

  void _signInWithGoogle() => unawaited(_signIn(_Provider.google, context.read<AuthCubit>().signInWithGoogle));

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) _SignInError(message: _error!),
        _AppleButton(loading: _pending == _Provider.apple, onPressed: _busy ? null : _signInWithApple),
        const SizedBox(height: paddingUnit),
        _GoogleButton(loading: _pending == _Provider.google, onPressed: _busy ? null : _signInWithGoogle),
      ],
    );
  }
}

class _SignInError extends StatelessWidget {
  const _SignInError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: paddingUnit),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 18, color: XploreColors.error),
            const SizedBox(width: paddingUnit / 2),
            Expanded(
              child: Text(message, style: XploreText.footnote.copyWith(color: XploreColors.error)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A solid white capsule, so Apple reads as the prominent option per its HIG.
class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: XploreColors.white,
        foregroundColor: Colors.black,
        // Only the in-flight button keeps full colour; the idle one dims while another provider is busy.
        disabledBackgroundColor: loading ? XploreColors.white : XploreColors.raised,
        disabledForegroundColor: loading ? Colors.black : XploreColors.tertiaryLabel,
        minimumSize: const Size.fromHeight(_buttonHeight),
        shape: const StadiumBorder(),
        textStyle: _labelStyle,
      ),
      child: loading
          ? const _Spinner(color: Colors.black)
          : const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.apple, size: 22),
                SizedBox(width: paddingUnit * 2 / 3),
                Flexible(child: Text('Sign in with Apple', overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: XploreColors.card,
        foregroundColor: XploreColors.white,
        disabledForegroundColor: loading ? XploreColors.white : XploreColors.tertiaryLabel,
        side: const BorderSide(color: XploreColors.separator),
        minimumSize: const Size.fromHeight(_buttonHeight),
        shape: const StadiumBorder(),
        textStyle: _labelStyle.copyWith(fontWeight: FontWeight.w500),
      ),
      child: loading
          ? const _Spinner(color: XploreColors.white)
          : const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GoogleGlyph(),
                SizedBox(width: paddingUnit * 5 / 6),
                Flexible(child: Text('Continue with Google', overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _spinnerSize,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
    );
  }
}

/// A small "G" on a white chip: a lightweight stand-in for the Google mark
/// (swap for the official asset before any public release).
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      // Bespoke size: sized to the chip as a logo stand-in, not running text.
      child: const Text(
        'G',
        style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w700, fontSize: 13, height: 1.1),
      ),
    );
  }
}
