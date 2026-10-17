import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/client.dart';
import '../features/api.dart';
import 'auth_notifier.dart';

class OrgState {
  final String? orgId;
  final String? role;
  final bool loading;
  final Object? error;

  const OrgState({this.orgId, this.role, this.loading = true, this.error});

  bool get canManage => role == 'owner' || role == 'manager';
}

final orgProvider = StateNotifierProvider<OrgNotifier, OrgState>((ref) {
  final notifier = OrgNotifier();
  // Re-resolve the active membership whenever the signed-in user changes, so a
  // sign-out, sign-in or account switch never leaves a stale org behind.
  ref.listen<AsyncValue<Session?>>(authProvider, (previous, next) {
    final before = previous?.valueOrNull?.user.id;
    final after = next.valueOrNull?.user.id;
    if (before != after) notifier.refresh();
  });
  return notifier;
});

class OrgNotifier extends StateNotifier<OrgState> {
  OrgNotifier() : super(const OrgState()) {
    refresh();
  }

  /// A user may belong to several orgs; v1 picks the first active membership.
  /// Every screen shares this one request instead of re-querying.
  Future<void> refresh() async {
    state = const OrgState(loading: true);

    // Signed out: there is nothing to resolve and the query would just 401.
    if (getSupabase().auth.currentSession == null) {
      state = const OrgState(loading: false);
      return;
    }

    try {
      final row = await activeMembership();
      if (!mounted) return;
      state = OrgState(
        orgId: row?['org_id'] as String?,
        role: row?['role'] as String?,
        loading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = OrgState(loading: false, error: e);
    }
  }
}
