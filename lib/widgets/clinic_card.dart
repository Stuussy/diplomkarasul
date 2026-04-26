import 'package:flutter/material.dart';

import '../theme/clinic_theme.dart';
import 'dent_card.dart';

/// Backward compatible ClinicCard → delegates to DentCard.
class ClinicCard extends StatelessWidget {
  const ClinicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.onTap,
    this.gradient,
    this.background,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return DentCard(
      padding: padding,
      margin: margin,
      onTap: onTap,
      gradient: gradient,
      color: background ?? ClinicTheme.snow,
      child: child,
    );
  }
}
