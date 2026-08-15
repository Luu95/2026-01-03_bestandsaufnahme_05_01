/// App-Einstellungen (Theme, OCR-Beta, Listen-Highlight) via SharedPreferences.
/// Riverpod-[SettingsNotifier] hält den aktuellen [AppSettings]-State.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistierbare App-Einstellungen für Theme und Feature-Flags.
class AppSettings {
  final ThemeMode themeMode;
  final bool typenschildOcrEnabled;
  /// Visuelle Markierung der zuletzt geöffneten Anlage in der Liste.
  final bool highlightLastOpenedAnlage;

  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.typenschildOcrEnabled = false,
    this.highlightLastOpenedAnlage = true,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? typenschildOcrEnabled,
    bool? highlightLastOpenedAnlage,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      typenschildOcrEnabled: typenschildOcrEnabled ?? this.typenschildOcrEnabled,
      highlightLastOpenedAnlage:
          highlightLastOpenedAnlage ?? this.highlightLastOpenedAnlage,
    );
  }
}

/// Lädt und speichert [AppSettings] in SharedPreferences.
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  static const _keyThemeMode = 'settings_theme_mode';
  static const _keyTypenschildOcrEnabled = 'settings_typenschild_ocr_beta';
  static const _keyHighlightLastOpenedAnlage =
      'settings_highlight_last_opened_anlage';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      themeMode: _themeModeFromKey(prefs.getString(_keyThemeMode)),
      typenschildOcrEnabled: prefs.getBool(_keyTypenschildOcrEnabled) ?? false,
      highlightLastOpenedAnlage:
          prefs.getBool(_keyHighlightLastOpenedAnlage) ?? true,
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

  /// Setzt und persistiert den [ThemeMode].
  Future<void> setThemeMode(ThemeMode value) async {
    state = state.copyWith(themeMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, _themeModeToKey(value));
  }

  /// Schaltet die Typenschild-OCR-Beta ein/aus.
  Future<void> setTypenschildOcrEnabled(bool value) async {
    state = state.copyWith(typenschildOcrEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTypenschildOcrEnabled, value);
  }

  /// Schaltet die Hervorhebung der zuletzt geöffneten Anlage.
  Future<void> setHighlightLastOpenedAnlage(bool value) async {
    state = state.copyWith(highlightLastOpenedAnlage: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHighlightLastOpenedAnlage, value);
  }
}

/// Globaler Provider für [AppSettings].
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
