import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/push.dart';
import '../core/supabase/client.dart';

/// Owns the auth session for the whole tree: one listener, one source of truth.
final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<Session?>>((ref) {
  return AuthNotifier();
});

/// Convenience: the current session (null while loading or signed out).
final sessionProvider = Provider<Session?>((ref) {
  return ref.watch(authProvider).valueOrNull;
});

final userProvider = Provider<User?>((ref) => ref.watch(sessionProvider)?.user);

class AuthNotifier extends StateNotifier<AsyncValue<Session?>> {
  AuthNotifier() : super(const AsyncLoading()) {
    _init();
  }

  StreamSubscription<AuthState>? _sub;

  Future<void> _init() async {
    final client = getSupabase();
    try {
      final session = await client.auth.getSession();
      if (mounted) state = AsyncValue.data(session);
      if (session != null) await registerPushToken();
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
    _sub = client.auth.onAuthStateChange.listen((event) {
      if (mounted) state = AsyncValue.data(event.session);
      // A fresh sign-in is the other moment a token may become registrable
      // (the app may have launched signed-out).
      if (event.event == AuthChangeEvent.signedIn) {
        registerPushToken();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> signOut() async {
    await getSupabase().auth.signOut();
  }
}
