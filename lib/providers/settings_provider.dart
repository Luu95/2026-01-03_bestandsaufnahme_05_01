import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final bool showValidationProgress;
  final ThemeMode themeMode;
  final bool typenschildOcrEnabled;

  const AppSettings({
    this.showValidationProgress = true,
    this.themeMode = ThemeMode.light,
    this.typenschildOcrEnabled = false,
  });

  AppSettings copyWith({
    bool? showValidationProgress,
    ThemeMode? themeMode,
    bool? typenschildOcrEnabled,
  }) {
    return AppSettings(
      showValidationProgress: showValidationProgress ?? this.showValidationProgress,
      themeMode: themeMode ?? this.themeMode,
      typenschildOcrEnabled: typenschildOcrEnabled ?? this.typenschildOcrEnabled,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  static const _keyShowValidationProgress = 'settings_show_validation_progress';
  static const _keyThemeMode = 'settings_theme_mode';
  static const _keyTypenschildOcrEnabled = 'settings_typenschild_ocr_beta';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      showValidationProgress: prefs.getBool(_keyShowValidationProgress) ?? true,
      themeMode: _themeModeFromKey(prefs.getString(_keyThemeMode)),
      typenschildOcrEnabled: prefs.getBool(_keyTypenschildOcrEnabled) ?? false,
    );
  }

  static ThemeMode _themeModeFromKey(String? key) {
    switch (key) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  static String _themeModeToKey(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
    }
  }

  Future<void> setShowValidationProgress(bool value) async {
    state = state.copyWith(showValidationProgress: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowValidationProgress, value);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    state = state.copyWith(themeMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, _themeModeToKey(value));
  }

  Future<void> setTypenschildOcrEnabled(bool value) async {
    state = state.copyWith(typenschildOcrEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTypenschildOcrEnabled, value);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
