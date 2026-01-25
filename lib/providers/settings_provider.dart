import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UISettings {
  final String titleKey;
  final String subtitleKey;

  UISettings({
    required this.titleKey,
    required this.subtitleKey,
  });

  UISettings copyWith({
    String? titleKey,
    String? subtitleKey,
  }) {
    return UISettings(
      titleKey: titleKey ?? this.titleKey,
      subtitleKey: subtitleKey ?? this.subtitleKey,
    );
  }
}

class UISettingsNotifier extends StateNotifier<UISettings> {
  UISettingsNotifier() : super(UISettings(titleKey: 'Bezeichnung', subtitleKey: 'Hersteller')) {
    _loadSettings();
  }

  static const _keyTitle = 'ui_settings_title_key';
  static const _keySubtitle = 'ui_settings_subtitle_key';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString(_keyTitle) ?? 'Bezeichnung';
    final subtitle = prefs.getString(_keySubtitle) ?? 'Hersteller';
    state = UISettings(titleKey: title, subtitleKey: subtitle);
  }

  Future<void> setTitleKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTitle, key);
    state = state.copyWith(titleKey: key);
  }

  Future<void> setSubtitleKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySubtitle, key);
    state = state.copyWith(subtitleKey: key);
  }
}

final uiSettingsProvider = StateNotifierProvider<UISettingsNotifier, UISettings>((ref) {
  return UISettingsNotifier();
});

