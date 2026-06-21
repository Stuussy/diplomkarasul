import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../providers/locale_provider.dart';
import '../theme/clinic_theme.dart';

/// Описание одного языка для пикера.
class _LangOption {
  const _LangOption(this.code, this.flag, this.native);
  final String code;
  final String flag;
  final String native;
}

const _langOptions = <_LangOption>[
  _LangOption('ru', '🇷🇺', 'Русский'),
  _LangOption('kk', '🇰🇿', 'Қазақша'),
  _LangOption('en', '🇬🇧', 'English'),
];

/// Текущий язык в виде короткого кода (РУС / ҚАЗ / ENG).
String _shortCode(String code) {
  switch (code) {
    case 'kk':
      return 'ҚАЗ';
    case 'en':
      return 'ENG';
    default:
      return 'РУС';
  }
}

String _flagFor(String code) =>
    _langOptions.firstWhere((o) => o.code == code, orElse: () => _langOptions.first).flag;

/// Открывает красивую нижнюю панель выбора языка.
Future<void> showLanguagePicker(BuildContext context) async {
  final provider = context.read<LocaleProvider>();
  final s = context.sRead;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Container(
        decoration: const BoxDecoration(
          color: ClinicTheme.snow,
          borderRadius: BorderRadius.vertical(top: Radius.circular(ClinicTheme.radiusXL)),
        ),
        padding: EdgeInsets.only(
          top: 12,
          bottom: 12 + MediaQuery.of(sheetContext).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grabber
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ClinicTheme.mist,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.globe, size: 20, color: ClinicTheme.azure),
                const SizedBox(width: 8),
                Text(
                  s.languageTitle,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._langOptions.map((opt) {
              final selected = provider.code == opt.code;
              return ListTile(
                onTap: () {
                  HapticFeedback.selectionClick();
                  provider.setLocale(Locale(opt.code));
                  Navigator.of(sheetContext).pop();
                },
                leading: Text(opt.flag, style: const TextStyle(fontSize: 26)),
                title: Text(
                  opt.native,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: ClinicTheme.midnight,
                  ),
                ),
                trailing: selected
                    ? const Icon(LucideIcons.checkCircle, color: ClinicTheme.azure)
                    : const Icon(LucideIcons.circle, color: ClinicTheme.mist),
              );
            }),
            const SizedBox(height: 4),
          ],
        ),
      );
    },
  );
}

/// Компактная «таблетка» с глобусом и текущим языком.
/// Тап открывает [showLanguagePicker]. Используется на логине и в профиле.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key, this.onDark = false});

  /// Светлые цвета для тёмного фона.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final code = context.watch<LocaleProvider>().code;

    final bg = onDark
        ? Colors.white.withValues(alpha: 0.12)
        : ClinicTheme.azure.withValues(alpha: 0.08);
    final border = onDark
        ? Colors.white.withValues(alpha: 0.25)
        : ClinicTheme.azure.withValues(alpha: 0.2);
    final fg = onDark ? Colors.white : ClinicTheme.azure;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showLanguagePicker(context);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_flagFor(code), style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              _shortCode(code),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: fg,
              ),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronDown, size: 14, color: fg),
          ],
        ),
      ),
    );
  }
}
