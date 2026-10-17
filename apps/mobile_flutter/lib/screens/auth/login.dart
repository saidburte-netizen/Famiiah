import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/invite_store.dart';
import '../../core/supabase/client.dart';
import '../../i18n/strings.dart';
import '../../theme/tokens.dart';
import '../../widgets/ui.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await getSupabase().auth.signInWithPassword(
            email: _email.text.trim(),
            password: _password.text,
          );
      final pending = await takePendingInvite();
      if (!mounted) return;
      if (pending != null) {
        context.go('/invite?token=${Uri.encodeComponent(pending)}');
        return;
      }
      context.go('/app/home');
    } catch (err) {
      if (mounted) setState(() => _error = userMessage(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FamScreen(
      child: ListView(
        children: [
          Text(t('app.name'), style: Theme.of(context).textTheme.displayLarge),
          Text('Property & rental control',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: FamColors.textMuted)),
          const SizedBox(height: 20),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: FamColors.danger)),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                FamField(
                  label: t('auth.email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                FamField(label: t('auth.password'), controller: _password, obscureText: true),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _signIn,
                  child: _busy
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(t('auth.signIn')),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.go('/auth/forgot-password'),
                  child: Text(t('auth.forgotPassword')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => context.go('/auth/sign-up'), child: Text(t('auth.signUp'))),
        ],
      ),
    );
  }
}
