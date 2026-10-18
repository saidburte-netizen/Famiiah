/// Ethiopian phone numbers are typed as `0912 345 678`, `+251912345678` or
/// `251912345678`; GoTrue only accepts E.164 (`+2519…`), so the sign-up and
/// sign-in screens normalise before calling it. Mirrors `toE164` in
/// `packages/shared/src/phone.ts`.
final RegExp _ethiopianE164 = RegExp(r'^\+251[79]\d{8}$');

String? toE164(String? input) {
  if (input == null) return null;
  var s = input.replaceAll(RegExp(r'[\s()\[\]-]'), '');
  if (s.startsWith('+')) s = s.substring(1);
  if (s.startsWith('00')) s = s.substring(2);
  final String candidate;
  if (s.startsWith('251')) {
    candidate = '+$s';
  } else if (s.startsWith('0')) {
    candidate = '+251${s.substring(1)}';
  } else {
    candidate = '+251$s';
  }
  return _ethiopianE164.hasMatch(candidate) ? candidate : null;
}

/// True for identifiers the sign-in field should treat as an email, not a phone.
bool looksLikeEmail(String identifier) => identifier.contains('@');
