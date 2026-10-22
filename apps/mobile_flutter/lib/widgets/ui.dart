import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'brand.dart';

/// A padded screen container with the app background.
class FamScreen extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool safeArea;

  const FamScreen({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return Scaffold(
      backgroundColor: FamColors.background,
      body: safeArea ? SafeArea(child: body) : body,
    );
  }
}

/// A card with the brand radius and soft shadow.
class FamCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? shadow;
  final Border? border;
  final VoidCallback? onTap;

  const FamCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = FamColors.white,
    this.borderRadius,
    this.shadow,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(FamRadius.card);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        boxShadow: shadow ?? FamShadows.card,
        border: border,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      ),
    );
  }
}

/// Standard text field with a floating label above a 54 px control,
/// matching the design's input style (white fill, 1.5 px border, 14 radius).
class FamField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool enabled;
  final bool autocorrect;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final bool autofocus;
  final String? helperText;

  const FamField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.onChanged,
    this.prefixIcon,
    this.suffix,
    this.enabled = true,
    this.autocorrect = true,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.autofocus = false,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: FamFonts.body,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: FamColors.textLabel,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          maxLines: obscureText ? 1 : maxLines,
          onChanged: onChanged,
          enabled: enabled,
          autocorrect: autocorrect,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          autofillHints: autofillHints,
          autofocus: autofocus,
          style: const TextStyle(
            fontFamily: FamFonts.body,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: FamColors.text,
          ),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            helperText: helperText,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
            suffixIcon: suffix,
            constraints: const BoxConstraints(minHeight: 50),
          ),
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FamColors.dangerBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.error_outline_rounded,
                    size: 22, color: FamColors.danger),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontFamily: FamFonts.body,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: FamColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontFamily: FamFonts.body,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: FamColors.textMuted,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            FamSecondaryButton(label: 'Try again', onPressed: onRetry, height: 46, dense: true),
          ],
        ],
      ),
    );
  }
}

/// Friendly empty state with the brand illustration.
class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FamEmptyIllustration(icon: icon),
            const SizedBox(height: 14),
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: FamFonts.body,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: FamColors.navy,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: FamColors.textMuted,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FamPrimaryButton(label: actionLabel!, onPressed: onAction, height: 48, dense: true),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline notice banner (success / info / warning / error).
class FamNotice extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color foreground;
  final Color background;

  const FamNotice({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.foreground = FamColors.royalMid,
    this.background = FamColors.tint,
  });

  const FamNotice.error(this.message, {super.key})
      : icon = Icons.error_outline_rounded,
        foreground = FamColors.danger,
        background = FamColors.dangerBg;

  const FamNotice.success(this.message, {super.key})
      : icon = Icons.check_circle_outline_rounded,
        foreground = FamColors.success,
        background = FamColors.successBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(FamRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled row used by detail screens and settings.
class FamInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const FamInfoRow({super.key, required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: FamColors.textMuted),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: FamColors.textMuted,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: FamColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
