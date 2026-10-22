import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/strings.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';

/// Bottom tab shell: Home, Properties, Tenants, Rent (+ Admin for owner/manager).
class AppShell extends ConsumerWidget {
  final GoRouterState state;
  final Widget child;

  const AppShell({super.key, required this.state, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgProvider);
    final showAdmin = org.role == 'owner' || org.role == 'manager';

    final destinations = <_Dest>[
      const _Dest('/app/home', Icons.home_outlined, Icons.home_rounded, 'nav.home'),
      const _Dest('/app/properties', Icons.apartment_outlined, Icons.apartment_rounded, 'nav.properties'),
      const _Dest('/app/tenants', Icons.people_outline, Icons.people_alt_rounded, 'nav.tenants'),
      const _Dest('/app/rent', Icons.payments_outlined, Icons.payments_rounded, 'nav.rent'),
      if (showAdmin)
        const _Dest('/app/admin', Icons.admin_panel_settings_outlined,
            Icons.admin_panel_settings_rounded, 'nav.admin'),
    ];

    final loc = state.matchedLocation;
    var index = destinations.indexWhere((d) => loc.startsWith(d.path));
    if (index < 0) index = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: FamColors.white,
          border: Border(top: BorderSide(color: FamColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 76,
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _NavItem(
                      destination: destinations[i],
                      selected: i == index,
                      label: t(destinations[i].labelKey),
                      onTap: () => context.go(destinations[i].path),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One tab: the icon sits in a tinted pill when active, per the design.
class _NavItem extends StatelessWidget {
  final _Dest destination;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.destination,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? FamColors.royal : FamColors.textMuted;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 52,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? FamColors.tint : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(selected ? destination.selected : destination.icon, size: 22, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dest {
  final String path;
  final IconData icon;
  final IconData selected;
  final String labelKey;
  const _Dest(this.path, this.icon, this.selected, this.labelKey);
}
