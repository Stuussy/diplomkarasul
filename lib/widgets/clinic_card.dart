import 'package:flutter/material.dart';

import '../theme/clinic_theme.dart';

class ClinicCard extends StatelessWidget {
  const ClinicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.background,
    this.gradient,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? background;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (background ?? ClinicTheme.porcelain) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(ClinicTheme.radiusM),
        border: Border.all(color: ClinicTheme.line, width: 0.6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    return Container(
      margin: margin,
      child: onTap == null
          ? card
          : InkWell(
              borderRadius: BorderRadius.circular(ClinicTheme.radiusM),
              onTap: onTap,
              child: card,
            ),
    );
  }
}
