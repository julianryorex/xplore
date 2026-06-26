import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/trip/services/invite_link.dart';

void main() {
  group('InviteLink.build', () {
    test('produces a join URL with trip and token query params', () {
      final link = InviteLink.build(tripId: 'trip-1', token: 'tok-abc');

      final uri = Uri.parse(link);
      expect(uri.host, 'xplore.app');
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
  });
}
