import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Compile-time configuration keys (pass via `--dart-define`).
const _kSupabaseUrl = 'FAM_SUPABASE_URL';
const _kSupabaseAnonKey = 'FAM_SUPABASE_ANON_KEY';
const _kAppEnv = 'FAM_APP_ENV';

/// Returns true if the app was built with the required public Supabase config.
bool hasSupabaseConfig() {
  final url = const String.fromEnvironment(_kSupabaseUrl, defaultValue: '');
  final anon = const String.fromEnvironment(_kSupabaseAnonKey, defaultValue: '');
  return url.isNotEmpty && anon.isNotEmpty;
}

/// Initialize Supabase once. Must be called in `main()` before runApp().
Future<void> initSupabase() async {
  if (!hasSupabaseConfig()) {
    throw StateError('missing_supabase_env');
  }
  await Supabase.initialize(
    url: const String.fromEnvironment(_kSupabaseUrl),
    anonKey: const String.fromEnvironment(_kSupabaseAnonKey),
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false,
    ),
    realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 10),
  );
}

SupabaseClient getSupabase() => Supabase.instance.client;

/// Get the app environment (e.g. local|staging|production). Read from
/// `--dart-define=FAM_APP_ENV` and defaults to "local".
String getAppEnv() => const String.fromEnvironment(_kAppEnv, defaultValue: 'local');

/// Current client version, read from the platform bundle (matches the RN app's
/// `expoConfig.version`). Falls back to 1.0.0 when the plugin is unavailable
/// (e.g. in unit tests).
Future<String> getAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version.isEmpty ? '1.0.0' : info.version;
  } catch (_) {
    return '1.0.0';
  }
}
