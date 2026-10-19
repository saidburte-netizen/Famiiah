import 'package:fam_mobile/routing/deep_links.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android hands the app the full URI for a custom-scheme link, where the first
/// segment is the URI *host*. These tests lock in the rewrite that lets
/// `fam://invite?token=…` reach the `/invite` route, and confirm that ordinary
/// in-app locations and unrelated links are left to the router's auth guard.
void main() {
  group('deepLinkRedirect', () {
    test('maps the invite deep link to the invite route', () {
      expect(
        deepLinkRedirect(Uri.parse('fam://invite?token=abc123')),
        '/invite?token=abc123',
      );
    });

    test('maps an invite link without a token', () {
      expect(deepLinkRedirect(Uri.parse('fam://invite')), '/invite');
    });

    test('round-trips a token that needs encoding', () {
      final link = Uri.parse('fam://invite')
          .replace(queryParameters: {'token': 'a+b=c d'});
      final location = deepLinkRedirect(link);
      expect(location, startsWith('/invite?'));
      expect(Uri.parse(location!).queryParameters['token'], 'a+b=c d');
    });

    test('leaves in-app locations alone', () {
      expect(deepLinkRedirect(Uri.parse('/app/home')), isNull);
      expect(deepLinkRedirect(Uri.parse('/invite?token=abc')), isNull);
      expect(deepLinkRedirect(Uri.parse('/')), isNull);
    });

    test('ignores other schemes', () {
      expect(
        deepLinkRedirect(Uri.parse('https://example.com/invite?token=abc')),
        isNull,
      );
    });

    test('maps the reset-password link and keeps its fragment', () {
      expect(
        deepLinkRedirect(Uri.parse('fam://reset-password#access_token=x&type=recovery')),
        '/auth/reset-password#access_token=x&type=recovery',
      );
    });

    test('maps a bare reset-password link', () {
      expect(deepLinkRedirect(Uri.parse('fam://reset-password')), '/auth/reset-password');
    });

    test('leaves unknown fam links to the auth guard', () {
      expect(deepLinkRedirect(Uri.parse('fam://something-else')), isNull);
    });
  });

  group('isAuthCallbackLink', () {
    test('recognises a recovery link (tokens in the fragment)', () {
      expect(
        isAuthCallbackLink(
          Uri.parse('fam://reset-password#access_token=a&refresh_token=b&type=recovery'),
        ),
        isTrue,
      );
    });

    test('recognises a PKCE callback link (code in the query)', () {
      expect(isAuthCallbackLink(Uri.parse('fam://reset-password?code=abc')), isTrue);
    });

    test('leaves the invitation link alone', () {
      expect(isAuthCallbackLink(Uri.parse('fam://invite?token=abc123')), isFalse);
    });

    test('leaves an ordinary in-app location alone', () {
      expect(isAuthCallbackLink(Uri.parse('fam://invite')), isFalse);
    });
  });
}
