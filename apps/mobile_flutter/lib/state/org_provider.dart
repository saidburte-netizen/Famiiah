import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/api.dart';

class OrgState {
  final String? orgId;
  final String? role;
  final bool loading;
  final Object? error;

  const OrgState({this.orgId, this.role, this.loading = true, this.error});

  bool get canManage => role == 'owner' || role == 'manager';
}

final orgProvider = StateNotifierProvider<OrgNotifier, OrgState>((ref) {
  return OrgNotifier();
});

class OrgNotifier extends StateNotifier<OrgState> {
  OrgNotifier() : super(const OrgState()) {
    refresh();
  }

  /// A user may belong to several orgs; v1 picks the first active membership.
  /// Every screen shares this one request instead of re-querying.
  Future<void> refresh() async {
    state = const OrgState(loading: true);
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
