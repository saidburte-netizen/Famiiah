import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/admin/admin.dart';
import '../screens/auth/create_organization.dart';
import '../screens/auth/forgot_password.dart';
import '../screens/auth/invite.dart';
import '../screens/auth/login.dart';
import '../screens/auth/sign_up.dart';
import '../screens/home/dashboard.dart';
import '../screens/notifications/notifications.dart';
import '../screens/payments/list.dart';
import '../screens/payments/new.dart';
import '../screens/properties/detail.dart';
import '../screens/properties/list.dart';
import '../screens/properties/new.dart';
import '../screens/rent/list.dart';
import '../screens/reports/reports.dart';
import '../screens/settings/settings.dart';
import '../screens/shell/app_shell.dart';
import '../screens/splash.dart';
import '../screens/stock/list.dart';
import '../screens/stock/rentals.dart';
import '../screens/tenants/detail.dart';
import '../screens/tenants/list.dart';
import '../screens/tenants/new.dart';
import '../state/auth_notifier.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) => refresh.value++);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      if (auth.isLoading) return null;

      final session = auth.valueOrNull;
      final loc = state.matchedLocation;
      final public = loc.startsWith('/auth') || loc == '/invite';

      if (session == null) {
        return public ? null : '/auth/login';
      }
      if (loc == '/' ||
          loc == '/auth/login' ||
          loc == '/auth/sign-up' ||
          loc == '/auth/forgot-password' ||
          loc == '/auth/create-organization') {
        return '/app/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),

      // ---- auth ----
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/auth/sign-up', builder: (_, __) => const SignUpScreen()),
      GoRoute(path: '/auth/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/auth/create-organization', builder: (_, __) => const CreateOrganizationScreen()),
      GoRoute(
        path: '/invite',
        builder: (_, state) => InviteScreen(token: state.uri.queryParameters['token']),
      ),

      // ---- app shell (bottom tabs) ----
      ShellRoute(
        builder: (context, state, child) => AppShell(state: state, child: child),
        routes: [
          GoRoute(path: '/app/home', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/app/properties', builder: (_, __) => const PropertiesScreen()),
          GoRoute(path: '/app/tenants', builder: (_, __) => const TenantsScreen()),
          GoRoute(path: '/app/rent', builder: (_, __) => const RentScreen()),
          GoRoute(path: '/app/admin', builder: (_, __) => const AdminScreen()),
        ],
      ),

      // ---- pushed screens ----
      GoRoute(path: '/app/properties/new', builder: (_, __) => const NewPropertyScreen()),
      GoRoute(
        path: '/app/properties/:id',
        builder: (_, state) => PropertyDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/app/tenants/new',
        builder: (_, state) => NewTenantScreen(unitId: state.uri.queryParameters['unitId']),
      ),
      GoRoute(
        path: '/app/tenants/:id',
        builder: (_, state) => TenantDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/app/payments', builder: (_, __) => const PaymentsScreen()),
      GoRoute(
        path: '/app/payments/new',
        builder: (_, state) => NewPaymentScreen(leaseId: state.uri.queryParameters['leaseId']),
      ),
      GoRoute(path: '/app/stock', builder: (_, __) => const StockScreen()),
      GoRoute(path: '/app/stock/rentals', builder: (_, __) => const StockRentalsScreen()),
      GoRoute(path: '/app/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/app/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/app/settings', builder: (_, __) => const SettingsScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(child: Text(state.error?.toString() ?? 'Page not found')),
    ),
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
