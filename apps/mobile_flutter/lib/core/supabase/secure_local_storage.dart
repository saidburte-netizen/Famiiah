import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keychain / Keystore backed session store.
///
/// `supabase_flutter` defaults to `SharedPreferencesLocalStorage`, which keeps
/// the whole session — including the refresh token — in plain app-private
/// preferences. We mirror the React Native client (`expo-secure-store`) and keep
/// the session in the platform secure store instead: EncryptedSharedPreferences
/// (Android Keystore) on Android and the Keychain on iOS.
///
/// The storage key matches the Supabase default so dashboards/tooling find the
/// session where they expect it.
class SecureLocalStorage extends LocalStorage {
  const SecureLocalStorage();

  static const String _sessionKey = 'supabase.auth.token';

  // `static final`, not `const`: the plugin may change its constructor shape
  // between majors and a non-const constructor would break the build. The
  // default already uses Keystore-backed encryption on Android and the Keychain
  // on iOS.
  static final FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _sessionKey);

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _sessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _sessionKey);
}
