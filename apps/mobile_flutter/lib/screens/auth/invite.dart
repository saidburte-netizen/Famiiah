import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/invite_store.dart';
import '../../core/supabase/client.dart';
import '../../features/api.dart';
import '../../theme/tokens.dart';
import '../../widgets/ui.dart';

enum _InviteState { checking, needsAuth, accepting, done, error }

/// Accept an organization invitation from `fam://invite?token=<rawToken>`.
/// `accept_invitation` matches on the SHA-256 hash of the raw token.
class InviteScreen extends StatefulWidget {
  final String? token;
  const InviteScreen({super.key, this.token});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  _InviteState _state = _InviteState.checking;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      // Runs during initState (before first build): assign directly, no setState.
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
          Text('Organization invitation', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 12),
          FamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (busy) ...[
                  const Center(child: CircularProgressIndicator(color: FamColors.royal)),
                  const SizedBox(height: 12),
                  Text(
                    _state == _InviteState.checking ? 'Checking your invitation…' : 'Joining the organization…',
                    style: const TextStyle(color: FamColors.textMuted),
                  ),
                ],
                if (_state == _InviteState.done)
                  const Text('You have joined the organization.', style: TextStyle(color: FamColors.royal)),
                if (_state == _InviteState.error) ...[
                  Text(_error ?? 'Something went wrong.', style: const TextStyle(color: FamColors.danger)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => context.go('/auth/login'), child: const Text('Go to sign in')),
                ],
                if (_state == _InviteState.needsAuth) ...[
                  const Text('Sign in or create an account to accept this invitation. Your invitation is saved.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => context.go('/auth/login'), child: const Text('Sign in')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () => context.go('/auth/sign-up'), child: const Text('Create an account')),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
