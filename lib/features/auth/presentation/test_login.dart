import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/auth/test_login_flag.dart';

/// A small "Test login" link that opens an email/password form, so a tester or
/// agent can sign in as the dedicated Firebase test user without Apple/Google.
/// Renders nothing unless [enabled], which defaults to the compile-time
/// `ENABLE_TEST_LOGIN` flag; tests pass it explicitly.
class TestLoginEntry extends StatelessWidget {
  const TestLoginEntry({super.key, this.enabled = testLoginEnabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();

    return Center(
      child: TextButton(
        onPressed: () => unawaited(_showTestLoginSheet(context)),
        style: TextButton.styleFrom(foregroundColor: XploreColors.secondaryLabel, textStyle: XploreText.footnote),
        child: const Text('Test login'),
      ),
    );
  }
}

Future<void> _showTestLoginSheet(BuildContext context) {
  // Read here: the sheet's route sits outside this subtree's providers.
  final authCubit = context.read<AuthCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: XploreColors.card,
    showDragHandle: true,
    builder: (_) => _TestLoginSheet(authCubit: authCubit),
  );
}

class _TestLoginSheet extends StatefulWidget {
  const _TestLoginSheet({required this.authCubit});

  final AuthCubit authCubit;

  @override
  State<_TestLoginSheet> createState() => _TestLoginSheetState();
}

class _TestLoginSheetState extends State<_TestLoginSheet> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _passwordVisible = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.authCubit.signInWithEmailPassword(email: _email.text.trim(), password: _password.text);
      // Only dismisses this sheet; where the user lands next is up to whoever
      // listens to the auth state (which may already have closed it).
      if (mounted) Navigator.pop(context);
    } on AuthFailureException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Test login', style: XploreText.heading.copyWith(color: XploreColors.white)),
              const SizedBox(height: 4),
              Text(
                'Sign in as the Firebase test user. Only in builds made with ENABLE_TEST_LOGIN.',
                style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                enabled: !_submitting,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                cursorColor: XploreColors.accent,
                style: XploreText.body.copyWith(color: XploreColors.white),
                decoration: _fieldDecoration('Email'),
                validator: (value) => (value ?? '').trim().isEmpty ? 'Enter the test user’s email.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                enabled: !_submitting,
                obscureText: !_passwordVisible,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.go,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => unawaited(_submit()),
                cursorColor: XploreColors.accent,
                style: XploreText.body.copyWith(color: XploreColors.white),
                decoration: _fieldDecoration('Password').copyWith(
                  suffixIcon: IconButton(
                    tooltip: _passwordVisible ? 'Hide password' : 'Show password',
                    color: XploreColors.secondaryLabel,
                    icon: Icon(_passwordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                  ),
                ),
                validator: (value) => (value ?? '').isEmpty ? 'Enter the test user’s password.' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 18, color: XploreColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_error!, style: XploreText.footnote.copyWith(color: XploreColors.error)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : () => unawaited(_submit()),
                style: FilledButton.styleFrom(
                  backgroundColor: XploreColors.accent,
                  foregroundColor: XploreColors.onAccent,
                  disabledBackgroundColor: XploreColors.accent,
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                  textStyle: XploreText.bodyStrong,
                ),
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: XploreColors.onAccent),
                      )
                    : const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: XploreText.body.copyWith(color: XploreColors.secondaryLabel),
    floatingLabelStyle: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
    errorStyle: XploreText.footnote.copyWith(color: XploreColors.error),
    filled: true,
    fillColor: XploreColors.raised,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusSm), borderSide: BorderSide.none),
  );
}
