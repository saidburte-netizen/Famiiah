import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/invite_store.dart';
import '../../core/supabase/client.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/ui.dart';

enum _InviteState { checking, needsAuth, accepting, done, error }

/// Accept an organization invitation from `fam://invite?token=<rawToken>`.
/// `accept_invitation` matches on the SHA-256 hash of the raw token.
class InviteScreen extends ConsumerStatefulWidget {
  final String? token;
  const InviteScreen({super.key, this.token});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  _InviteState _state = _InviteState.checking;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Kick the flow off after the first frame: it calls setState, which must
    // not happen during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      // No token in the deep link: show the error state immediately.
      _error = 'No invitation token was provided.';
      _state = _InviteState.error;
      return;
    }
    final session = getSupabase().auth.currentSession;
    if (session == null) {
      await savePendingInvite(token);
      if (mounted) setState(() => _state = _InviteState.needsAuth);
      return;
    }
    await _accept(token);
  }

  Future<void> _accept(String raw) async {
    setState(() {
      _state = _InviteState.accepting;
      _error = null;
    });
    try {
      final hash = sha256.convert(utf8.encode(raw)).toString();
      await acceptInvitation(hash);
      // Membership changed: refresh the shared org state before routing home.
      await ref.read(orgProvider.notifier).refresh();
      if (!mounted) return;
      setState(() => _state = _InviteState.done);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (mounted) context.go('/app/home');
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = userMessage(err);
          _state = _InviteState.error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _state == _InviteState.checking || _state == _InviteState.accepting;
    return FamScreen(
      child: ListView(
        children: [
          const SizedBox(height: 8),
          const FamLogo(size: 56, glow: true),
          const SizedBox(height: 18),
          const Text(
            'Organization invitation',
            style: TextStyle(
              fontFamily: FamFonts.body,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: FamColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Join the workspace your colleague invited you to.',
            style: TextStyle(
              fontFamily: FamFonts.body,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: FamColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (busy) ...[
                  const Center(child: CircularProgressIndicator(color: FamColors.royal)),
                  const SizedBox(height: 12),
                  Text(
                    _state == _InviteState.checking ? 'Checking your invitation…' : 'Joining the organization…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: FamFonts.body,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: FamColors.textMuted,
                    ),
                  ),
                ],
                if (_state == _InviteState.done) const FamNotice.success('You have joined the organization.'),
                if (_state == _InviteState.error) ...[
                  FamNotice.error(_error ?? 'Something went wrong.'),
                  const SizedBox(height: 14),
                  FamPrimaryButton(
                    label: 'Go to sign in',
                    onPressed: () => context.go('/auth/login'),
                  ),
                ],
                if (_state == _InviteState.needsAuth) ...[
                  const FamNotice('Sign in or create an account to accept this invitation. Your invitation is saved.'),
                  const SizedBox(height: 14),
                  FamPrimaryButton(
                    label: 'Sign in',
                    onPressed: () => context.go('/auth/login'),
                  ),
                  const SizedBox(height: 10),
                  FamSecondaryButton(
                    label: 'Create an account',
                    onPressed: () => context.go('/auth/sign-up'),
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
