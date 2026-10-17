import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Pending invitation token.
///
/// When someone opens an invite deep link (`fam://invite?token=...`) without a
/// session, we stash the token so it survives sign-in / sign-up and can be
/// accepted afterwards. Mirrors `apps/mobile/lib/invite.ts`, which uses
/// `expo-secure-store` — the token grants org membership, so it never touches
/// plain preferences.
const _key = 'fam.pending_invite';

final _storage = FlutterSecureStorage();

Future<void> savePendingInvite(String token) =>
    _storage.write(key: _key, value: token);

Future<String?> takePendingInvite() async {
  final token = await _storage.read(key: _key);
  if (token != null) await _storage.delete(key: _key);
  return token;
}

Future<String?> peekPendingInvite() => _storage.read(key: _key);
