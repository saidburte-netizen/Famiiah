import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Returns [c] at [alpha] (0..1) without the deprecated `withOpacity`.
Color famAlpha(Color c, double alpha) => c.withAlpha((alpha.clamp(0, 1) * 255).round());

/// The Fam app mark: a rounded square with the brand gradient, the blocky
/// white "F", its window grid, door and baseline. Drawn rather than shipped as
/// a bitmap so it stays crisp at every size (22 px tab icon → 138 px splash).
class FamLogo extends StatelessWidget {
  final double size;

  /// Adds the soft drop shadow used on the splash and auth headers.
  final bool glow;

  const FamLogo({super.key, this.size = 44, this.glow = false});

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size.square(size),
      painter: _FamMarkPainter(),
    );
    if (!glow) return mark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.23),
        boxShadow: [
          BoxShadow(
            color: const Color(0x80000000),
            blurRadius: size * 0.22,
            offset: Offset(0, size * 0.15),
          ),
        ],
      ),
      child: mark,
    );
  }
}

class _FamMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 512.0;
    canvas.save();
    canvas.scale(s);

    final rect = const Rect.fromLTWH(0, 0, 512, 512);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(118));

    // Brand gradient body.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: FamGradients.mark,
        ).createShader(rect),
    );

    // Diagonal sheen.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.5, -0.7),
          radius: 1.1,
          colors: [Color(0x4DFFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
    );

    // Hairline inner border.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 8, 496, 496),
        const Radius.circular(110),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x38FFFFFF),
    );

    canvas.save();
    canvas.translate(16, -9);

    // The "F".
    final f = Path()
      ..moveTo(166, 118)
      ..lineTo(336, 118)
      ..quadraticBezierTo(352, 118, 352, 134)
      ..lineTo(352, 172)
      ..quadraticBezierTo(352, 188, 336, 188)
      ..lineTo(236, 188)
      ..lineTo(236, 230)
      ..lineTo(308, 230)
      ..quadraticBezierTo(324, 230, 324, 246)
      ..lineTo(324, 272)
      ..quadraticBezierTo(324, 288, 308, 288)
      ..lineTo(236, 288)
      ..lineTo(236, 398)
      ..lineTo(166, 398)
      ..close();
    canvas.drawPath(
      f,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), FamColors.ice],
        ).createShader(const Rect.fromLTWH(0, 118, 512, 280)),
    );

    // Window grid on the stem.
    final windowPaint = Paint()..color = famAlpha(FamColors.royal, 0.38);
    for (final x in [180.0, 206.0]) {
      for (final y in [210.0, 258.0, 306.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 16, 22), const Radius.circular(3)),
          windowPaint,
        );
      }
    }

    // Door.
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(188, 350, 26, 48), const Radius.circular(4)),
      Paint()..color = famAlpha(FamColors.navy, 0.9),
    );

    // Baseline.
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(134, 398, 244, 12), const Radius.circular(6)),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Mark + "Fam" wordmark, as used in the auth headers.
class FamWordmark extends StatelessWidget {
  final double size;
  final Color color;
  final bool glow;

  const FamWordmark({
    super.key,
    this.size = 30,
    this.color = FamColors.navy,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FamLogo(size: size * 1.5, glow: glow),
        SizedBox(width: size * 0.4),
        Text(
          'Fam',
          style: TextStyle(
            fontFamily: FamFonts.display,
            fontSize: size,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// A translucent concentric ring used to decorate the navy gradient surfaces.
class FamRing extends StatelessWidget {
  final double size;
  final double opacity;

  const FamRing({super.key, required this.size, this.opacity = 0.16});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: famAlpha(FamColors.ice, opacity), width: 1),
        ),
      ),
    );
  }
}

/// Navy/royal gradient surface with the two decorative rings from the design.
class FamGradientSurface extends StatelessWidget {
  final Widget child;
  final List<Color> colors;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final List<BoxShadow>? shadow;
  final Alignment gradientBegin;
  final Alignment gradientEnd;

