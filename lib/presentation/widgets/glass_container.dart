import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Border? border;
  final Color? color;
  final bool showGlow;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 12.0,
    this.opacity = 0.08,
    this.borderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.border,
    this.color,
    this.showGlow = false,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final defaultRadius = BorderRadius.circular(18);
    final effectiveBorderRadius = borderRadius ?? defaultRadius;

    return Container(
      margin: margin,
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: effectiveBorderRadius,
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: (color ?? AppTheme.primaryColor).withOpacity(0.15),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null
                  ? (color ?? Colors.white.withOpacity(opacity))
                  : null,
              borderRadius: effectiveBorderRadius,
              border: border ??
                  Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? bgColor;
  final Gradient? gradient;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Border? border;
  final List<BoxShadow>? shadows;

  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.bgColor,
    this.gradient,
    this.borderRadius,
    this.onTap,
    this.border,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(20));
    const effectiveBorder = Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0), width: 1));
    const defaultBg = Colors.white;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: margin,
        padding: padding ?? const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bgColor ?? defaultBg,
          gradient: gradient,
          borderRadius: borderRadius ?? radius,
          border: border ?? effectiveBorder,
          boxShadow: shadows,
        ),
        child: child,
      ),
    );
  }
}

class StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const StatBadge({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor = AppTheme.primaryColor,
    this.bgColor = AppTheme.primaryColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const textPrimary = Color(0xFF0F172A);
    const textSecondary = Color(0xFF64748B);

    return GestureDetector(
      onTap: onTap,
      child: ModernCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
