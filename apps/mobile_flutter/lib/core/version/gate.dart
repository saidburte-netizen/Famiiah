import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/client.dart';

enum GateKind { ok, updateAvailable, forceUpdate }

class GateDecision {
  final GateKind kind;
  final String? storeUrl;
  final String? notes;

  const GateDecision._(this.kind, {this.storeUrl, this.notes});

  factory GateDecision.ok() => const GateDecision._(GateKind.ok);
  factory GateDecision.updateAvailable({String? storeUrl, String? notes}) =>
      GateDecision._(GateKind.updateAvailable, storeUrl: storeUrl, notes: notes);
  factory GateDecision.forceUpdate({String? storeUrl, String? notes}) =>
      GateDecision._(GateKind.forceUpdate, storeUrl: storeUrl, notes: notes);
}

/// On launch ask the backend whether this client is supported.
/// Fails open on network error (never bricks the app).
Future<GateDecision> checkVersionGate(String platform, String currentVersion) async {
  try {
    final client = getSupabase();
    final data = await client.rpc(
      'check_app_version',
      params: {'p_platform': platform, 'p_version': currentVersion},
    );
    if (data == null) return GateDecision.ok();
    final status = data['status'] as String?;
    if (status == 'force_update') {
      return GateDecision.forceUpdate(
        storeUrl: data['store_url'] as String?,
        notes: data['notes'] as String?,
      );
    }
    if (status == 'update_available') {
      return GateDecision.updateAvailable(
        storeUrl: data['store_url'] as String?,
        notes: data['notes'] as String?,
      );
    }
    return GateDecision.ok();
  } catch (_) {
    return GateDecision.ok();
  }
}
