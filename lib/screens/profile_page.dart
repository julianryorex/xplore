import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/ambient_background.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/layout_padding.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XploreColors.primaryBg,
      body: AmbientBackground(
        child: SafeArea(
          bottom: false,
          child: LayoutPadding(
            header: Header(
              leadingWidget: GlassIconButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
              titleWidget: Text('Edit Profile', textAlign: TextAlign.center, style: context.pText.headlineSmall),
              // Balances the leading glass button so the title stays centred.
              trailingWidget: const SizedBox(width: headerIconButtonSize),
            ),
            child: BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, profileState) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: paddingUnit),
                      _GlassAvatar(
                        image: _avatarImage(profileState),
                        initial: _initialFor(profileState.name),
                        onEdit: () => context.read<ProfileCubit>().changeProfilePicture(),
                      ),
                      const SizedBox(height: paddingUnit * 2),
                      _ProfileFieldsCard(name: profileState.name, username: profileState.username),
                      const SizedBox(height: paddingUnit * 2),
                      const _SaveChangesButton(),
                      const SizedBox(height: paddingUnit),
                      _SignOutButton(onTap: () => _confirmAndSignOut(context)),
                      const SizedBox(height: paddingUnit * 0.5),
                      _DeleteAccountButton(onTap: () => _confirmAndDeleteAccount(context)),
                      const SizedBox(height: paddingUnit),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Freshly-picked bytes win; otherwise fall back to the synced cloud avatar.
  ImageProvider? _avatarImage(ProfileState state) {
    if (state.profilePicture != null) {
      return Image.memory(state.profilePicture!).image;
    }
    final url = state.photoUrl;
    if (url != null && url.isNotEmpty) {
      return NetworkImage(url);
    }
    return null;
  }

  String _initialFor(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
  }

  Future<void> _confirmAndSignOut(BuildContext context) async {
    final authCubit = context.read<AuthCubit>();
    final shouldSignOut =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Sign out?'),
              content: const Text('You will return to the sign-in screen and can sign in again with any account.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text('Sign out', style: TextStyle(color: XploreColors.error)),
                ),
              ],
            );
          },
        ) ??
        false;

    if (shouldSignOut) {
      await authCubit.signOut();
    }
  }

  Future<void> _confirmAndDeleteAccount(BuildContext context) async {
    final authCubit = context.read<AuthCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete account?'),
              content: const Text(
                'This permanently deletes your account and profile. This cannot be undone. '
                "You'll be asked to confirm with your sign-in provider to continue.",
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text('Delete', style: TextStyle(color: XploreColors.error)),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete) return;

    try {
      await authCubit.deleteAccount();
      // On success the AuthGate swaps to onboarding; nothing else to do here.
    } on AuthCancelledException {
      // User backed out of the re-authentication sheet — non-blocking.
    } on AuthFailureException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Circular avatar wrapped in a liquid-glass rim with a floating glass camera
/// badge — the badge reads as a separate piece of glass hovering over the photo.
class _GlassAvatar extends StatelessWidget {
  final ImageProvider? image;
  final String initial;
  final VoidCallback onEdit;

  const _GlassAvatar({required this.image, required this.initial, required this.onEdit});

  static const double _size = 100;
  static const double _badge = 34;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size + _badge / 2,
      height: _size + _badge / 2,
      child: Stack(
        children: [
          Container(
            width: _size,
            height: _size,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: XploreColors.glassFill,
              border: Border.all(color: XploreColors.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: XploreColors.black.withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: DecoratedBox(
              // Neutral, desaturated fallback so an avatar without a photo reads
              // as a calm placeholder rather than a bright coloured token.
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [XploreColors.surfaceElevated, XploreColors.surface],
                ),
              ),
              child: CircleAvatar(
                foregroundImage: image,
                backgroundColor: Colors.transparent,
                child: Text(
                  initial,
                  style: context.pText.headlineSmall?.copyWith(
                    color: XploreColors.mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: SizedBox(
              width: _badge,
              height: _badge,
              child: GlassSurface(
                borderRadius: _badge,
                strong: true,
                padding: EdgeInsets.zero,
                onTap: onEdit,
                child: Center(child: Icon(Icons.photo_camera_rounded, size: 16, color: XploreColors.mutedText)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The editable fields grouped onto a single liquid-glass panel, separated by
/// hairline dividers — matching the stacked-row layout in the design.
class _ProfileFieldsCard extends StatelessWidget {
  final String name;
  final String? username;

  const _ProfileFieldsCard({required this.name, required this.username});

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: EdgeInsets.zero,
      child: BlocBuilder<AuthCubit, AuthState>(
        buildWhen: (previous, current) => previous.runtimeType != current.runtimeType || current is AuthAuthenticated,
        builder: (context, authState) {
          final email = authState is AuthAuthenticated ? (authState.email ?? '—') : '—';
          // Handle is the synced cloud value (auto-generated at sign-up; chosen
          // in onboarding). '—' until the cloud profile hydrates.
          final handle = (username != null && username!.isNotEmpty) ? '@$username' : '—';

          return Column(
            children: [
              _ProfileFieldRow(label: 'Full name', value: name),
              const _FieldDivider(),
              _ProfileFieldRow(label: 'Email', value: email),
              const _FieldDivider(),
              _ProfileFieldRow(label: 'Username', value: handle),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileFieldRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileFieldRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: paddingUnit * 1.5, vertical: paddingUnit * 1.25),
      child: Row(
        children: [
          Text(label, style: context.pText.labelSmall?.copyWith(color: XploreColors.subtleText, letterSpacing: 0.2)),
          const SizedBox(width: paddingUnit),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: context.pText.bodyMedium?.copyWith(color: XploreColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldDivider extends StatelessWidget {
  const _FieldDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: paddingUnit * 1.5),
      child: Divider(height: 1, thickness: 1, color: XploreColors.divider),
    );
  }
}

class _SaveChangesButton extends StatelessWidget {
  const _SaveChangesButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          // A clean near-white primary reads as premium on dark, and keeps the
          // brand accent for sparing, intentional use elsewhere.
          backgroundColor: XploreColors.white,
          foregroundColor: XploreColors.primaryBg,
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        ),
        child: Text('Save Changes', style: context.pText.labelLarge?.copyWith(color: XploreColors.primaryBg)),
      ),
    );
  }
}

/// Sign-out rendered as a recessed glass slab rather than a loud button,
/// keeping the page calm while still reading as a real control.
class _SignOutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SignOutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GlassSurface(
        borderRadius: radiusMd,
        padding: const EdgeInsets.symmetric(vertical: paddingUnit * 1.25),
        onTap: onTap,
        child: Center(
          child: Text('Sign out', style: context.pText.labelMedium?.copyWith(color: XploreColors.subtleText)),
        ),
      ),
    );
  }
}

/// Destructive account deletion, rendered as a quiet text affordance below the
/// sign-out slab so it stays discoverable without competing for attention.
class _DeleteAccountButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteAccountButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text('Delete Account', style: context.pText.labelMedium?.copyWith(color: XploreColors.error)),
    );
  }
}
