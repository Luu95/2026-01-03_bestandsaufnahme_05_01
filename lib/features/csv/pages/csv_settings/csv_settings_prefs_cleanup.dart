// Prefs-Aufräumen nach Hard-Delete eines Gebäudes (UI-State, Legacy-Keys).

import 'package:shared_preferences/shared_preferences.dart';

import 'package:bestandsaufnahme_01/core/logging/app_log.dart';

/// Entfernt gebäudebezogene SharedPreferences nach Datenlöschung.
Future<void> clearBuildingCsvUiPrefs(String buildingId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('disciplines_initialized_$buildingId');

  final prefix = 'expanded_groups_${buildingId}_';
  for (final key in prefs.getKeys().where((k) => k.startsWith(prefix))) {
    await prefs.remove(key);
  }

  // Legacy: Disziplinen lagen früher in Prefs statt in der DB.
  await prefs.remove('disziplinen_$buildingId');
  appLog('CSV-UI-Prefs für Gebäude $buildingId bereinigt');
}
