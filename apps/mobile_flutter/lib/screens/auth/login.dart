import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/invite_store.dart';
import '../../core/phone.dart';
import '../../core/supabase/client.dart';
import '../../i18n/strings.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/ui.dart';

/// Sign in — navy gradient header over the white auth sheet, per the design.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    // One field takes both shapes: a value containing `@` goes to GoTrue as an
    // email (what the sign-up form creates and what pre-existing accounts use),
    // anything else is normalised to E.164 and sent as a phone number (enabled
    // later, once Providers → Phone is on).
    final identifier = _identifier.text.trim();
    final email = looksLikeEmail(identifier) ? identifier : null;
    final phone = email == null ? toE164(identifier) : null;
    if (email == null && phone == null) {
      setState(() => _error = t('error.invalidPhone'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await getSupabase().auth.signInWithPassword(
            email: email,
            phone: phone,
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
    final height = math.max(MediaQuery.sizeOf(context).height, 780.0);

    return Scaffold(
      backgroundColor: FamColors.background,
      body: SingleChildScrollView(
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 300,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(0.2, -1),
                      end: Alignment(-0.2, 1),
                      colors: FamGradients.header,
                    ),
                  ),
                ),
              ),
              const Positioned(right: -170, top: -120, child: FamRing(size: 420, opacity: 0.15)),
              const Positioned(right: -90, top: -60, child: FamRing(size: 260, opacity: 0.18)),
              Positioned(
                left: 28,
                right: 28,
                top: 48,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FamWordmark(size: 30, color: FamColors.white, glow: true),
                    const SizedBox(height: 34),
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        fontFamily: FamFonts.body,
                        fontSize: 30,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: FamColors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to manage your portfolio.',
                      style: TextStyle(
                        fontFamily: FamFonts.body,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: FamColors.iceSoft,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                top: 244,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  decoration: BoxDecoration(
                    color: FamColors.white,
                    borderRadius: BorderRadius.circular(FamRadius.sheet),
                    boxShadow: FamShadows.sheet,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        FamNotice.error(_error!),
                        const SizedBox(height: 14),
                      ],
                      FamField(
                        label: t('auth.phoneOrEmail'),
                        hint: 'you@example.com',
                        controller: _identifier,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.mail_outline_rounded,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                      ),
                      const SizedBox(height: 14),
                      FamField(
                        label: t('auth.password'),
                        hint: 'Enter your password',
                        controller: _password,
                        obscureText: !_showPassword,
                        prefixIcon: Icons.lock_outline_rounded,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _busy ? null : _signIn(),
                        autofillHints: const [AutofillHints.password],
                        suffix: IconButton(
                          tooltip: _showPassword ? 'Hide password' : 'Show password',
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.go('/auth/forgot-password'),
                          child: Text(t('auth.forgotPassword')),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FamPrimaryButton(
                        label: t('auth.signIn'),
                        loading: _busy,
                        onPressed: _busy ? null : _signIn,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'New to Fam?',
                      style: TextStyle(
                        fontFamily: FamFonts.body,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: FamColors.textLabel,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/auth/sign-up'),
                      child: Text(t('auth.signUp')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
