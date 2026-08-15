/// CSV-Import und -Export für die Gebäude-Hauptseite.
///
/// Früher inline in `building_details_page.dart` (Abschnitt 2). Als Mixin,
/// weil Import/Export stark auf `context`, `mounted`, `ref` und Gebäude-State
/// zugreifen. Die Page stellt Werte über Getter bereit.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:bestandsaufnahme_01/features/projects/models/building.dart';
import 'package:bestandsaufnahme_01/features/systems/models/disziplin_schnittstelle.dart';
import 'package:bestandsaufnahme_01/features/projects/models/project.dart';
import 'package:bestandsaufnahme_01/features/csv/providers/csv_settings_provider.dart';
import 'package:bestandsaufnahme_01/features/projects/providers/database_provider.dart';
import 'package:bestandsaufnahme_01/features/csv/services/anlagen_csv_import_service.dart';
import 'package:bestandsaufnahme_01/features/csv/services/csv_service.dart';
import 'package:bestandsaufnahme_01/app/theme/app_palette.dart';
import 'package:bestandsaufnahme_01/core/logging/app_log.dart';
import 'package:bestandsaufnahme_01/features/buildings/building_details/export_dialogs.dart';

/// CSV-Import/Export-Logik der Gebäude-Seite.
///
/// `T` = Widget der Page (hier: [BuildingDetailsPage]), damit kein
/// Zirkel-Import zur Page-Datei nötig ist.
mixin BuildingDetailsCsvActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// Aktuelles Gebäude (IDs für Import/Export).
  Building get csvBuilding;

  /// Aktuelles Projekt (CSV-Settings sind projektbezogen).
  Project get csvProject;

  /// Geladene Gewerke (Export braucht die Disziplin-Liste).
  List<Disziplin> get csvDisciplines;

  /// Disziplinen neu laden (nach CSV-Import / Settings).
  Future<void> reloadDisciplinesAfterCsv({
    bool clearExpandedState = false,
    bool refreshSystemsPages = false,
  });

  /// Systems-Tabs neu zeichnen (nach Import).
  void refreshSystemsPagesAfterCsv();

  Future<void> importCsv() async {
    try {
      // Zeige Lade-Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // CSV importieren
      appLog('Starte CSV-Import für Building: ${csvBuilding.id}');
      if (csvProject.id.isNotEmpty) {
        await ref.read(csvSettingsProvider(csvProject.id).notifier).load();
      }
      final importCsvSettings = csvProject.id.isNotEmpty
          ? ref.read(csvSettingsProvider(csvProject.id))
          : CsvSettings.defaults();
      final dbService = ref.read(databaseServiceProvider);
      final persistResult = await AnlagenCsvImportService.runFullImport(
        dbService: dbService,
        projectId: csvProject.id,
        buildingId: csvBuilding.id,
        csvSettings: importCsvSettings,
        saveSettings: (updated) async {
          if (csvProject.id.isNotEmpty) {
            await ref
                .read(csvSettingsProvider(csvProject.id).notifier)
                .save(updated);
          }
        },
      );
      appLog(
        'CSV-Import: ${persistResult.savedCount} importiert, '
        '${persistResult.skippedCount} übersprungen, ${persistResult.errorCount} Fehler',
      );

      // Dialog schließen
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Disziplinen neu laden (wichtig, da Schema aktualisiert wurde)
      appLog('Lade Disziplinen neu...');
      await reloadDisciplinesAfterCsv(
        clearExpandedState: true,
        refreshSystemsPages: true,
      );
      refreshSystemsPagesAfterCsv();
    } catch (e, stackTrace) {
      appLog('CSV-Import Fehler: $e');
      appLog('Stack Trace: $stackTrace');

      // Dialog schließen
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  /// Teilen oder Speichern – erst nach Schließen des Lade-Dialogs (sonst kein Speicherort-Dialog).
  Future<String?> _deliverExportBuiltFile(
    ExportBuiltFile built,
    ExportDestination destination, {
    String shareText = 'Anlagen-Export',
    String shareSubject = 'Anlagen-Export',
  }) async {
    if (destination == ExportDestination.saveToDevice) {
      // Kurz warten, bis der Lade-Dialog geschlossen ist – sonst öffnet sich kein Speicher-Dialog.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return null;
      return CsvService.saveFileToDevice(
        file: built.file,
        fileName: built.fileName,
      );
    }
    await Share.shareXFiles(
      [XFile(built.file.path)],
      text: shareText,
      subject: shareSubject,
    );
    return null;
  }

  void _showExportSavedMessage(String savedPath) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gespeichert unter:\n$savedPath'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> exportCsv() async {
    try {
      // Zeige Auswahl-Dialog: CSV oder ZIP mit Fotos
      final exportType = await showExportTypeDialog(context);

      if (exportType == null) return;

      final destination = await showExportDestinationDialog(context);
      if (destination == null) return;

      if (csvProject.id.isNotEmpty) {
        await ref.read(csvSettingsProvider(csvProject.id).notifier).load();
      }
      final csvSettings = csvProject.id.isNotEmpty
          ? ref.read(csvSettingsProvider(csvProject.id))
          : CsvSettings.defaults();

      final dbService = ref.read(databaseServiceProvider);
      final anlagen = await dbService.getAnlagenByBuildingId(csvBuilding.id);
      appLog('Export: ${anlagen.length} Anlagen gefunden');

      if (anlagen.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Keine Anlagen zum Exportieren')),
          );
        }
        return;
      }

      if (exportType == 'csv') {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        late final ExportBuiltFile built;
        try {
          built = await CsvService.buildAnlagenCsvExportFile(
            anlagen: anlagen,
            csvSettings: csvSettings,
            disciplines: csvDisciplines,
            projectId: csvProject.id.isNotEmpty ? csvProject.id : null,
            buildingId: csvBuilding.id,
            dbService: dbService,
          );
        } finally {
          if (mounted) Navigator.of(context).pop();
        }

        if (!mounted) return;

        final savedPath = await _deliverExportBuiltFile(
          built,
          destination,
          shareSubject: 'Anlagen CSV Export',
        );

        if (savedPath != null) {
          _showExportSavedMessage(savedPath);
        }

        appLog('CSV-Export abgeschlossen');
      } else if (exportType == 'zip') {
        // ZIP mit Fotos exportieren - zeige Dialog für Ordnerstruktur
        final structure = await showDialog<PhotoExportStructure>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ordnerstruktur wählen'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.folder, color: AppPalette.primary),
                  title: const Text('Nach Anlagen'),
                  subtitle: const Text('Jede Anlage hat einen eigenen Ordner'),
                  onTap: () =>
                      Navigator.of(context).pop(PhotoExportStructure.byAnlage),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.category, color: AppPalette.primary),
                  title: const Text('Nach Gewerken'),
                  subtitle: const Text('Fotos nach Gewerken gruppiert'),
                  onTap: () =>
                      Navigator.of(context).pop(PhotoExportStructure.byGewerk),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open,
                      color: AppPalette.primaryLight),
                  title: const Text('Alle in einem Ordner'),
                  subtitle: const Text('Alle Fotos in einem Ordner'),
                  onTap: () =>
                      Navigator.of(context).pop(PhotoExportStructure.allInOne),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Abbrechen'),
              ),
            ],
          ),
        );

        if (structure == null) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        late final ExportBuiltFile built;
        try {
          built = await CsvService.buildAnlagenZipExportFile(
            anlagen: anlagen,
            csvSettings: csvSettings,
            structure: structure,
            disciplines: csvDisciplines,
            projectId: csvProject.id.isNotEmpty ? csvProject.id : null,
            buildingId: csvBuilding.id,
            dbService: dbService,
          );
        } finally {
          if (mounted) Navigator.of(context).pop();
        }

        if (!mounted) return;

        String? savedPath;
        try {
          savedPath = await _deliverExportBuiltFile(
            built,
            destination,
            shareText: 'Anlagen-Export mit Fotos',
            shareSubject: 'Anlagen ZIP Export',
          );
        } finally {
          if (await built.file.exists()) {
            await built.file.delete();
          }
        }

        if (savedPath != null) {
          _showExportSavedMessage(savedPath);
        }

        appLog('ZIP-Export abgeschlossen');
      }
    } catch (e, stackTrace) {
      appLog('Export Fehler: $e');
      appLog('Stack Trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export fehlgeschlagen: $e')),
        );
      }
    }
  }
}
