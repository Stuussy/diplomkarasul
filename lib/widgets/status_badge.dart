import 'package:flutter/material.dart';

import '../theme/clinic_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(ClinicTheme.radiusL),
      ),
      child: Text(
        _label(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }

  Color _color() {
    switch (status) {
      case 'confirmed':
        return ClinicTheme.success;
      case 'completed':
        return ClinicTheme.info;
      case 'cancelled':
        return ClinicTheme.error;
      case 'scheduled':
      default:
        return ClinicTheme.warning;
    }
  }

  String _label() {
    switch (status) {
      case 'confirmed':
        return 'Подтверждено';
      case 'completed':
        return 'Завершено';
      case 'cancelled':
        return 'Отменено';
      case 'scheduled':
      default:
        return 'Ожидает';
    }
  }
}
