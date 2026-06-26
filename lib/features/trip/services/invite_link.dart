/// Universal-link helpers for trip invites.
///
/// Links resolve via the Associated-Domains-verified host below. Deep linking
/// requires the iOS Associated Domains entitlement (`applinks:`) plus the
/// hosted `apple-app-site-association` file on the same host (see
/// `infra/README.md` and `infra/hosting/`).
class InviteLink {
  const InviteLink._();

  /// Universal-link host for invites. Kept in sync with the
  /// `applinks:xplore.olympuslabs.ai` entitlement (`ios/Runner/Runner.entitlements`)
  /// and the AASA file at `https://xplore.olympuslabs.ai/.well-known/apple-app-site-association`.
  static const base = 'https://xplore.olympuslabs.ai/join';

  static const _tripParam = 'trip';
  static const _tokenParam = 'token';

  /// Builds the shareable invite URL for [tripId] / [token].
  static String build({required String tripId, required String token}) {
    final uri = Uri.parse(base).replace(queryParameters: {_tripParam: tripId, _tokenParam: token});
    return uri.toString();
  }

  /// Parses an incoming deep link into its [InviteLinkData], or returns `null`
  /// when [uri] is not a recognisable invite link (wrong path or missing
  /// params). Pure and side-effect free so it can be unit-tested without the
  /// platform channel.
  static InviteLinkData? parse(Uri uri) {
    final isJoinPath = uri.path == '/join' || uri.path.endsWith('/join');
    if (!isJoinPath) {
      return null;
    }

    final tripId = uri.queryParameters[_tripParam];
    final token = uri.queryParameters[_tokenParam];
    if (tripId == null || tripId.isEmpty || token == null || token.isEmpty) {
      return null;
    }

    return InviteLinkData(tripId: tripId, token: token);
  }
}

/// The trip + token pair extracted from an invite deep link.
class InviteLinkData {
  const InviteLinkData({required this.tripId, required this.token});

  final String tripId;
  final String token;

  @override
  bool operator ==(Object other) => other is InviteLinkData && other.tripId == tripId && other.token == token;

  @override
  int get hashCode => Object.hash(tripId, token);

  @override
  String toString() => 'InviteLinkData(tripId: $tripId, token: $token)';
}
