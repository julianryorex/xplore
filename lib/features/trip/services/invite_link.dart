/// Universal-link helpers for trip invites.
///
/// The production domain is **not finalised** yet (FEAT-003 open question), so
/// the base lives in a single constant. Swap [InviteLink.base] for the real
/// `applinks:` domain once it is decided and the Associated Domains entitlement
/// + `apple-app-site-association` file are hosted (see `infra/README.md`).
class InviteLink {
  const InviteLink._();

  /// Placeholder universal-link base. MUST be replaced with the real,
  /// Associated-Domains-verified domain before invite links resolve in
  /// production. Until then links are shareable but will not deep-link.
  static const base = 'https://xplore.app/join';

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
