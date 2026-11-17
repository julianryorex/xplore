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
    final path = uri.path.replaceFirst(_trailingSlashes, '');
    final isJoinPath = path == '/join' || path.endsWith('/join');
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

  /// Parses an invite link out of user-pasted [text], such as the whole share
  /// message (`Join "<title>" on Xplore:\n<link>`). Uses the first http(s) URL in
  /// the text and, unlike [parse], only accepts https links on [base]'s origin,
  /// because pasted text has not been host-verified by the OS.
  static InviteLinkData? parsePasted(String text) {
    final match = _httpUrl.firstMatch(text);
    if (match == null) {
      return null;
    }
    final uri = Uri.tryParse(match[0]!.replaceFirst(_trailingPunctuation, ''));
    // Compared field by field: Uri.origin throws on a URL with an empty host.
    final trusted = Uri.parse(base);
    if (uri == null || uri.scheme != trusted.scheme || uri.host != trusted.host || uri.port != trusted.port) {
      return null;
    }
    return parse(uri);
  }

  static final _trailingSlashes = RegExp(r'/+$');
  static final _httpUrl = RegExp(r'https?://\S+', caseSensitive: false);

  // Sentence punctuation or closing quotes that chat apps let run into a URL.
  static final _trailingPunctuation = RegExp('[.,;:!?)\\]}>"\'’”]+\$');
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

  // The token grants trip access, so keep it out of logs and error reports.
  @override
  String toString() => 'InviteLinkData(tripId: $tripId, token: <redacted>)';
}
