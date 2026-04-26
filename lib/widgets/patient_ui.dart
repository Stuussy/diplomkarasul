import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/clinic_theme.dart';
import 'dent_card.dart';
import 'dent_badge.dart';

/// Palette aliases for patient-facing screens (backward compatible).
class PatientPalette {
  static const Color primary = ClinicTheme.azure;
  static const Color secondary = ClinicTheme.violet;
  static const Color accent = ClinicTheme.violet;
  static const Color success = ClinicTheme.mint;
  static const Color warning = ClinicTheme.amber;
  static const Color error = ClinicTheme.coral;
  static const Color surface = ClinicTheme.snow;
  static const Color background = ClinicTheme.mist;

  static const LinearGradient hero = ClinicTheme.heroGradient;

  static LinearGradient muted([double opacity = 0.08]) {
    return ClinicTheme.mutedGradient(opacity);
  }
}

/// Section title with optional action.
class PatientSectionTitle extends StatelessWidget {
  const PatientSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

/// Backward compatible badge (delegates to DentBadge).
class PatientBadge extends StatelessWidget {
  const PatientBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.variant = PatientBadgeVariant.info,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final PatientBadgeVariant variant;

  DentBadgeVariant _mapVariant() {
    switch (variant) {
      case PatientBadgeVariant.success:
        return DentBadgeVariant.success;
      case PatientBadgeVariant.warning:
        return DentBadgeVariant.warning;
      case PatientBadgeVariant.error:
        return DentBadgeVariant.error;
      case PatientBadgeVariant.info:
        return DentBadgeVariant.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DentBadge(
      label: label,
      icon: icon,
      color: color,
      variant: _mapVariant(),
    );
  }
}

enum PatientBadgeVariant { info, success, warning, error }

/// Empty state placeholder.
class PatientEmptyState extends StatelessWidget {
  const PatientEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = LucideIcons.inbox,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return DentCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: ClinicTheme.slate),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Quick stat tile for dashboards.
class PatientQuickStat extends StatelessWidget {
  const PatientQuickStat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? PatientPalette.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: resolvedColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
          ),
          child: Icon(icon, color: resolvedColor, size: 22),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        Text(
          label,
          style: TextStyle(color: ClinicTheme.slate, fontSize: 13),
        ),
      ],
    );
  }
}
