import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/clinic_theme.dart';

/// Frosted glass container for premium overlays.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = ClinicTheme.radiusL,
    this.sigmaX = 24,
    this.sigmaY = 24,
    this.opacity = 0.12,
    this.borderOpacity = 0.2,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double sigmaX;
  final double sigmaY;
  final double opacity;
  final double borderOpacity;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
