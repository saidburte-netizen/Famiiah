import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Pending invitation token.
///
/// When someone opens an invite deep link (`fam://invite?token=...`) without a
/// session, we stash the token so it survives sign-in / sign-up and can be
/// accepted afterwards. Mirrors `apps/mobile/lib/invite.ts`, which uses
/// `expo-secure-store` — the token grants org membership, so it never touches
/// plain preferences.
///
/// Every operation is best-effort: a device whose Keystore throws must never
/// lose a sign-in over an optional convenience — reading a token that cannot
/// be decrypted just means "no pending invite", and the user can reopen the
/// invite link.
const _key = 'fam.pending_invite';

final _storage = FlutterSecureStorage();

Future<void> savePendingInvite(String token) async {
  try {
    await _storage.write(key: _key, value: token);
  } catch (_) {
    // Best effort: an unstorable token costs the invite shortcut only.
  }
}

Future<String?> takePendingInvite() async {
  try {
    final token = await _storage.read(key: _key);
    if (token != null) await _storage.delete(key: _key);
    return token;
  } catch (_) {
    // Broken secure store: treat as "no pending invite".
    return null;
  }
}

Future<String?> peekPendingInvite() async {
  try {
    return await _storage.read(key: _key);
  } catch (_) {
    return null;
  }
}
