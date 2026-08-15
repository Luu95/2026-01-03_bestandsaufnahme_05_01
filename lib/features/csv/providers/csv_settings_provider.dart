/// Riverpod-Anbindung der CSV-Einstellungen (pro Projekt).
/// Domänenlogik liegt unter `lib/features/csv/`; hier nur State laden/speichern und Re-Export.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bestandsaufnahme_01/features/csv/csv.dart';

export 'package:bestandsaufnahme_01/features/csv/csv.dart';

/// Hält [CsvSettings] für ein Projekt und persistiert über SharedPreferences.
class CsvSettingsNotifier extends StateNotifier<CsvSettings> {
  final String projectId;

  CsvSettingsNotifier(this.projectId) : super(CsvSettings.defaults());

  /// Lädt Einstellungen (inkl. Legacy-Migration) – eine Quelle der Wahrheit.
  Future<void> load() async {
    state = await CsvSettings.loadForProject(projectId);
  }

  /// Speichert Einstellungen und aktualisiert den State.
  Future<void> save(CsvSettings settings) async {
    state = settings;
    await CsvSettings.saveForProject(projectId, settings);
  }

  /// Entfernt gespeicherte Anlagen-CSV-Import-Struktur (Header, Attribut-Spalten).
  Future<void> clearAnlagenCsvImportStructure() async {
    await save(
      state.copyWith(
        importHeaderRow: const [],
        attributeColumnPairs: const [],
        attributeTripletColumns: const [],
      ),
    );
  }

  /// Persistiert die Import-Headerzeile.
  Future<void> saveImportHeaderRow(List<String> headerRow) async {
    await save(state.copyWith(importHeaderRow: headerRow));
  }
}

/// Family-Provider: CSV-Einstellungen je [projectId].
final csvSettingsProvider =
    StateNotifierProviderFamily<CsvSettingsNotifier, CsvSettings, String>(
  (ref, projectId) => CsvSettingsNotifier(projectId),
);
