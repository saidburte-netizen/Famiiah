/// Device push registration.
///
/// The backend stores a device push token per user (`register_device_token`)
/// and `send-reminders` dispatches queued notifications to those tokens through
/// the Expo push API. The Expo (React Native) client can obtain an Expo token
/// directly; the Flutter client has no push provider configured in this repo
/// (Android push needs an FCM `google-services.json`, which is not committed).
///
/// Rather than ship a plugin that cannot build without those credentials, this
/// hook is the single place push registration happens: today it is a no-op, and
/// wiring a provider later means implementing [PushTokenSource] and nothing else
/// in the UI. The RPC contract is fixed and already exercised by the RN client,
/// so the server side needs no change when Flutter push is switched on.
library;

import 'supabase/client.dart';

/// Where a push token comes from. Implemented per client once a push provider
/// is configured; kept as an interface so the app never hard-depends on one.
abstract class PushTokenSource {  /// The current device's push token, or null when unavailable/denied.
  Future<String?> getToken();

  /// The platform the token belongs to: `android` or `ios`.
  String get platform;
}

PushTokenSource? _source;

/// Install the platform push provider (called from `main()` once one exists).
void setPushTokenSource(PushTokenSource source) {
  _source = source;
}

/// Register this device's push token with the backend, if a provider is wired
/// and the user is signed in. Safe to call on every launch: the RPC upserts on
/// the token. Never throws — a missing token or a transient failure is retried
/// on the next launch and must not block the app.
Future<void> registerPushToken() async {
  final source = _source;
  if (source == null) return;
  if (getSupabase().auth.currentSession == null) return;
  try {
    final token = await source.getToken();
    if (token == null || token.isEmpty) return;
    await getSupabase().rpc(
      'register_device_token',
      params: {'p_token': token, 'p_platform': source.platform},
    );
  } catch (_) {
    // Permission denied or a transient network failure — nothing to surface.
  }
}
