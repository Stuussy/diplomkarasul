import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const _key = 'app_locale';

  /// Поддерживаемые языки приложения.
  static const supported = <Locale>[
    Locale('ru'),
    Locale('kk'),
    Locale('en'),
  ];

  Locale _locale = const Locale('ru');

  Locale get locale => _locale;
  String get code => _locale.languageCode;
  bool get isKazakh => _locale.languageCode == 'kk';
  bool get isEnglish => _locale.languageCode == 'en';

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key) ?? 'ru';
    final code = supported.any((l) => l.languageCode == saved) ? saved : 'ru';
    _locale = Locale(code);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }

  /// Переключение по кругу ru → kk → en → ru (для простого toggle, если нужно).
  Future<void> toggle() async {
    final idx = supported.indexWhere((l) => l.languageCode == code);
    final next = supported[(idx + 1) % supported.length];
    await setLocale(next);
  }
}
