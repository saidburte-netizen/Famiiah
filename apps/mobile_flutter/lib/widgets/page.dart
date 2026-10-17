import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A pushed screen: brand AppBar + scrollable padded body.
class FamPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  const FamPage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FamColors.background,
      appBar: AppBar(title: Text(title), actions: actions),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(20), child: child),
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
