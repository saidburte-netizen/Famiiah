import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, UserAttributes;

import '../../core/errors/user_message.dart';
import '../../core/supabase/client.dart';
import '../../i18n/strings.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
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
    // is not left on a blank screen. `_hasSession` is still null here when the
    // observer never delivered a session (the token was expired or already
    // used), so flip it to false; a session that did arrive is left alone.
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted && _hasSession == null) setState(() => _hasSession = false);
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
          const Text(
            'Set a new password',
            style: TextStyle(
              fontFamily: FamFonts.body,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: FamColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t('auth.resetPasswordTitle'),
            style: const TextStyle(
              fontFamily: FamFonts.body,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: FamColors.textMuted,
            ),
          ),
          const SizedBox(height: 18),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_done) ...[
                  FamNotice.success(t('auth.passwordUpdated')),
                  const SizedBox(height: 16),
                  FamPrimaryButton(
                    label: 'Continue',
                    onPressed: () => context.go('/app/home'),
                  ),
                ] else if (_hasSession == null) ...[
                  const Center(child: CircularProgressIndicator(color: FamColors.royal)),
                ] else if (!_hasSession!) ...[
                  FamNotice.error(t('error.invalidToken')),
                  const SizedBox(height: 16),
                  FamPrimaryButton(
                    label: 'Send a new link',
                    onPressed: () => context.go('/auth/forgot-password'),
                  ),
                ] else ...[
                  FamField(
                    label: t('auth.newPassword'),
                    hint: 'Create a password',
                    controller: _password,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline_rounded,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _busy ? null : _submit(),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'At least 8 characters, with an uppercase letter and a number.',
                    style: TextStyle(
                      fontFamily: FamFonts.body,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: FamColors.textMuted,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    FamNotice.error(_error!),
                  ],
                  const SizedBox(height: 16),
                  FamPrimaryButton(
                    label: t('auth.updatePassword'),
                    loading: _busy,
                    onPressed: _busy ? null : _submit,
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
