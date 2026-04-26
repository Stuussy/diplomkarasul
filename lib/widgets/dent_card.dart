import 'package:flutter/material.dart';

import '../theme/clinic_theme.dart';

/// Premium card with multi-layer shadow and optional gradient.
class DentCard extends StatelessWidget {
  const DentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.onTap,
    this.gradient,
    this.color,
    this.shadow,
    this.borderRadius = ClinicTheme.radiusM,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? color;
  final List<BoxShadow>? shadow;
  final double borderRadius;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: gradient,
        color: gradient == null ? (color ?? ClinicTheme.snow) : null,
        boxShadow: shadow ?? ClinicTheme.shadowSm,
        border: border,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
