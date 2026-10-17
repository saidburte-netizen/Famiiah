import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/supabase/client.dart';
import '../core/version/gate.dart';
import '../theme/tokens.dart';

/// Blocks the app when the backend requires an update. Fails open on network
/// error so a flaky connection never bricks the app.
class VersionGate extends ConsumerStatefulWidget {
  final Widget child;
  const VersionGate({super.key, required this.child});

  @override
  ConsumerState<VersionGate> createState() => _VersionGateState();
}

class _VersionGateState extends ConsumerState<VersionGate> {
  GateDecision? _decision;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final version = await getAppVersion();
    final decision = await checkVersionGate(_platformName(), version);
    if (mounted) setState(() => _decision = decision);
  }

  /// The backend compares per-platform; web falls back to the android rules
  /// (and the gate fails open anyway).
  String _platformName() {
    if (kIsWeb) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'android';
  }

  @override
  Widget build(BuildContext context) {
    final decision = _decision;
    if (decision == null) {
      return const Scaffold(
        backgroundColor: FamColors.midnight,
        body: Center(child: CircularProgressIndicator(color: FamColors.ice)),
      );
    }
    if (decision.kind == GateKind.forceUpdate) {
      return Scaffold(
        backgroundColor: FamColors.midnight,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Update required',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: FamColors.ice, fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  decision.notes ?? 'A newer version of Fam is required to continue.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: FamColors.ice),
                ),
                const SizedBox(height: 16),
                if (decision.storeUrl != null)
                  FilledButton(
                    onPressed: () => launchUrl(Uri.parse(decision.storeUrl!)),
                    child: const Text('Update now'),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return widget.child;
  }
}
