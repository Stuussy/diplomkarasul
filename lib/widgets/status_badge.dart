import 'package:flutter/material.dart';

import '../theme/clinic_theme.dart';
import 'dent_badge.dart';

/// Unified status badge that maps appointment status to semantic colors.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, variant) = _resolve(status);
    return DentBadge(label: label, variant: variant);
  }

  (String, DentBadgeVariant) _resolve(String status) {
    switch (status) {
      case 'scheduled':
        return ('Запланирован', DentBadgeVariant.info);
      case 'confirmed':
        return ('Подтверждён', DentBadgeVariant.success);
      case 'completed':
        return ('Завершён', DentBadgeVariant.neutral);
      case 'cancelled':
        return ('Отменён', DentBadgeVariant.error);
      default:
        return (status, DentBadgeVariant.neutral);
    }
  }
}
