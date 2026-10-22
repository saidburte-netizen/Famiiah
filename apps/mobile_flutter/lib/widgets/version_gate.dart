import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/supabase/client.dart';
import '../core/version/gate.dart';
import '../theme/tokens.dart';
import 'brand.dart';

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
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0.2, -1),
                    end: Alignment(-0.2, 1),
                    colors: FamGradients.header,
                  ),
                ),
              ),
            ),
            const Positioned(right: -170, top: -120, child: FamRing(size: 420, opacity: 0.15)),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const FamLogo(size: 84, glow: true),
                    const SizedBox(height: 24),
                    const Text(
                      'Update required',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: FamFonts.body,
                        color: FamColors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      decision.notes ?? 'A newer version of Fam is required to continue.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: FamFonts.body,
                        color: FamColors.iceSoft,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (decision.storeUrl != null)
                      FamPrimaryButton(
                        label: 'Update now',
                        icon: Icons.download_rounded,
                        onPressed: () => launchUrl(Uri.parse(decision.storeUrl!)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return widget.child;
  }
}
