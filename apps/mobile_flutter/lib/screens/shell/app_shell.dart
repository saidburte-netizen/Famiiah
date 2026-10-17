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
      const _Dest('/app/home', Icons.home_outlined, Icons.home, 'nav.home'),
      const _Dest('/app/properties', Icons.apartment_outlined, Icons.apartment, 'nav.properties'),
      const _Dest('/app/tenants', Icons.people_outline, Icons.people, 'nav.tenants'),
      const _Dest('/app/rent', Icons.payments_outlined, Icons.payments, 'nav.rent'),
      if (showAdmin)
        const _Dest('/app/admin', Icons.admin_panel_settings_outlined, Icons.admin_panel_settings, 'nav.admin'),
    ];

    final loc = state.matchedLocation;
    var index = destinations.indexWhere((d) => loc.startsWith(d.path));
    if (index < 0) index = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        backgroundColor: FamColors.white,
        indicatorColor: FamColors.tint,
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(destinations[i].path),
        destinations: destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selected, color: FamColors.royal),
                  label: t(d.labelKey),
                ))
            .toList(),
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
