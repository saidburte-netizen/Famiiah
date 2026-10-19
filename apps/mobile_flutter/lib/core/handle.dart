/// A profile handle is the account's public name: people type `@Abebe`, the
/// database stores `abebe`. 3-24 characters, starting with a letter, then
/// letters, digits or underscores — the same rule as `profiles_handle_format`
/// and `handle_available()` in migration `0018`. Handles are optional on
/// sign-up; if no valid handle is provided, normalizeHandle returns `null`.
/// Mirrors `Handle` in `packages/shared/src/schemas.ts`.
final RegExp _handleFormat = RegExp(r'^[a-z][a-z0-9_]{2,23}$');

/// Normalise a typed handle to its stored form, or `null` when invalid/empty.
String? normalizeHandle(String? input) {
  if (input == null) return null;
  var s = input.trim();
  if (s.isEmpty) return null;
  while (s.startsWith('@')) {
    s = s.substring(1);
  }
  if (s.isEmpty) return null;
  s = s.toLowerCase();
  return _handleFormat.hasMatch(s) ? s : null;
}
