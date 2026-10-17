import 'package:fam_mobile/core/errors/user_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// These tests lock in the contract that raw backend errors never reach the
/// user: every Supabase/Postgres failure must map to a safe, localized string.
void main() {
  group('userMessage', () {
    test('null maps to the generic unknown message', () {
      expect(userMessage(null), contains('Something went wrong'));
    });

    test('maps a Supabase auth code', () {
      final err = Exception('AuthApiException: Invalid login credentials (code: invalid_credentials)');
      expect(userMessage(err), 'Incorrect email or password.');
    });

    test('names a rejected sign-up address instead of the generic message', () {
      final err = Exception(
          'AuthApiException: Email address "x@example.com" is invalid (code: email_address_invalid)');
      expect(userMessage(err), 'That email address was rejected. Check it and try again.');
    });

    test('names a disabled provider instead of the generic message', () {
      final err = Exception('AuthApiException: Phone signups are disabled (code: phone_provider_disabled)');
      expect(userMessage(err), 'New sign-ups are turned off for this app.');
    });

    test('maps a Postgres SQLSTATE from a JSON code field', () {
      final err = Exception('{"code":"42501","message":"forbidden"}');
      expect(userMessage(err), 'You do not have permission to do that.');
    });

    test('maps a shared result key that appears bare', () {
      final err = Exception('PostgrestException(message: unit_not_vacant, code: 23505)');
      expect(userMessage(err), 'That unit already has an active lease.');
    });

    test('maps a network failure', () {
      final err = Exception('SocketException: Failed host lookup: network is unreachable');
      expect(userMessage(err), contains('No connection'));
    });

    test('never leaks the raw message for an unknown error', () {
      final err = Exception('pq: relation "secret_table" does not exist');
      final out = userMessage(err);
      expect(out, isNot(contains('secret_table')));
      expect(out, contains('Something went wrong'));
    });
  });
}
