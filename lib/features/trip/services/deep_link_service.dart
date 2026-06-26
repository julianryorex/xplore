import 'package:app_links/app_links.dart';
import 'package:xplore/features/trip/services/invite_link.dart';

/// Thin wrapper over [AppLinks] that surfaces *invite* deep links only.
///
/// Receiving the OS-level universal link requires the iOS Associated Domains
/// entitlement + a hosted `apple-app-site-association` file (see
/// `infra/README.md`); that part can only be verified on a Mac/Xcode +
/// simulator/device, not in this headless environment. The parsing itself
/// ([InviteLink.parse]) is pure and unit-tested.
class DeepLinkService {
  DeepLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  /// Invite links delivered while the app is already running (warm start).
  Stream<InviteLinkData> get inviteLinks =>
      _appLinks.uriLinkStream.map(InviteLink.parse).where((data) => data != null).cast<InviteLinkData>();

  /// The invite link that cold-started the app, if any.
  Future<InviteLinkData?> initialInviteLink() async {
    final uri = await _appLinks.getInitialLink();
    return uri == null ? null : InviteLink.parse(uri);
  }
}
