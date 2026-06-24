import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, setswana }

class LanguageProvider extends ChangeNotifier {
  AppLanguage _lang = AppLanguage.english;
  AppLanguage get language => _lang;
  bool get isSetswana => _lang == AppLanguage.setswana;

  LanguageProvider() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('language') ?? 'english';
    _lang = stored == 'setswana'
        ? AppLanguage.setswana
        : AppLanguage.english;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage lang) async {
    _lang = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language',
        lang == AppLanguage.setswana ? 'setswana' : 'english');
    notifyListeners();
  }
}
