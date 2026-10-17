import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/supabase/client.dart';
import 'routing/router.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'widgets/version_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!hasSupabaseConfig()) {
    runApp(const ConfigMissingApp());
    return;
  }

  try {
    await initSupabase();
  } catch (_) {
    // A broken/partial config must not white-screen the app before runApp.
    runApp(const ConfigMissingApp());
    return;
  }
  runApp(const ProviderScope(child: FamApp()));
}

class FamApp extends ConsumerWidget {
  const FamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Fam',
      theme: buildFamTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => VersionGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Shown when the app was compiled without usable Supabase configuration.
///
/// `String.fromEnvironment` resolves at *compile* time, so this cannot be
/// repaired at runtime — the values have to be present when the build runs. CI
/// enforces that ("Verify Supabase config" in `.github/workflows/flutter.yml`),
/// so only an old or mis-built install reaches here, and the wording is aimed
/// at the person holding the phone rather than at a developer. The technical
/// detail is kept behind `kDebugMode`.
class ConfigMissingApp extends StatelessWidget {
  const ConfigMissingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fam',
      theme: buildFamTheme(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: FamColors.midnight,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Fam',
                  style: TextStyle(
                    color: FamColors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "This app can't reach the server yet.\n"
                  'Please update to the latest version and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: FamColors.ice,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Developer build without config: pass --dart-define='
                    'FAM_SUPABASE_URL and --dart-define=FAM_SUPABASE_ANON_KEY.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
