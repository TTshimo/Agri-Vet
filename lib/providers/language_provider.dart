import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One language the app can show diagnosis content in.
/// The list lives in assets/i18n/languages.json so adding a language needs
/// no code change: add it there and let scripts/translate.py generate it.
class AppLanguage {
  final String code;
  final String name;
  final String nativeName;

  const AppLanguage(this.code, this.name, this.nativeName);

  static const english = AppLanguage('en', 'English', 'English');

  factory AppLanguage.fromJson(Map<String, dynamic> json) => AppLanguage(
        json['code'] as String,
        json['name'] as String,
        (json['native'] as String?) ?? json['name'] as String,
      );

  /// Label shown in Settings, e.g. "Kiswahili (Swahili)".
  String get label => nativeName == name ? name : '$nativeName ($name)';
}

/// The single source of truth for the user's language.
///
/// English strings come from assets/i18n/en.json (UI) and the knowledge base
/// (disease content). Every other language comes from the machine-translated
/// assets/i18n/<code>.json. Missing keys fall back to English, so a language
/// that hasn't been translated yet still works.
class LanguageProvider extends ChangeNotifier {
  static const _prefsKey = 'language';

  List<AppLanguage> _languages = const [AppLanguage.english];
  AppLanguage _language = AppLanguage.english;
  Map<String, String> _english = const {};
  Map<String, String> _strings = const {};

  List<AppLanguage> get languages => _languages;
  AppLanguage get language => _language;
  String get code => _language.code;

  LanguageProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/i18n/languages.json');
      _languages = (json.decode(raw) as List)
          .map((e) => AppLanguage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('LanguageProvider: could not read languages.json: $e');
    }
    _english = await _readStrings('en');

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    // Older builds stored 'english' / 'setswana'.
    final savedCode = saved == 'setswana'
        ? 'tn'
        : (saved == null || saved == 'english')
            ? 'en'
            : saved;
    await _apply(savedCode);
  }

  Future<void> setLanguage(String code) async {
    await _apply(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _language.code);
  }

  Future<void> _apply(String code) async {
    _language = _languages.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLanguage.english,
    );
    _strings = _language.code == 'en' ? const {} : await _readStrings(_language.code);
    notifyListeners();
  }

  Future<Map<String, String>> _readStrings(String code) async {
    try {
      final raw = await rootBundle.loadString('assets/i18n/$code.json');
      final map = json.decode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries)
          if (!e.key.startsWith('_')) e.key: e.value.toString(),
      };
    } catch (_) {
      // Not translated yet: everything falls back to English.
      return const {};
    }
  }

  /// Translate [key]. [fallback] is the English text to use when no
  /// translation exists (used for knowledge-base content, whose English
  /// lives in the knowledge base rather than en.json).
  /// `{name}` placeholders are filled from [args].
  String t(String key, {String? fallback, Map<String, Object>? args}) {
    var text = _strings[key] ?? _english[key] ?? fallback ?? key;
    args?.forEach((name, value) => text = text.replaceAll('{$name}', '$value'));
    return text;
  }
}
