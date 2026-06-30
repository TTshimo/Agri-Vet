import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;

  ThemeProvider() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool('isDark') ?? false;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', _isDark);
    notifyListeners();
  }
}

// App-wide color tokens
class AppTheme {
  static ThemeData light() => _build(false);
  static ThemeData dark()  => _build(true);

  static ThemeData _build(bool dark) {
    const seed = Color(0xFF2E7D32); // greenDark
    final scheme = dark
        ? const ColorScheme.dark(primary: seed, secondary: Color(0xFFFFA000))
        : const ColorScheme.light(primary: seed, secondary: Color(0xFFFFA000));
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7F5),
      cardColor: dark ? const Color(0xFF1E1E1E) : Colors.white,
      dividerColor: dark
          ? const Color(0xFF2C2C2C)
          : const Color(0xFFE0E0E0),
    );
  }
}