  const FamGradientSurface({
    super.key,
    required this.child,
    this.colors = FamGradients.hero,
    this.borderRadius = const BorderRadius.all(Radius.circular(FamRadius.hero)),
    this.padding = const EdgeInsets.all(18),
    this.shadow,
    this.gradientBegin = Alignment.topLeft,
    this.gradientEnd = Alignment.bottomRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(begin: gradientBegin, end: gradientEnd, colors: colors),
        boxShadow: shadow ?? FamShadows.hero,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(right: -70, top: -90, child: FamRing(size: 220, opacity: 0.20)),
          Positioned(right: -30, top: -50, child: FamRing(size: 130, opacity: 0.22)),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// White rounded-square control with the small design shadow.
class FamIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color background;
  final Color foreground;
  final bool bordered;

  const FamIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 44,
    this.background = FamColors.white,
    this.foreground = FamColors.navy,
    this.bordered = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: background,
      borderRadius: BorderRadius.circular(FamRadius.input),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(FamRadius.input),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FamRadius.input),
            border: bordered ? Border.all(color: FamColors.border, width: 1.5) : null,
          ),
          child: Icon(icon, size: size * 0.48, color: foreground),
        ),
      ),
    );

    final shadowed = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FamRadius.input),
        boxShadow: bordered ? null : FamShadows.control,
      ),
      child: button,
    );

    return tooltip == null ? shadowed : Tooltip(message: tooltip!, child: shadowed);
  }
}

/// The primary call to action: navy gradient, 54 px high, rounded 16.
class FamPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;
  final bool dense;

  const FamPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 54,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(FamRadius.button),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(FamRadius.button),
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FamRadius.button),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: FamGradients.primary,
              ),
              boxShadow: enabled ? FamShadows.button : null,
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: FamColors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: dense ? 19 : 20, color: FamColors.white),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: FamFonts.body,
                            fontSize: dense ? 14 : 16,
                            fontWeight: FontWeight.w800,
                            color: FamColors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action: outline pill/rounded button.
class FamSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;
  final double height;
  final bool dense;
  final Color? borderColor;
  final Color? foregroundColor;

  const FamSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.filled = false,
    this.height = 54,
    this.dense = false,
    this.borderColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final tone = foregroundColor ??
        (filled ? FamColors.royalMid : FamColors.navy);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: filled ? FamColors.tint : FamColors.white,
        borderRadius: BorderRadius.circular(FamRadius.button),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(FamRadius.button),
          child: Container(
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FamRadius.button),
              border: filled
                  ? null
                  : Border.all(color: borderColor ?? FamColors.border, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: dense ? 18 : 19, color: tone),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: FamFonts.body,
                    fontSize: dense ? 13 : 15,
                    fontWeight: FontWeight.w800,
                    color: tone,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen title row: 26 px heading plus optional trailing icon controls.
class FamScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool large;

  const FamScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.large = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: FamFonts.body,
                  fontSize: large ? 26 : 22,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: FamColors.navy,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontFamily: FamFonts.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: FamColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                actions[i],
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// Segmented control with the navy active pill (Properties / Shops / Stock).
class FamSegmented extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  const FamSegmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: FamColors.tint,
        borderRadius: BorderRadius.circular(FamRadius.button),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? FamColors.navy : Colors.transparent,
                    borderRadius: BorderRadius.circular(FamRadius.sm),
                  ),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: FamFonts.body,
                      fontSize: 14,
                      fontWeight: i == selected ? FontWeight.w800 : FontWeight.w700,
                      color: i == selected ? FamColors.white : FamColors.royalMid,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontally scrolling filter pills.
