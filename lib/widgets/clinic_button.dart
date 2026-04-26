import 'package:flutter/material.dart';

import '../theme/clinic_theme.dart';

class ClinicButton extends StatelessWidget {
  const ClinicButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  })  : _variant = _ClinicButtonVariant.primary,
        icon = null;

  const ClinicButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  })  : _variant = _ClinicButtonVariant.secondary,
        icon = null;

  const ClinicButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
  })  : _variant = _ClinicButtonVariant.ghost,
        isLoading = false,
        icon = null;

  const ClinicButton.icon({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
  }) : _variant = _ClinicButtonVariant.primary;

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final _ClinicButtonVariant _variant;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    switch (_variant) {
      case _ClinicButtonVariant.primary:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            child: child,
          ),
        );
      case _ClinicButtonVariant.secondary:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            child: child,
          ),
        );
      case _ClinicButtonVariant.ghost:
        return TextButton(
          onPressed: onPressed,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: ClinicTheme.slate),
          ),
        );
    }
  }
}

enum _ClinicButtonVariant { primary, secondary, ghost }
