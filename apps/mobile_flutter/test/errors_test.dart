import 'dart:io';

import 'package:fam_mobile/core/errors/user_message.dart';
import 'package:flutter/services.dart';
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
      expect(userMessage(err), 'Incorrect phone/email or password.');
    });

    test('parses the toString format gotrue 2.27 actually produces', () {
      final err = Exception(
          'AuthApiException(message: Phone signups are disabled, statusCode: 400, code: phone_provider_disabled)');
      expect(userMessage(err), 'Phone sign-up is not enabled for this app.');

      final other = Exception(
          'AuthApiException(message: Invalid login credentials, statusCode: 401, code: invalid_credentials)');
      expect(userMessage(other), 'Incorrect phone/email or password.');
    });

    test('names a weak password even though gotrue omits its code', () {
      final err = Exception(
          'AuthWeakPasswordException(message: Password should contain at least one uppercase letter, statusCode: 422, reasons: [uppercase])');
      expect(userMessage(err), 'Choose a stronger password.');
    });

    test('names a rejected sign-up address instead of the generic message', () {
      final err = Exception(
          'AuthApiException: Email address "x@example.com" is invalid (code: email_address_invalid)');
      expect(userMessage(err), 'That email address was rejected. Check it and try again.');
    });

    test('names a disabled phone provider instead of the generic message', () {
      final err = Exception('AuthApiException: Phone signups are disabled (code: phone_provider_disabled)');
      expect(userMessage(err), 'Phone sign-up is not enabled for this app.');
    });

    test('maps the phone sign-up codes to safe messages', () {
      expect(
        userMessage(Exception('AuthApiException: Phone not confirmed (code: phone_not_confirmed)')),
        'Confirm your phone number before signing in.',
      );
      expect(
        userMessage(Exception('AuthApiException: Phone already exists (code: phone_exists)')),
        'That account already exists. Try signing in.',
      );
      expect(
        userMessage(Exception('AuthApiException: Could not send SMS (code: sms_send_failed)')),
        'We could not send the SMS. Please try again.',
      );
    });

    test('maps a Postgres SQLSTATE from a JSON code field', () {
      final err = Exception('{"code":"42501","message":"forbidden"}');
      expect(userMessage(err), 'You do not have permission to do that.');
    });

    test('maps a shared result key that appears bare', () {
      final err = Exception('PostgrestException(message: unit_not_vacant, code: 23505)');
      expect(userMessage(err), 'That unit already has an active lease.');
    });

    test('prefers a guard message over its generic SQLSTATE', () {
      // The archive guards raise 23503 (a foreign-key code) but carry a
      // specific message; the user must see the specific copy, not the
      // generic "conflicts with existing data".
      final err = Exception(
          '{"code":"23503","details":null,"hint":null,"message":"unit_has_lease"}');
      expect(userMessage(err), 'This unit still has an active lease. End the lease first.');

      final prop = Exception(
          '{"code":"23503","details":null,"hint":null,"message":"property_has_units"}');
      expect(userMessage(prop), contains('units first'));

      final stock = Exception(
          '{"code":"23503","details":null,"hint":null,"message":"item_has_stock"}');
      expect(userMessage(stock), contains('still has stock on hand'));
    });

    test('a bare SQLSTATE still maps when no specific message is present', () {
      final err = Exception('{"code":"23503","details":null,"hint":null,"message":null}');
      expect(userMessage(err), 'That action conflicts with existing data.');
    });

    test('maps a network failure', () {
      final err = Exception('SocketException: Failed host lookup: network is unreachable');
      expect(userMessage(err), contains('No connection'));
    });

    test('reads a TLS handshake failure as a connection problem', () {
      // dart:io throws HandshakeException (a TlsException), not a
      // SocketException, when HTTPS is broken in front of the API.
      expect(
        userMessage(const HandshakeException('Connection terminated during handshake')),
        contains('No connection'),
      );
    });

    test('never leaks a secure-storage failure for the session', () {
      // A Keystore/platform-channel failure must stay behind friendly copy
      // even if one ever escapes the storage fallback.
      final err = PlatformException(code: 'BadPaddingException', message: 'Failed to encrypt');
      final out = userMessage(err);
      expect(out, isNot(contains('BadPadding')));
      expect(out, contains('Something went wrong'));
    });

    test('never leaks the raw message for an unknown error', () {
      final err = Exception('pq: relation "secret_table" does not exist');
      final out = userMessage(err);
      expect(out, isNot(contains('secret_table')));
      expect(out, contains('Something went wrong'));
    });
  });
}