class FamFilterPills extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  const FamFilterPills({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: i == selected ? FamColors.royal : FamColors.white,
                  borderRadius: BorderRadius.circular(FamRadius.pill),
                  border: Border.all(
                    color: i == selected ? FamColors.royal : FamColors.border,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontFamily: FamFonts.body,
                    fontSize: 13,
                    fontWeight: i == selected ? FontWeight.w800 : FontWeight.w700,
                    color: i == selected ? FamColors.white : FamColors.navy,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// White metric card used in the dashboard's 2×2 grid.
class FamStatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;
  final bool alert;

  const FamStatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
    this.alert = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = alert ? FamColors.danger : FamColors.royal;
    final accentBg = alert ? FamColors.dangerBg : FamColors.tint;
    return Material(
      color: FamColors.white,
      borderRadius: BorderRadius.circular(FamRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FamRadius.card),
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FamRadius.card),
            boxShadow: FamShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 22, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: FamFonts.body,
                        fontSize: 22,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: alert ? FamColors.danger : FamColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient summary card with a label, a value and a progress bar.
class FamHeroCard extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final double? progress;
  final String? trailing;
  final VoidCallback? onTap;
  final double? height;

  const FamHeroCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.progress,
    this.trailing,
    this.onTap,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final content = FamGradientSurface(
      borderRadius: BorderRadius.circular(FamRadius.hero),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      gradientBegin: Alignment.topLeft,
      gradientEnd: Alignment.bottomRight,
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: FamFonts.body,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: famAlpha(FamColors.white, 0.82),
                    ),
                  ),
                ),
                if (trailing != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: famAlpha(FamColors.white, 0.16),
                      borderRadius: BorderRadius.circular(FamRadius.pill),
                    ),
                    child: Text(
                      trailing!,
                      style: const TextStyle(
                        fontFamily: FamFonts.body,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: FamColors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: FamFonts.body,
                fontSize: 32,
                height: 1.1,
                letterSpacing: -0.3,
                fontWeight: FontWeight.w800,
                color: FamColors.white,
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0).toDouble(),
                  minHeight: 8,
                  backgroundColor: famAlpha(FamColors.white, 0.18),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFFFFFF)),
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 6),
                Text(
                  caption!,
                  style: TextStyle(
                    fontFamily: FamFonts.body,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: famAlpha(FamColors.white, 0.82),
                  ),
                ),
              ],
            ] else if (caption != null) ...[
              const SizedBox(height: 6),
              Text(
                caption!,
                style: TextStyle(
                  fontFamily: FamFonts.body,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: famAlpha(FamColors.white, 0.82),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

/// Section heading with an optional trailing action.
class FamSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const FamSectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: FamFonts.body,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: FamColors.navy,
            ),
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontFamily: FamFonts.body,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: FamColors.royal,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Round initials avatar with a semantic tone.
class FamAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color background;
  final Color foreground;

  const FamAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.background = FamColors.tint,
    this.foreground = FamColors.royalMid,
  });

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(
        initials(name),
        style: TextStyle(
          fontFamily: FamFonts.body,
          fontSize: size * 0.33,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

/// Small status pill (Paid / Overdue / Pending / Residential …).
class FamBadge extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  const FamBadge({
    super.key,
    required this.label,
    this.foreground = FamColors.royalMid,
    this.background = FamColors.tint,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(FamRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: FamFonts.body,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin progress bar with optional label row.
class FamProgress extends StatelessWidget {
  final double value;
  final String? label;
  final String? trailing;
  final double height;

  const FamProgress({
    super.key,
    required this.value,
    this.label,
    this.trailing,
    this.height = 7,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || trailing != null) ...[
          Row(
            children: [
              if (label != null)
                Expanded(
                  child: Text(
                    label!,
                    style: const TextStyle(
                      fontFamily: FamFonts.body,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: FamColors.text,
                    ),
                  ),
                ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: const TextStyle(
                    fontFamily: FamFonts.body,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: FamColors.royalMid,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0).toDouble(),
            minHeight: height,
            backgroundColor: FamColors.tint,
            valueColor: const AlwaysStoppedAnimation(FamColors.royal),
          ),
        ),
      ],
    );
  }
}

/// Floating action used on list screens ("Add property").
class FamFab extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const FamFab({super.key, required this.label, this.icon = Icons.add, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(27),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(27),
        child: Ink(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: FamGradients.primary,
            ),
            boxShadow: FamShadows.button,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: FamColors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: FamFonts.body,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: FamColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Decorative full-bleed gradient header with rings, used by the auth screens.
class FamAuthHeader extends StatelessWidget {
  final double height;
  final Widget child;

  const FamAuthHeader({super.key, this.height = 300, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-0.4, -1),
                  end: Alignment(0.6, 1),
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
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Circular progress ring used in the splash screen.
class FamDots extends StatelessWidget {
  final int count;
  final int active;
  const FamDots({super.key, this.count = 3, this.active = 0});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: i == active ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active ? FamColors.white : famAlpha(FamColors.ice, 0.45),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ],
    );
  }
}

/// Small helper for the "Fam mark" watermark on empty states.
class FamEmptyIllustration extends StatelessWidget {
  final IconData icon;
  const FamEmptyIllustration({super.key, this.icon = Icons.inbox_rounded});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(color: FamColors.tint, shape: BoxShape.circle),
      child: Icon(icon, size: 28, color: FamColors.royal),
    );
  }
}
