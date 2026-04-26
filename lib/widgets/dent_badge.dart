import 'package:flutter/material.dart';

import '../theme/clinic_theme.dart';

enum DentBadgeVariant { info, success, warning, error, neutral }

/// Pill-shaped semantic badge.
class DentBadge extends StatelessWidget {
  const DentBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.variant = DentBadgeVariant.info,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final DentBadgeVariant variant;

  Color _bg(Color c) => c.withValues(alpha: 0.1);

  Color _resolveColor() {
    switch (variant) {
      case DentBadgeVariant.success:
        return ClinicTheme.mint;
      case DentBadgeVariant.warning:
        return ClinicTheme.amber;
      case DentBadgeVariant.error:
        return ClinicTheme.coral;
      case DentBadgeVariant.info:
        return ClinicTheme.azure;
      case DentBadgeVariant.neutral:
        return ClinicTheme.slate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? _resolveColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _bg(resolved),
        borderRadius: BorderRadius.circular(ClinicTheme.radiusL),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: resolved),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: resolved,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
          ),
        ],
      ),
    );
  }
}
