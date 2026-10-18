import 'dart:io';

import '../../i18n/strings.dart';

const _authCodes = <String, String>{
  'invalid_credentials': 'error.invalidCredentials',
  'email_not_confirmed': 'error.emailNotConfirmed',
  'phone_not_confirmed': 'error.phoneNotConfirmed',
  'email_exists': 'error.alreadyRegistered',
  'phone_exists': 'error.alreadyRegistered',
  'user_already_exists': 'error.alreadyRegistered',
  'weak_password': 'error.weakPassword',
  'over_email_send_rate_limit': 'error.rateLimited',
  'over_sms_send_rate_limit': 'error.rateLimited',
  'over_request_rate_limit': 'error.rateLimited',
  'session_not_found': 'error.sessionExpired',
  'refresh_token_not_found': 'error.sessionExpired',
  'session_expired': 'error.sessionExpired',
  // Sign-up failures that are worth naming instead of "Something went wrong":
  // a rejected address (Supabase validates the domain) or a project with
  // sign-ups / a provider switched off.
  'email_address_invalid': 'error.emailInvalid',
  'signup_disabled': 'error.signupDisabled',
  'email_provider_disabled': 'error.signupDisabled',
  'phone_provider_disabled': 'error.phoneProviderDisabled',
  'sms_send_failed': 'error.smsFailed',
  'validation_failed': 'error.invalidInput',
  'otp_expired': 'error.invalidToken',
};

const _sqlstate = <String, String>{
  '42501': 'error.forbidden',
  '23505': 'error.conflict',
  '23514': 'error.invalidInput',
  '22023': 'error.invalidInput',
  'P0002': 'error.notFound',
  'PGRST301': 'error.sessionExpired',
  'PGRST000': 'error.unknown',
};

const _sharedKeyMap = <String, String>{
  'forbidden': 'error.forbidden',
  'mfa_required': 'error.mfaRequired',
  'lease_not_found': 'error.leaseNotFound',
  'unit_not_found': 'error.unitNotFound',
  'unit_not_vacant': 'error.unitNotVacant',
  'invalid_amount': 'error.invalidAmount',
  'payment_not_found': 'error.paymentNotFound',
  'cannot_demote_last_owner': 'error.cannotDemoteLastOwner',
  'item_not_found': 'error.itemNotFound',
  'insufficient_stock': 'error.insufficientStock',
  'negative_balance': 'error.negativeBalance',
  'invitation_not_found': 'error.invitationNotFound',
  'invitation_expired': 'error.invitationExpired',
  'invalid_token': 'error.invalidToken',
  'already_member': 'error.alreadyMember',
  'rate_limited': 'error.rateLimited',
};

bool _isNetwork(dynamic err) {
  if (err is SocketException) return true;
  // TLS handshake / certificate failures never reach the app layer either —
  // a carrier or captive network breaking HTTPS reads to the user as a
  // connection problem, not as an account problem.
  if (err is TlsException) return true;
  final msg = err.toString().toLowerCase();
  return msg.contains('network') ||
      msg.contains('timeout') ||
      msg.contains('failed to connect') ||
      msg.contains('no route to host') ||
      msg.contains('connection refused') ||
      msg.contains('connection reset') ||
      msg.contains('internet');
}

/// Map anything thrown (Supabase, HTTP, etc.) to a localized user-facing string.
String userMessage(dynamic err) {
  if (err == null) return t('error.unknown');
  if (_isNetwork(err)) return t('error.network');

  final raw = err.toString();
  final msg = raw;

  // Supabase/Auth-like: "AuthApiException: message (code: x)" — and gotrue's
  // newer "AuthApiException(message: …, statusCode: …, code: x)" form.
  if (msg.contains('code: ')) {
    final m = RegExp(r'code:\s*([^\)\s]+)').firstMatch(msg);
    if (m != null) {
      final code = m.group(1)!.toLowerCase();
      if (_authCodes.containsKey(code)) return t(_authCodes[code]!);
    }
  }
  // AuthWeakPasswordException prints `reasons:` but not its `code`, so the
  // parser above never sees `weak_password`.
  if (msg.contains('AuthWeakPasswordException')) return t('error.weakPassword');
  // PostgREST/Supabase errors often have `code: ...`
  final mcode = RegExp(r'"code"\s*:\s*"([^\"]+)"').firstMatch(msg);
  if (mcode != null) {
    final c = mcode.group(1)!;
    final k = _sharedKeyMap[c];
    if (k != null) return t(k);
    final s = _sqlstate[c];
    if (s != null) return t(s);
  }
  final mkey = RegExp(r'"message"\s*:\s*"([^\"]+)"').firstMatch(msg);
  if (mkey != null) {
    final k = mkey.group(1)!;
    final mapped = _sharedKeyMap[k];
    if (mapped != null) return t(mapped);
  }

  // Try known message fragments (shared error keys appear as-is).
  for (final e in _sharedKeyMap.entries) {
    if (raw.contains(e.key)) return t(e.value);
  }
  // Auth codes that appear bare (without the `code: ` prefix).
  final lower = raw.toLowerCase();
  for (final e in _authCodes.entries) {
    if (lower.contains(e.key)) return t(e.value);
  }

  return t('error.unknown');
}
