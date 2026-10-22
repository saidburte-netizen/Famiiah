import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'brand.dart';

/// A pushed screen: brand AppBar + padded body.
class FamPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final bool pad;

  const FamPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.floatingActionButton,
    this.pad = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FamColors.background,
      appBar: AppBar(
        backgroundColor: FamColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.of(context).canPop()
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Center(
                  child: FamIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    background: FamColors.white,
                    size: 40,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              )
            : null,
        leadingWidth: Navigator.of(context).canPop() ? 64 : null,
        titleSpacing: Navigator.of(context).canPop() ? 4 : 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: FamColors.navy,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: FamFonts.body,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: FamColors.textMuted,
                ),
              ),
          ],
        ),
        actions: [
          ...actions,
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(pad ? 20 : 0, pad ? 16 : 0, pad ? 20 : 0, pad ? 20 : 0),
          child: child,
        ),
      ),
    );
  }
}

/// A padded loading spinner centred in the page body.
class FamLoading extends StatelessWidget {
  const FamLoading({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: FamColors.royal));
}
