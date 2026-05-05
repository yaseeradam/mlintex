import 'package:flutter/material.dart';

class GlassButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  const GlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.padding,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: child,
          ),
        ),
      ),
    );
  }
}
