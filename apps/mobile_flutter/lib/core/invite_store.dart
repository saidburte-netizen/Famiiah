import 'package:shared_preferences/shared_preferences.dart';

/// Pending invitation token.
///
/// When someone opens an invite deep link (`fam://invite?token=...`) without a
/// session, we stash the token so it survives sign-in / sign-up and can be
/// accepted afterwards. Mirrors `apps/mobile/lib/invite.ts`.
const _key = 'fam.pending_invite';

Future<void> savePendingInvite(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_key, token);
}

Future<String?> takePendingInvite() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(_key);
  if (token != null) await prefs.remove(_key);
  return token;
}

Future<String?> peekPendingInvite() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_key);
}
