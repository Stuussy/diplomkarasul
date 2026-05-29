import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';
import '../theme/clinic_theme.dart';

/// A segmented РУС / ҚАЗ language switch.
///
/// Two pill segments side by side; the active language is highlighted.
/// Tapping a segment switches the app locale via [LocaleProvider].
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key, this.onDark = false});

  /// When true, uses light colors suitable for a dark background.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final isKk = localeProvider.isKazakh;

    final bg = onDark
        ? Colors.white.withValues(alpha: 0.12)
        : ClinicTheme.azure.withValues(alpha: 0.08);
    final border = onDark
        ? Colors.white.withValues(alpha: 0.25)
        : ClinicTheme.azure.withValues(alpha: 0.2);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            label: 'РУС',
            active: !isKk,
            onTap: () {
              if (isKk) {
                HapticFeedback.selectionClick();
                localeProvider.setLocale(const Locale('ru'));
              }
            },
          ),
          _segment(
            label: 'ҚАЗ',
            active: isKk,
            onTap: () {
              if (!isKk) {
                HapticFeedback.selectionClick();
                localeProvider.setLocale(const Locale('kk'));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? ClinicTheme.azure : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: active
                ? Colors.white
                : (onDark ? Colors.white70 : ClinicTheme.slate),
          ),
        ),
      ),
    );
  }
}
