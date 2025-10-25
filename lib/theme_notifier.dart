import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// NEW: Enum to represent the available theme colors.
enum AppThemeColor {
  red,
  deepPurple,
  blue,
  teal,
  orange,
  green,
  indigo,
}

// NEW: Extension to get the actual Color from the enum.
extension AppThemeColorExtension on AppThemeColor {
  Color get seedColor {
    switch (this) {
      case AppThemeColor.red:
        return const Color(0xFFF44336);
      case AppThemeColor.deepPurple:
        return Colors.deepPurple;
      case AppThemeColor.blue:
        return Colors.blue;
      case AppThemeColor.teal:
        return Colors.teal;
      case AppThemeColor.orange:
        return Colors.orange;
      case AppThemeColor.green:
        return Colors.green;
      case AppThemeColor.indigo:
        return Colors.indigo;
    }
  }
}

class ThemeNotifier extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _themeColorKey = 'theme_color';
  SharedPreferences? _prefs;
  late ThemeMode _themeMode;
  late AppThemeColor _appThemeColor;

  // Provide stable ThemeData instances to avoid rebuild flashes
  ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
        seedColor: _appThemeColor.seedColor, brightness: Brightness.light);
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      // FIX: Set the backgroundColor instead of using flexibleSpace, which is not a valid AppBarTheme property.
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
      ),
    );
  }

  ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
        seedColor: _appThemeColor.seedColor, brightness: Brightness.dark);
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      // FIX: Set the backgroundColor for the dark theme as well.
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
      ),
    );
  }

  ThemeMode get themeMode => _themeMode;
  AppThemeColor get appThemeColor => _appThemeColor;

  ThemeNotifier() {
    // Set a default theme and load the saved preference
    _themeMode = ThemeMode.system;
    _appThemeColor = AppThemeColor.red; // Default color
    _loadFromPrefs();
  }

  // Switch between themes
  void setThemeMode(ThemeMode theme) {
    _themeMode = theme;
    _saveThemeModeToPrefs();
    notifyListeners(); // Notify widgets to rebuild
  }

  // NEW: Change the theme color
  void setThemeColor(AppThemeColor color) {
    _appThemeColor = color;
    _saveThemeColorToPrefs();
    notifyListeners();
  }

  // Initialize SharedPreferences
  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Load the saved theme preferences
  Future<void> _loadFromPrefs() async {
    await _initPrefs();
    final int themeModeIndex = _prefs!.getInt(_themeModeKey) ?? ThemeMode.system.index;
    final int themeColorIndex = _prefs!.getInt(_themeColorKey) ?? AppThemeColor.red.index;
    _themeMode = ThemeMode.values[themeModeIndex];
    _appThemeColor = AppThemeColor.values[themeColorIndex];
    notifyListeners();
  }

  // Save the current theme preferences
  Future<void> _saveThemeModeToPrefs() async {
    await _initPrefs();
    _prefs!.setInt(_themeModeKey, _themeMode.index);
  }

  Future<void> _saveThemeColorToPrefs() async {
    await _initPrefs();
    _prefs!.setInt(_themeColorKey, _appThemeColor.index);
  }
}
