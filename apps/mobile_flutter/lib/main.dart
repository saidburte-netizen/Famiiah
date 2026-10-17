import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/supabase/client.dart';
import 'routing/router.dart';
import 'theme/app_theme.dart';
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

class ConfigMissingApp extends StatelessWidget {
  const ConfigMissingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fam',
      theme: buildFamTheme(),
      home: const Scaffold(
        backgroundColor: Color(0xFF061538),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Configuration missing',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  'Missing FAM_SUPABASE_URL / FAM_SUPABASE_ANON_KEY.\nPass --dart-define for both.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
