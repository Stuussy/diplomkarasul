import 'package:flutter/material.dart';

class PatientPalette {
  static const Color primary = Color(0xFF2563EB);
  static const Color secondary = Color(0xFF60A5FA);
  static const Color accent = Color(0xFF0EA5E9);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color surface = Colors.white;
  static const Color background = Color(0xFFF4F6FB);

  static const LinearGradient hero = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient muted([double opacity = 0.08]) {
    return LinearGradient(
      colors: [
        const Color(0xFF2563EB).withValues(alpha: opacity + 0.04),
        const Color(0xFF0EA5E9).withValues(alpha: opacity),
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
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.onTap,
    this.gradient,
    this.color = PatientPalette.surface,
    this.borderRadius = 24,
    this.elevation = 12,
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
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: elevation,
        offset: const Offset(0, 10),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                ),
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
        borderRadius: BorderRadius.circular(20),
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
            style: TextStyle(color: resolved, fontWeight: FontWeight.w600),
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
    return PatientCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Colors.black45),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
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
