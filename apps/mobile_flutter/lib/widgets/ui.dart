import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A padded screen container with the app background.
class FamScreen extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const FamScreen({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FamColors.background,
      body: SafeArea(
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A card with the brand border/radius.
class FamCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const FamCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: FamColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FamRadius.card),
        side: const BorderSide(color: FamColors.border),
      ),
      elevation: 0,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Standard text field with label.
class FamField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const FamField({
    super.key,
    required this.label,
    this.controller,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: FamColors.textMuted)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(errorText: errorText),
        ),
      ],
    );
  }
}

/// Error card with an optional retry.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return FamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Something went wrong',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: FamColors.danger)),
          const SizedBox(height: 6),
          Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: FamColors.textMuted)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;

  const EmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: FamColors.textMuted));
  }
}
