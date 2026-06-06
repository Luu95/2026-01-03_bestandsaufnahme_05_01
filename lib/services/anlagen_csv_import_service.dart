// lib/services/anlagen_csv_import_service.dart

import '../database/database_service.dart';
import '../models/anlage.dart';
import '../models/disziplin_schnittstelle.dart';
import '../providers/csv_settings_provider.dart';
import '../utils/csv_column_layout.dart';
import 'csv_service.dart';
import 'template_service.dart';

void _migrateAnlageParams(
  Map<String, dynamic> params,
  Disziplin discipline,
) {
  if (hasCsvRowCellsForExport(params)) return;
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
  CsvSettings.migrateParamsFromAnlagenColumnKeys(
    params: params,
    schemaFields: schemaFields,
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
          _migrateAnlageParams(cleanedParams, anlage.discipline);

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
          _migrateAnlageParams(cleanedParams, anlage.discipline);

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
      } catch (_) {
        errorCount++;
      }
    }

    if (pendingInserts.isNotEmpty) {
      try {
        await dbService.insertAnlagenBatch(pendingInserts);
        savedCount = pendingInserts.length;
      } catch (_) {
        errorCount += pendingInserts.length;
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
    final detectedPairs = CsvSettings.detectAnlagenAttributePairsFromHeader(header);
    await saveSettings(
      csvSettings.copyWith(
        importHeaderRow: header,
        exportDelimiter: importResult.detectedDelimiter,
        attributeColumnPairs: detectedPairs.isNotEmpty
            ? detectedPairs
            : csvSettings.attributeColumnPairs,
        // Gewerke-Vierergruppen behalten – Import wählt Mapping je nach Header.
        attributeTripletColumns: csvSettings.attributeTripletColumns,
      ),
    );

    // Schemata (inkl. art-Gruppen) aus Gewerkevorlagen in Disziplinen übernehmen.
    await TemplateService.ensureDisciplinesFromTemplates(
      dbService,
      buildingId,
      projectId,
    );

    return persistImportedAnlagen(
      dbService: dbService,
      buildingId: buildingId,
      anlagen: importResult.anlagen,
    );
  }
}
