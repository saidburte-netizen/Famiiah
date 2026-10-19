import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, UserAttributes;

import '../../core/errors/user_message.dart';
import '../../core/supabase/client.dart';
import '../../i18n/strings.dart';
import '../../theme/tokens.dart';
import '../../widgets/ui.dart';

/// Finish a password reset: the user arrives from the `fam://reset-password`
/// link GoTrue emails. `supabase_flutter`'s deep-link observer exchanges the
/// recovery tokens in the URI fragment for a session (see
/// `detectSessionInUri` / `isAuthCallbackLink` in `core/supabase/client.dart`),
/// so this screen only has to ask for the new password and call `updateUser`.
///
/// The exchange is asynchronous: the screen subscribes to auth state while it
/// waits, so it neither flashes "invalid link" for a good link nor sits blank.
/// A link that expired or was already used carries no tokens, so no session
/// ever arrives and the screen offers a fresh link instead of a raw error.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _password = TextEditingController();
  StreamSubscription<AuthState>? _sub;
  bool _busy = false;
  bool _done = false;
  String? _error;

  /// null = still waiting for a recovery session to arrive.
  bool? _hasSession;

  @override
  void initState() {
    super.initState();
    final auth = getSupabase().auth;
    _hasSession = auth.currentSession != null;
    // The recovery tokens are exchanged by the deep-link observer, which can
    // finish after this screen is built — listen so the form appears the moment
    // the session lands.
    _sub = auth.onAuthStateChange.listen((event) {
      if (event.session != null && mounted) setState(() => _hasSession = true);
    });
    // If no session shows up shortly, treat the link as expired/used so the user
    // is not left on a blank screen.
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted && _hasSession == false) setState(() => _hasSession = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await getSupabase().auth.updateUser(UserAttributes(password: _password.text));
      if (mounted) setState(() => _done = true);
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
          Text(t('auth.resetPasswordTitle'), style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 12),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_done) ...[
                  Text(t('auth.passwordUpdated'), style: const TextStyle(color: FamColors.royal)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go('/app/home'),
                    child: const Text('Continue'),
                  ),
                ] else if (_hasSession == null) ...[
                  const Center(child: CircularProgressIndicator(color: FamColors.royal)),
                ] else if (!_hasSession!) ...[
                  Text(t('error.invalidToken'), style: const TextStyle(color: FamColors.danger)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go('/auth/forgot-password'),
                    child: const Text('Send a new link'),
                  ),
                ] else ...[
                  FamField(
                    label: t('auth.newPassword'),
                    controller: _password,
                    obscureText: true,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'At least 8 characters, with an uppercase letter and a number.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: FamColors.textMuted),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: FamColors.danger)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(t('auth.updatePassword')),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
