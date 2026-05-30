import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/backup_interval.dart';

class AppSettings {
  final bool showValidationProgress;
  final bool autoBackupEnabled;
  final BackupInterval autoBackupInterval;
  final String? autoBackupPath;
  final String? autoBackupStorageUri;
  final DateTime? lastAutoBackupAt;
  final ThemeMode themeMode;

  const AppSettings({
    this.showValidationProgress = true,
    this.autoBackupEnabled = false,
    this.autoBackupInterval = BackupInterval.daily,
    this.autoBackupPath,
    this.autoBackupStorageUri,
    this.lastAutoBackupAt,
    this.themeMode = ThemeMode.light,
  });

  bool get hasBackupLocation =>
      (autoBackupStorageUri != null && autoBackupStorageUri!.isNotEmpty) ||
      (autoBackupPath != null && autoBackupPath!.isNotEmpty);

  bool get isBackupDue {
    if (!autoBackupEnabled || !hasBackupLocation) {
      return false;
    }
    if (lastAutoBackupAt == null) return true;
    return DateTime.now().difference(lastAutoBackupAt!) >= autoBackupInterval.duration;
  }

  AppSettings copyWith({
    bool? showValidationProgress,
    bool? autoBackupEnabled,
    BackupInterval? autoBackupInterval,
    String? autoBackupPath,
    String? autoBackupStorageUri,
    DateTime? lastAutoBackupAt,
    ThemeMode? themeMode,
    bool clearAutoBackupPath = false,
    bool clearAutoBackupStorageUri = false,
    bool clearLastAutoBackupAt = false,
  }) {
    return AppSettings(
      showValidationProgress: showValidationProgress ?? this.showValidationProgress,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      autoBackupInterval: autoBackupInterval ?? this.autoBackupInterval,
      autoBackupPath: clearAutoBackupPath ? null : (autoBackupPath ?? this.autoBackupPath),
      autoBackupStorageUri:
          clearAutoBackupStorageUri ? null : (autoBackupStorageUri ?? this.autoBackupStorageUri),
      lastAutoBackupAt:
          clearLastAutoBackupAt ? null : (lastAutoBackupAt ?? this.lastAutoBackupAt),
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  static const _keyShowValidationProgress = 'settings_show_validation_progress';
  static const _keyAutoBackupEnabled = 'settings_auto_backup_enabled';
  static const _keyAutoBackupInterval = 'settings_auto_backup_interval';
  static const _keyAutoBackupPath = 'settings_auto_backup_path';
  static const _keyAutoBackupStorageUri = 'settings_auto_backup_storage_uri';
  static const _keyLastAutoBackupAt = 'settings_last_auto_backup_at';
  static const _keyThemeMode = 'settings_theme_mode';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackupRaw = prefs.getString(_keyLastAutoBackupAt);
    state = AppSettings(
      showValidationProgress: prefs.getBool(_keyShowValidationProgress) ?? true,
      autoBackupEnabled: prefs.getBool(_keyAutoBackupEnabled) ?? false,
      autoBackupInterval: BackupInterval.fromKey(prefs.getString(_keyAutoBackupInterval)),
      autoBackupPath: prefs.getString(_keyAutoBackupPath),
      autoBackupStorageUri: prefs.getString(_keyAutoBackupStorageUri),
      lastAutoBackupAt: lastBackupRaw != null ? DateTime.tryParse(lastBackupRaw) : null,
      themeMode: _themeModeFromKey(prefs.getString(_keyThemeMode)),
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

  Future<void> setAutoBackupEnabled(bool value) async {
    state = state.copyWith(autoBackupEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoBackupEnabled, value);
  }

  Future<void> setAutoBackupInterval(BackupInterval interval) async {
    state = state.copyWith(autoBackupInterval: interval);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAutoBackupInterval, interval.name);
  }

  Future<void> setAutoBackupPath(String? path) async {
    if (path == null || path.isEmpty) {
      state = state.copyWith(clearAutoBackupPath: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAutoBackupPath);
      return;
    }
    state = state.copyWith(autoBackupPath: path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAutoBackupPath, path);
  }

  Future<void> setAutoBackupStorageUri(String? uri) async {
    if (uri == null || uri.isEmpty) {
      state = state.copyWith(clearAutoBackupStorageUri: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAutoBackupStorageUri);
      return;
    }
    state = state.copyWith(autoBackupStorageUri: uri);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAutoBackupStorageUri, uri);
  }

  Future<void> setAutoBackupLocation({
    required String displayPath,
    String? storageUri,
    String? filePath,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    state = state.copyWith(
      autoBackupPath: displayPath,
      autoBackupStorageUri: storageUri,
      clearAutoBackupStorageUri: storageUri == null || storageUri.isEmpty,
    );

    await prefs.setString(_keyAutoBackupPath, displayPath);
    if (storageUri != null && storageUri.isNotEmpty) {
      await prefs.setString(_keyAutoBackupStorageUri, storageUri);
    } else {
      await prefs.remove(_keyAutoBackupStorageUri);
    }

    // Für Desktop: filePath ist identisch mit displayPath und wird in autoBackupPath gespeichert.
    if (filePath != null && filePath.isNotEmpty && filePath != displayPath) {
      await prefs.setString(_keyAutoBackupPath, filePath);
      state = state.copyWith(autoBackupPath: filePath);
    }
  }

  Future<void> setLastAutoBackupAt(DateTime value) async {
    state = state.copyWith(lastAutoBackupAt: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastAutoBackupAt, value.toIso8601String());
  }

  Future<void> setThemeMode(ThemeMode value) async {
    state = state.copyWith(themeMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, _themeModeToKey(value));
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
