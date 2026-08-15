/// Orchestriert Anlagen-CSV-Import: Parsen über [CsvService], Schema-Sync und Persistenz.
/// Dedupliziert nach `lfdNummer` und bereinigt Import-Parameter vor dem Speichern.

import 'package:bestandsaufnahme_01/core/database/database_service.dart';
import 'package:bestandsaufnahme_01/features/systems/models/anlage.dart';
import 'package:bestandsaufnahme_01/features/systems/models/disziplin_schnittstelle.dart';
import 'package:bestandsaufnahme_01/features/csv/providers/csv_settings_provider.dart';
import 'package:bestandsaufnahme_01/core/logging/app_log.dart';
import 'package:bestandsaufnahme_01/features/csv/utils/csv_column_layout.dart';
import 'package:bestandsaufnahme_01/features/systems/services/anlage_validation_service.dart';
import 'package:bestandsaufnahme_01/features/csv/services/csv_service.dart';
import 'package:bestandsaufnahme_01/features/systems/services/template_service.dart';

/// Migriert Legacy-Param-Keys und repariert Schema-/Zellen-Metadaten nach dem Import.
void _migrateAnlageParams(
  Map<String, dynamic> params,
  Disziplin discipline, {
  List<String> importHeaders = const [],
  CsvSettings? csvSettings,
}) {
  String? revisionsobjekt;
  for (final ro in discipline.revisionsobjektNames) {
    for (final entry in params.entries) {
      if (entry.value?.toString().trim() == ro) {
        revisionsobjekt = ro;
        break;
      }
    }
    if (revisionsobjekt != null) break;
  }
  final schemaFields = discipline.effectiveSchemaFor(
    revisionsobjekt: revisionsobjekt,
  );
  if (!hasCsvRowCellsForExport(params)) {
    CsvSettings.migrateParamsFromAnlagenColumnKeys(
      params: params,
      schemaFields: schemaFields,
    );
  }
  AnlageParamsCleanup.repairAndClear(
    params: params,
    schemaFields: schemaFields,
    importHeaders: importHeaders,
    csvSettings: csvSettings,
  );
}

/// Ergebnis des Speicherns importierter Anlagen in die Datenbank.
class AnlagenCsvPersistResult {
  final int savedCount;
  final int skippedCount;
  final int errorCount;

  const AnlagenCsvPersistResult({
    required this.savedCount,
    required this.skippedCount,
    required this.errorCount,
  });
}

/// Anlagen-CSV-Import (Abgleich / Neuaufnahme) – Dateiauswahl, Parsen und Persistenz.
class AnlagenCsvImportService {
  /// True, wenn im Gebäude mindestens eine per CSV importierte Anlage (mit lfdNummer) existiert.
  static Future<bool> hasBuildingAnlagenCsvImport(
    DatabaseService dbService,
    String buildingId,
  ) async {
    final anlagen = await dbService.getAnlagenByBuildingId(buildingId);
    return anlagen.any((a) {
      final lfd = a.params['lfdNummer']?.toString().trim();
      return lfd != null && lfd.isNotEmpty;
    });
  }

