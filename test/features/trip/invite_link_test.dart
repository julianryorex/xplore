import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/trip/services/invite_link.dart';

void main() {
  group('InviteLink.build', () {
    test('produces a join URL with trip and token query params', () {
      final link = InviteLink.build(tripId: 'trip-1', token: 'tok-abc');

      final uri = Uri.parse(link);
      expect(uri.host, 'xplore.olympuslabs.ai');
      expect(uri.path, '/join');
      expect(uri.queryParameters['trip'], 'trip-1');
      expect(uri.queryParameters['token'], 'tok-abc');
    });

    test('round-trips through parse', () {
      final link = InviteLink.build(tripId: 'trip-9', token: 'tok-9');
      final data = InviteLink.parse(Uri.parse(link));

      expect(data, isNotNull);
      expect(data!.tripId, 'trip-9');
      expect(data.token, 'tok-9');
    });
  });

  group('InviteLink.parse', () {
    test('parses a valid universal link', () {
      final data = InviteLink.parse(Uri.parse('https://xplore.app/join?trip=t1&token=k1'));

      expect(data, const InviteLinkData(tripId: 't1', token: 'k1'));
    });

    test('parses a custom-scheme link with the join path', () {
      final data = InviteLink.parse(Uri.parse('xplore://app/join?trip=t1&token=k1'));

      expect(data, const InviteLinkData(tripId: 't1', token: 'k1'));
    });

    test('returns null for a non-join path', () {
      expect(InviteLink.parse(Uri.parse('https://xplore.app/profile?trip=t1&token=k1')), isNull);
    });

    test('returns null when trip is missing', () {
      expect(InviteLink.parse(Uri.parse('https://xplore.app/join?token=k1')), isNull);
    });

    test('returns null when token is missing', () {
      expect(InviteLink.parse(Uri.parse('https://xplore.app/join?trip=t1')), isNull);
    });

    test('returns null when params are empty', () {
      expect(InviteLink.parse(Uri.parse('https://xplore.app/join?trip=&token=')), isNull);
    });

    test('tolerates trailing slashes after the join path', () {
      final data = InviteLink.parse(Uri.parse('https://xplore.olympuslabs.ai/join//?trip=t1&token=k1'));

      expect(data, const InviteLinkData(tripId: 't1', token: 'k1'));
    });
  });

  group('InviteLink.parsePasted', () {
    final link = InviteLink.build(tripId: 'trip-1', token: 'tok-1');
    const expected = InviteLinkData(tripId: 'trip-1', token: 'tok-1');

    test('extracts the link from the whole share message', () {
      expect(InviteLink.parsePasted('Join "Lisbon \u201926" on Xplore:\n$link'), expected);
    });

    test('ignores punctuation that runs into the link', () {
      expect(InviteLink.parsePasted('Here you go: $link.'), expected);
    });

    test('accepts a link with a trailing slash on the join path', () {
      expect(InviteLink.parsePasted('https://xplore.olympuslabs.ai/join/?trip=trip-1&token=tok-1'), expected);
    });

    test('rejects a join link on a foreign host', () {
      expect(InviteLink.parsePasted('Join on Xplore:\nhttps://evil.example/join?trip=t1&token=k1'), isNull);
    });

    test('rejects a lookalike host that merely ends with the invite host', () {
      expect(InviteLink.parsePasted('https://xplore.olympuslabs.ai.evil.example/join?trip=t1&token=k1'), isNull);
    });

    test('rejects plain http on the invite host', () {
      expect(InviteLink.parsePasted('http://xplore.olympuslabs.ai/join?trip=t1&token=k1'), isNull);
    });

    test('rejects a link with an empty host without throwing', () {
      expect(InviteLink.parsePasted('https:///join?trip=t1&token=k1'), isNull);
    });

    test('returns null when the text contains no link', () {
      expect(InviteLink.parsePasted('see you in Lisbon'), isNull);
    });
  });
}
