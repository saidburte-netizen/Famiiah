import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/brand.dart';

/// Brand splash: the navy gradient with the two decorative rings, the Fam
/// mark, the wordmark and the tagline — shown while the session is restored.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          const Positioned(left: -115, top: 40, child: FamRing(size: 620, opacity: 0.14)),
          const Positioned(left: -25, top: 130, child: FamRing(size: 440, opacity: 0.16)),
          Positioned(
            left: 65,
            top: 150,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [famAlpha(FamColors.royalLift, 0.45), famAlpha(FamColors.royalLift, 0)],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FamLogo(size: 138, glow: true),
                const SizedBox(height: 30),
                const Text(
                  'Fam',
                  style: TextStyle(
                    fontFamily: FamFonts.display,
                    fontSize: 52,
                    height: 1,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: FamColors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'PROPERTY & RENTAL CONTROL',
                  style: TextStyle(
                    fontFamily: FamFonts.body,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3.1,
                    color: FamColors.ice,
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 28,
            right: 28,
            bottom: 64,
            child: Column(
              children: [
                FamDots(active: 0),
                SizedBox(height: 18),
                Text(
                  'Properties, shops, tenants, stock and rent.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: FamFonts.body,
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: FamColors.iceSoft,
                  ),
                ),
                Text(
                  'One calm place to run them all.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: FamFonts.body,
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: FamColors.iceSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