  /// Speichert geparste Anlagen; überspringt bestehende lfdNummern.
  static Future<AnlagenCsvPersistResult> persistImportedAnlagen({
    required DatabaseService dbService,
    required String buildingId,
    required List<Anlage> anlagen,
    List<String> importHeaders = const [],
    CsvSettings? csvSettings,
  }) async {
    int savedCount = 0;
    int skippedCount = 0;
    int errorCount = 0;
    final lfdToId = await dbService.getLfdNummerToIdMap(buildingId);
    final pendingInserts = <Anlage>[];

    for (final anlage in anlagen) {
      try {
        if (anlage.params['__syntheticParent'] == true) {
          continue;
        }
        final resolvedFloorId = anlage.floorId;
        final lfdNummer = anlage.params['lfdNummer']?.toString().trim();
        if (lfdNummer != null && lfdNummer.isNotEmpty) {
          final existingId = lfdToId[lfdNummer];
          if (existingId != null) {
            skippedCount++;
            continue;
          }

          final parentLfd = anlage.params['__parentLfdNummer']?.toString().trim();
          String? resolvedParentId;
          if (parentLfd != null && parentLfd.isNotEmpty) {
            resolvedParentId = lfdToId[parentLfd];
          }

          final cleanedParams = Map<String, dynamic>.from(anlage.params);
          cleanedParams.remove('__parentLfdNummer');
          cleanedParams.remove('__etageName');
          _migrateAnlageParams(
            cleanedParams,
            anlage.discipline,
            importHeaders: importHeaders,
            csvSettings: csvSettings,
          );
          // Importierte Werte sind nicht bestätigt – keinen Listen-Haken setzen.
          AnlageValidationService.stripFieldConfirmationMeta(cleanedParams);

          pendingInserts.add(Anlage(
            id: anlage.id,
            parentId: resolvedParentId,
            name: anlage.name,
            params: cleanedParams,
            floorId: resolvedFloorId,
            buildingId: anlage.buildingId,
            isMarker: anlage.isMarker,
            markerInfo: anlage.markerInfo,
            markerType: anlage.markerType,
            discipline: anlage.discipline,
          ));
          lfdToId[lfdNummer] = anlage.id;
        } else {
          final cleanedParams = Map<String, dynamic>.from(anlage.params);
          cleanedParams.remove('__etageName');
          _migrateAnlageParams(
            cleanedParams,
            anlage.discipline,
            importHeaders: importHeaders,
            csvSettings: csvSettings,
          );

          pendingInserts.add(Anlage(
            id: anlage.id,
            parentId: anlage.parentId,
            name: anlage.name,
            params: cleanedParams,
            floorId: resolvedFloorId,
            buildingId: anlage.buildingId,
            isMarker: anlage.isMarker,
            markerInfo: anlage.markerInfo,
            markerType: anlage.markerType,
            discipline: anlage.discipline,
          ));
        }
      } catch (e, st) {
        errorCount++;
        appLog(
          'Anlagen-CSV: Zeile konnte nicht vorbereitet werden',
          error: e,
          stackTrace: st,
        );
      }
    }

    if (pendingInserts.isNotEmpty) {
      try {
        await dbService.insertAnlagenBatch(pendingInserts);
        savedCount = pendingInserts.length;
      } catch (e, st) {
        errorCount += pendingInserts.length;
        appLog(
          'Anlagen-CSV: Batch-Insert fehlgeschlagen '
          '(${pendingInserts.length} Anlagen)',
          error: e,
          stackTrace: st,
        );
      }
    }

    return AnlagenCsvPersistResult(
      savedCount: savedCount,
      skippedCount: skippedCount,
      errorCount: errorCount,
    );
  }

  /// Vollständiger Import: Datei wählen, parsen, Einstellungen aktualisieren, Anlagen speichern.
  static Future<AnlagenCsvPersistResult> runFullImport({
    required DatabaseService dbService,
    required String projectId,
    required String buildingId,
    required CsvSettings csvSettings,
    required Future<void> Function(CsvSettings updated) saveSettings,
  }) async {
    final importResult = await CsvService.importAnlagenCsvForDisciplines(
      dbService: dbService,
      buildingId: buildingId,
      csvSettings: csvSettings,
    );

    final header = importResult.importHeaderRow;
    final keepManual = csvSettings.hasManualAttributeRange;
    // Ein Dialekt speichern (Pair ODER Triplet), nicht beide Listen parallel füllen.
    final mapping = CsvSettings.resolveImportAttributeMapping(
      headerRow: header,
      settings: csvSettings,
    );
    await saveSettings(
      csvSettings.copyWith(
        importHeaderRow: header,
        exportDelimiter: importResult.detectedDelimiter,
        attributeColumnPairs: keepManual
            ? csvSettings.attributeColumnPairs
            : (mapping.isPair ? mapping.pairs : const []),
        attributeTripletColumns: keepManual
            ? csvSettings.attributeTripletColumns
            : (mapping.isTriplet
                ? mapping.triplets
                : (mapping.isPair ? const [] : csvSettings.attributeTripletColumns)),
      ),
    );

    // Schemata (inkl. art-Gruppen) aus Gewerkevorlagen in Disziplinen übernehmen.
    await TemplateService.ensureDisciplinesFromTemplates(
      dbService,
      buildingId,
      projectId,
    );

    final settingsForPersist = await CsvSettings.loadForProject(projectId);
    return persistImportedAnlagen(
      dbService: dbService,
      buildingId: buildingId,
      anlagen: importResult.anlagen,
      importHeaders: header,
      csvSettings: settingsForPersist,
    );
  }
}
