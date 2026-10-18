import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keychain / Keystore backed session store.
///
/// `supabase_flutter` defaults to `SharedPreferencesLocalStorage`, which keeps
/// the whole session — including the refresh token — in plain app-private
/// preferences. We mirror the React Native client (`expo-secure-store`) and keep
/// the session in the platform secure store instead: EncryptedSharedPreferences
/// (Android Keystore) on Android and the Keychain on iOS.
///
/// Some Android devices ship a Keystore that throws on write (broken or
/// wiped `AndroidKeyStore`, common on a subset of budget OEM ROMs). The write
/// happens *inside* `auth.signUp()` / `signInWithPassword()`, so a throw there
/// used to surface as a generic "Something went wrong" **after** the account
/// was created server-side — sign-up appeared broken while the backend was
/// healthy. Availability wins over storage confidentiality here: when the
/// secure store fails, the session falls back to plain app-private
/// preferences — exactly where `supabase_flutter` keeps it by default —
/// instead of failing the auth flow. The fallback copy is cleared whenever a
/// secure write or a sign-out succeeds, so healthy devices never keep one.
///
/// The storage key matches the Supabase default so dashboards/tooling find the
/// session where they expect it.
class SecureLocalStorage extends LocalStorage {
  const SecureLocalStorage();

  static const String _sessionKey = 'supabase.auth.token';

  // One shared instance: the default options already use Keystore-backed
  // encryption on Android and the Keychain on iOS, which is what we want.
  static final FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    try {
      if (await _storage.containsKey(key: _sessionKey)) return true;
    } catch (_) {
      // Broken Keystore on this device — the plain copy below still counts.
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_sessionKey);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> accessToken() async {
    try {
      final value = await _storage.read(key: _sessionKey);
      if (value != null) return value;
    } catch (_) {
      // Broken Keystore — fall through to the plain copy below.
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_sessionKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(key: _sessionKey, value: persistSessionString);
      await _clearFallback();
      return;
    } catch (_) {
      // Broken Keystore: the auth request already succeeded, so keep the user
      // signed in from a plain app-private copy instead of failing sign-up.
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, persistSessionString);
    } catch (_) {
      // Nowhere left to store it; the user simply won't be remembered.
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: _sessionKey);
    } catch (_) {
      // Broken Keystore — still remove the plain copy below.
    }
    await _clearFallback();
  }

  static Future<void> _clearFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (_) {
      // Best effort only; a stale fallback copy is preferred over an error.
    }
  }
}
