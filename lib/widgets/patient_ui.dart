import 'package:flutter/material.dart';

import '../theme/clinic_theme.dart';
import 'clinic_card.dart';

class PatientPalette {
  static const Color primary = ClinicTheme.sage;
  static const Color secondary = Color(0xFF8EAB9F);
  static const Color accent = ClinicTheme.info;
  static const Color success = ClinicTheme.success;
  static const Color warning = ClinicTheme.warning;
  static const Color error = ClinicTheme.error;
  static const Color surface = ClinicTheme.porcelain;
  static const Color background = ClinicTheme.ivory;

  static const LinearGradient hero = LinearGradient(
    colors: [ClinicTheme.sage, Color(0xFF6B8C7E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient muted([double opacity = 0.08]) {
    return LinearGradient(
      colors: [
        ClinicTheme.sage.withValues(alpha: opacity + 0.04),
        ClinicTheme.info.withValues(alpha: opacity),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

class PatientCard extends StatelessWidget {
  const PatientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.onTap,
    this.gradient,
    this.color = PatientPalette.surface,
    this.borderRadius = ClinicTheme.radiusM,
    this.elevation = 10,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color color;
  final double borderRadius;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final boxShadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: elevation,
        offset: const Offset(0, 4),
      ),
    ];
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: gradient,
        color: gradient == null ? color : null,
        boxShadow: boxShadow,
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

  Color _resolveColor() {
    switch (variant) {
      case PatientBadgeVariant.success:
        return PatientPalette.success;
      case PatientBadgeVariant.warning:
        return PatientPalette.warning;
      case PatientBadgeVariant.error:
        return PatientPalette.error;
      case PatientBadgeVariant.info:
        return PatientPalette.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? _resolveColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ClinicTheme.radiusL),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: resolved),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: resolved,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

enum PatientBadgeVariant { info, success, warning, error }

class PatientEmptyState extends StatelessWidget {
  const PatientEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ClinicCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Colors.black45),
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
        CircleAvatar(
          radius: 22,
          backgroundColor: resolvedColor.withValues(alpha: 0.12),
          child: Icon(icon, color: resolvedColor),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        Text(label, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}
