// lib/services/template_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../database/database.dart';
import '../database/database_service.dart';
import '../models/disziplin_schnittstelle.dart';
import '../providers/csv_settings_provider.dart';
import '../utils/app_log.dart';
import '../utils/csv_column_layout.dart';
import '../utils/csv_utils.dart';
import '../utils/csv_parse_isolate.dart';
import '../theme/app_palette.dart';
import 'package:flutter/foundation.dart';

/// Repräsentiert eine Vorlage aus der Gewerkevorlagen.csv
class Template {
  final String gewerk;
  final String anlageBauteil; // 'a' für Anlage, 'b' für Bauteil
  final String anlagentyp;
  final String bezeichnung;
  final String? parameter;

  Template({
    required this.gewerk,
    required this.anlageBauteil,
    required this.anlagentyp,
    required this.bezeichnung,
    this.parameter,
  });

  /// Erstellt eine Template-Instanz aus einer CSV-Zeile.
  /// [parameterOverride]: wenn gesetzt, wird dies als Parameter verwendet (z. B. JSON aus Attribut-Spaltenpaaren).
  factory Template.fromCsvRow(List<dynamic> row, Map<String, int> columnIndices, [String? parameterOverride]) {
    String safeCell(int? idx) {
      if (idx == null || idx < 0 || idx >= row.length) return '';
      return row[idx].toString().trim();
    }

    final param = parameterOverride ?? (columnIndices.containsKey('parameter') ? safeCell(columnIndices['parameter']) : null);
    final paramValue = (param != null && param.isNotEmpty) ? param : null;

    return Template(
      gewerk: safeCell(columnIndices['gewerk']),
      anlageBauteil: safeCell(columnIndices['anlageBauteil']).toLowerCase(),
      anlagentyp: safeCell(columnIndices['anlagentyp']),
      bezeichnung: safeCell(columnIndices['bezeichnung']),
      parameter: paramValue,
    );
  }

  /// Erstellt eine Template-Instanz anhand der projektbezogenen CSV-Einstellungen.
  static Template fromCsvRowWithSettings(
    List<dynamic> row,
    CsvSettings csvSettings,
  ) {
    final h = readTemplateHierarchyFromRow(row, csvSettings);
    return Template(
      gewerk: h.gewerk,
      anlageBauteil: '',
      anlagentyp: h.schemaItem,
      bezeichnung: h.bezeichnung,
      parameter: null,
    );
  }

  static String _safeCellStatic(List<dynamic> row, int idx) {
    if (idx < 0 || idx >= row.length) return '';
    return row[idx].toString().trim();
  }
}

/// Service zum Laden und Verwalten von Vorlagen aus CSV-Dateien
class TemplateService {
  static const String _delimiter = ';';

  static String _detectDelimiterWithSettings(String csvString, int requiredMaxIndex) {
    // WICHTIG: In der Parameter-Spalte kommen oft Kommata vor ("Brennstoff, Leistung..."),
    // daher darf die Erkennung NICHT auf dem bloßen Zählen von ',' basieren.
    // Stattdessen testen wir Kandidaten und wählen den, bei dem die meisten Zeilen
    // genügend Spalten haben, um requiredMaxIndex sicher zu lesen.
    const candidates = [';', '\t', ','];

    String best = _delimiter;
    int bestGoodRows = -1;
    int bestAvgLen = -1;

    // Zusätzlich bewerten wir, ob in der Anlage/Bauteil-Spalte (Index requiredMaxIndex ist nur Min-Check)
    // typischerweise 'a'/'b' vorkommt. Das ist ein sehr gutes Signal für korrektes Parsing.
    // Der tatsächliche Index wird im Import anhand der Einstellungen geprüft.

    for (final d in candidates) {
      try {
        final parsed = CsvToListConverter(
          fieldDelimiter: d,
          eol: '\n',
          shouldParseNumbers: false,
        ).convert(csvString);

        if (parsed.isEmpty) continue;

        // Prüfe nur die ersten N Zeilen für Performance
        final sample = parsed.length > 30 ? parsed.sublist(0, 30) : parsed;
        int good = 0;
        int totalLen = 0;
        for (final row in sample) {
          totalLen += row.length;
          if (row.length > requiredMaxIndex) good++;
        }
        final avgLen = sample.isEmpty ? 0 : (totalLen ~/ sample.length);

        // Priorität: mehr "good rows", dann höhere durchschnittliche Spaltenanzahl,
        // bei Gleichstand Semikolon bevorzugen.
        final isBetter = good > bestGoodRows ||
            (good == bestGoodRows && avgLen > bestAvgLen) ||
            (good == bestGoodRows && avgLen == bestAvgLen && d == ';' && best != ';');

        if (isBetter) {
          best = d;
          bestGoodRows = good;
          bestAvgLen = avgLen;
        }
      } catch (e) {
        appLog('Delimiter-Kandidat $d fehlgeschlagen', error: e);
      }
    }

    return best;
  }

  static String _safeCell(List<dynamic> row, int idx) {
    if (idx < 0 || idx >= row.length) return '';
    return row[idx].toString().trim();
  }


  /// Baut aus einer CSV-Zeile Attribut-Definitionen (Dreiergruppen) ab [startColumn].
  static String _buildParameterJsonFromAttributeQuadruplets(List<dynamic> row, int startColumn) {
    final schema = <Map<String, dynamic>>[];
    for (var i = startColumn; i + 2 < row.length; i += 3) {
      final name = _safeCell(row, i);
      if (name.isEmpty) continue;
      schema.add(_schemaEntryFromTripletCells(
        name,
        _safeCell(row, i + 1),
        _safeCell(row, i + 2),
      ));
    }
    if (schema.isEmpty) return '';
    return json.encode({'_schema': schema});
  }

  static Map<String, dynamic> _schemaEntryFromTripletCells(
    String name,
    String typeStr,
    String artStr, {
    String? legacyOptionsStr,
  }) {
    return CsvSettings.schemaFieldFromGewerkeTypeCell(
      name,
      typeStr,
      legacyOptionsStr: legacyOptionsStr,
      artStr: artStr,
    );
  }

  /// Baut Attribut-Schema aus konfigurierten Spalten-Dreiergruppen (Header-Mapping).
  static String _buildParameterJsonFromConfiguredQuadruplets(
    List<dynamic> row,
    List<AttributeTripletColumn> quadruplets, {
    List<String>? headers,
  }) {
    final schema = <Map<String, dynamic>>[];
    for (var i = 0; i < quadruplets.length; i++) {
      final group = quadruplets[i];
      final name = _safeCell(row, group.nameColumn);
      if (name.isEmpty) continue;
      final entry = _schemaEntryFromTripletCells(
        name,
        _safeCell(row, group.typeColumn),
        _safeCell(row, group.artColumn),
        legacyOptionsStr: group.optionsColumn >= 0
            ? _safeCell(row, group.optionsColumn)
            : null,
      );
      final headerLabel = (headers != null &&
              group.nameColumn >= 0 &&
              group.nameColumn < headers.length)
          ? headers[group.nameColumn]
          : '';
      entry['attSlot'] =
          CsvSettings.attNumberFromHeaderLabel(headerLabel) ?? (i + 1);
      schema.add(entry);
    }
    if (schema.isEmpty) return '';
    return json.encode({'_schema': schema});
  }

  /// Entfernt die gespeicherte CSV-Import-Headerzeile (gemeinsam mit Anlagen-Import).
  static Future<void> clearTemplateImportHeaderRow(String projectId) async {
    final current = await CsvSettings.loadForProject(projectId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'csv_settings_$projectId',
      json.encode(current.copyWith(importHeaderRow: const []).toJson()),
    );
  }

  /// Schema aus Anlagen-Zeile (ATT + ATT_wert): Feldname steht in der Namen-Spalte.
  static String _buildParameterJsonFromAnlagenPairsRow(
    List<dynamic> row,
    List<AttributeColumnPair> pairs,
  ) {
    final schema = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (var i = 0; i < pairs.length; i++) {
      final pair = pairs[i];
      final attSlot = CsvSettings.attSlotForPair(pair, i);
      final label = _safeCell(row, pair.nameColumn);
      if (label.isEmpty || CsvSettings.isAnlagenCsvColumnParamKey(label)) {
        continue;
      }
      final key = label;
      if (seen.contains(key)) continue;
      seen.add(key);
      schema.add({
        'key': key,
        'label': label,
        'type': 'text',
        'attSlot': attSlot,
      });
    }
    if (schema.isEmpty) return '';
    return json.encode({'_schema': schema});
  }

  static int _firstAttributeScanColumn(CsvSettings csvSettings) {
    final reserved = csvSettings.reservedImportColumnIndices();
    var max = -1;
    for (final i in reserved) {
      if (i > max) max = i;
    }
    return max + 1;
  }

  static String _buildParameterJsonForRow(
    List<dynamic> row,
    CsvSettings csvSettings, {
    List<String>? headerRow,
    int rowIndex = 0,
  }) {
    final header = headerRow ?? csvSettings.importHeaderRow;
    final mapping = CsvSettings.resolveImportAttributeMapping(
      headerRow: header,
      settings: csvSettings,
    );

    String schemaJson = '';
    if (CsvSettings.headerLooksLikeAnlagenWertFormat(header) &&
        mapping.pairs.isNotEmpty) {
      schemaJson = _buildParameterJsonFromAnlagenPairsRow(row, mapping.pairs);
    } else if (mapping.quadruplets.isNotEmpty) {
      schemaJson = _buildParameterJsonFromConfiguredQuadruplets(
        row,
        mapping.quadruplets,
        headers: header,
      );
    } else {
      schemaJson = _buildParameterJsonFromAttributeQuadruplets(
        row,
        _firstAttributeScanColumn(csvSettings),
      );
    }

    return _mergeParameterJsonWithCsvRow(
      schemaJson: schemaJson,
      headerRow: header,
      row: row,
      rowIndex: rowIndex,
    );
  }

  static String _mergeParameterJsonWithCsvRow({
    required String schemaJson,
    required List<String> headerRow,
    required List<dynamic> row,
    required int rowIndex,
  }) {
    final decoded = <String, dynamic>{};
    if (schemaJson.trim().isNotEmpty) {
      try {
        final parsed = json.decode(schemaJson);
        if (parsed is Map) {
          decoded.addAll(Map<String, dynamic>.from(parsed));
        }
      } catch (e) {
        appLog('Schema-JSON in Vorlage ungültig', error: e);
      }
    }

    final cells = <String, String>{};
    for (var i = 0; i < headerRow.length; i++) {
      final h = headerRow[i].trim();
      if (h.isEmpty) continue;
      cells[h] = _safeCell(row, i);
    }
    decoded[CsvSettings.csvRowCellsParamKey] = cells;
    decoded[CsvSettings.csvRowIndexParamKey] = rowIndex;

    if (decoded.isEmpty) return '';
    return json.encode(decoded);
  }

  /// Lädt Vorlagen aus der Datenbank (projektbezogen)
  static Future<List<Template>> loadTemplatesFromDatabase(
    DatabaseService dbService,
    String projectId, {
    String? gewerk,
  }) async {
    final templateRows = gewerk != null
        ? await dbService.getTemplatesByProjectIdAndGewerk(projectId, gewerk)
        : await dbService.getTemplatesByProjectId(projectId);

    return templateRows.map((row) => Template(
      gewerk: row.gewerk,
      anlageBauteil: row.anlageBauteil,
      anlagentyp: row.anlagentyp,
      bezeichnung: row.bezeichnung,
      parameter: row.parameter,
    )).toList();
  }

  /// Importiert Vorlagen aus einer CSV-Datei und speichert sie in der Datenbank
  /// Erstellt automatisch Disziplinen aus den Gewerken für alle Gebäude im Projekt
  static Future<int> importTemplatesFromCsv(
    DatabaseService dbService,
    String projectId,
    String? filePath, {
    String? buildingId,
  }) async {
    // Wenn kein filePath angegeben, öffne FilePicker
    if (filePath == null || filePath.isEmpty) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (result == null || result.files.single.path == null) {
        throw Exception('Keine CSV-Datei ausgewählt');
      }
      filePath = result.files.single.path!;
      
      // Prüfe, ob es eine CSV-Datei ist
      if (!filePath.toLowerCase().endsWith('.csv')) {
        throw Exception('Bitte wählen Sie eine CSV-Datei aus');
      }
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('CSV-Datei nicht gefunden: $filePath');
    }

    // CSV robust lesen (BOM/Encoding/EOL)
    final bytes = await file.readAsBytes();
    final csvString = CsvUtils.normalizeCsvStringFromBytes(bytes);

    final csvSettings = await CsvSettings.loadForProject(projectId);
    final hierarchyCols = csvSettings.hierarchyNameColumnIndices();
    final level1Idx = hierarchyCols.isNotEmpty ? hierarchyCols.first : 0;
    final schemaLevel = csvSettings.schemaItemLevelNumber ?? 2;
    final level2Idx = hierarchyCols.length >= schemaLevel
        ? hierarchyCols[schemaLevel - 1]
        : (hierarchyCols.length >= 2 ? hierarchyCols[1] : level1Idx);

    int requiredMaxIndex = level1Idx > level2Idx ? level1Idx : level2Idx;
    for (final col in hierarchyCols) {
      if (col > requiredMaxIndex) requiredMaxIndex = col;
    }
    for (final t in csvSettings.attributeTripletColumns) {
      for (final col in t.columnIndices) {
        if (col > requiredMaxIndex) requiredMaxIndex = col;
      }
    }
    final scanStart = _firstAttributeScanColumn(csvSettings);
    if (requiredMaxIndex < scanStart + 2) {
      requiredMaxIndex = scanStart + 2;
    }

    // Delimiter-Sniffing anhand der konfigurierten Hierarchie-Spalten
    const candidates = [';', '\t', ','];
    String delimiter = _detectDelimiterWithSettings(csvString, requiredMaxIndex);

    int bestScore = -1;
    String bestDelimiter = delimiter;
    for (final d in candidates) {
      try {
        final parsed = CsvToListConverter(
          fieldDelimiter: d,
          eol: '\n',
          shouldParseNumbers: false,
        ).convert(csvString);
        if (parsed.length < 2) continue;

        int score = 0;
        final sample = parsed.length > 80 ? parsed.sublist(0, 80) : parsed;
        for (var i = 1; i < sample.length; i++) {
          final row = sample[i];
          if (row.isEmpty) continue;
          if (row.length <= level1Idx || row.length <= level2Idx) {
            continue;
          }
          final level1Val = row[level1Idx].toString().trim();
          if (level1Val.isEmpty) continue;
          final level2Val = row[level2Idx].toString().trim();
          if (level2Val.isNotEmpty) score++;
        }

        if (score > bestScore || (score == bestScore && d == ';' && bestDelimiter != ';')) {
          bestScore = score;
          bestDelimiter = d;
        }
      } catch (e) {
        appLog('Delimiter-Kandidat $d fehlgeschlagen', error: e);
      }
    }
    delimiter = bestDelimiter;
    final csvData = await compute(parseCsvRowsIsolate, {
      'csv': csvString,
      'delimiter': delimiter,
    });

    if (csvData.isEmpty) {
      throw Exception('CSV-Datei ist leer');
    }

    final importHeaderRow =
        csvData[0].map((cell) => cell.toString().trim()).toList();
    await CsvSettings.saveImportHeaderRowForProject(projectId, importHeaderRow);

    // Lösche alle bestehenden Vorlagen für dieses Projekt
    await dbService.deleteTemplatesByProjectId(projectId);

    // Sammle alle eindeutigen Gewerke aus den Vorlagen
    // (nicht nur "a", damit auch bei unvollständigen Vorlagen Disziplinen entstehen)
    final uniqueGewerke = <String>{};
    
    // Parse Datenzeilen und speichere direkt in DB
    int count = 0;
    int skipped = 0;
    var dataRowIndex = 0;
    for (var i = 1; i < csvData.length; i++) {
      final row = csvData[i];
      if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
        continue;
      }
      try {
        final template = Template.fromCsvRowWithSettings(
          row,
          csvSettings,
        );
        if (template.gewerk.isNotEmpty && template.anlagentyp.isNotEmpty) {
          final parameterJson = _buildParameterJsonForRow(
            row,
            csvSettings,
            headerRow: importHeaderRow,
            rowIndex: dataRowIndex,
          );
          await dbService.insertTemplate(
            projectId,
            template.gewerk,
            '',
            template.anlagentyp,
            template.bezeichnung,
            parameterJson.isEmpty ? null : parameterJson,
          );
          
          uniqueGewerke.add(template.gewerk);
          count++;
          dataRowIndex++;
        } else {
          skipped++;
        }
      } catch (e) {
        appLog('Fehler beim Parsen der Vorlage in Zeile ${i + 1}: $e');
        skipped++;
      }
    }

    appLog(
      'Vorlagen-Import abgeschlossen: projectId=$projectId, valid=$count, skipped=$skipped, delimiter=$delimiter, requiredMaxIndex=$requiredMaxIndex, uniqueGewerke=${uniqueGewerke.length}',
    );

    // Optional: Disziplin-Schemata aus Vorlagen synchronisieren,
    // aber keine neuen Gewerke mehr automatisch anlegen.
    if (buildingId != null) {
      try {
        await _syncDisciplineSchemasFromTemplates(dbService, buildingId, projectId);
      } catch (e) {
        appLog('Fehler beim Sync der Disziplinen aus Vorlagen: $e');
        // Fehler wird ignoriert, damit der Import nicht fehlschlägt
      }
    }

    return count;
  }

  static Disziplin _defaultDisciplineForGewerk(String gewerk) {
    return Disziplin(
      label: gewerk,
      icon: Icons.folder_open,
      color: AppPalette.primary,
      schema: const [],
      revisionsobjektSchemas: const {},
    );
  }

  /// Einzigartige Gewerk-Namen aus Projekt-Vorlagen (sortiert).
  static Future<List<String>> templateGewerkLabels(
    DatabaseService dbService,
    String projectId,
  ) async {
    final rows = await dbService.getTemplatesByProjectId(projectId);
    final labels = <String>{};
    for (final row in rows) {
      final g = row.gewerk.trim();
      if (g.isNotEmpty) labels.add(g);
    }
    final list = labels.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// Baut Disziplin-Objekte aus Vorlagen (nur Schema, ohne DB-Persistenz).
  /// Für CSV-Einstellungen / Plus-Auswahl – nicht für die Technik-Liste.
  static List<Disziplin> buildVirtualDisciplinesFromTemplateRows(
    List<TemplateDb> templateRows,
  ) {
    final schemaByGewerkAndTyp = _schemaByGewerkAndTypFromRows(templateRows);
    final allGewerke = <String>{};
    for (final row in templateRows) {
      final gewerk = row.gewerk.trim();
      if (gewerk.isNotEmpty) allGewerke.add(gewerk);
    }

    final sorted = allGewerke.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted
        .map(
          (gewerk) => _mergeTemplateSchemasIntoDiscipline(
            base: _defaultDisciplineForGewerk(gewerk),
            gewerk: gewerk,
            templateRows: templateRows,
            schemaByGewerkAndTyp: schemaByGewerkAndTyp,
          ),
        )
        .toList();
  }

  static Disziplin _mergeTemplateSchemasIntoDiscipline({
    required Disziplin base,
    required String gewerk,
    required List<TemplateDb> templateRows,
    required Map<String, Map<String, List<Map<String, dynamic>>>>
        schemaByGewerkAndTyp,
  }) {
    final byTyp = schemaByGewerkAndTyp[gewerk] ?? {};
    final mergedRoSchemas = Map<String, List<Map<String, dynamic>>>.from(
      base.revisionsobjektSchemas,
    );
    for (final entry in byTyp.entries) {
      mergedRoSchemas[entry.key] =
          entry.value.map((f) => Map<String, dynamic>.from(f)).toList();
    }
    for (final row in templateRows) {
      if (row.gewerk.trim() != gewerk) continue;
      final typ = row.anlagentyp.trim();
      if (typ.isNotEmpty) {
        mergedRoSchemas.putIfAbsent(typ, () => []);
      }
    }
    return Disziplin(
      label: base.label,
      icon: base.icon,
      color: base.color,
      schema: base.globalSchemaFields,
      groupingKey: base.groupingKey,
      revisionsobjektSchemas: mergedRoSchemas,
    );
  }

  static Map<String, Map<String, List<Map<String, dynamic>>>>
      _schemaByGewerkAndTypFromRows(List<TemplateDb> templateRows) {
    final schemaByGewerkAndTyp =
        <String, Map<String, List<Map<String, dynamic>>>>{};
    for (final row in templateRows) {
      final gewerk = row.gewerk.trim();
      final typ = row.anlagentyp.trim();
      if (gewerk.isEmpty || typ.isEmpty) continue;
      schemaByGewerkAndTyp.putIfAbsent(gewerk, () => {});
      final schema = getSchemaFromTemplateParameter(row.parameter);
      if (schema.isEmpty) {
        schemaByGewerkAndTyp[gewerk]!.putIfAbsent(typ, () => []);
        continue;
      }
      final merged = mergeSchemaFieldLists(
        schemaByGewerkAndTyp[gewerk]![typ] ?? const [],
        schema,
      );
      schemaByGewerkAndTyp[gewerk]![typ] = merged;
    }
    return schemaByGewerkAndTyp;
  }

  /// Synchronisiert Schemata aus Vorlagen in **bereits vorhandene** Disziplinen.
  /// Legt keine leeren Gewerk-Shells mehr an (Vorlagen ≠ Listen-Einträge).
  static Future<List<Disziplin>> ensureDisciplinesFromTemplates(
    DatabaseService dbService,
    String buildingId,
    String projectId, {
    bool createMissingGewerke = false,
  }) async {
    final templateRows = await dbService.getTemplatesByProjectId(projectId);
    final existing = await dbService.getDisciplinesByBuildingId(buildingId);
    if (templateRows.isEmpty) {
      return existing;
    }

    final schemaByGewerkAndTyp = _schemaByGewerkAndTypFromRows(templateRows);
    final byLabel = <String, Disziplin>{
      for (final d in existing) d.label.trim(): d,
    };

    final result = <Disziplin>[];
    for (final d in existing) {
      result.add(
        _mergeTemplateSchemasIntoDiscipline(
          base: d,
          gewerk: d.label.trim(),
          templateRows: templateRows,
          schemaByGewerkAndTyp: schemaByGewerkAndTyp,
        ),
      );
    }

    if (createMissingGewerke) {
      final allGewerke = <String>{};
      for (final row in templateRows) {
        final g = row.gewerk.trim();
        if (g.isNotEmpty) allGewerke.add(g);
      }
      final sortedNewGewerke = allGewerke.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      for (final gewerk in sortedNewGewerke) {
        if (byLabel.containsKey(gewerk)) continue;
        final base = _defaultDisciplineForGewerk(gewerk);
        result.add(
          _mergeTemplateSchemasIntoDiscipline(
            base: base,
            gewerk: gewerk,
            templateRows: templateRows,
            schemaByGewerkAndTyp: schemaByGewerkAndTyp,
          ),
        );
      }
    }

    await dbService.replaceDisciplines(buildingId, result);
    appLog(
      'Disziplinen-Schemata aus Vorlagen: ${result.length} Gewerke '
      '(createMissing=$createMissingGewerke) für Gebäude $buildingId',
    );
    return result;
  }

  /// Legt bei Bedarf ein einzelnes Gewerk aus Vorlagen an (Plus-Button).
  static Future<Disziplin> materializeDisciplineFromTemplates({
    required DatabaseService dbService,
    required String buildingId,
    required String projectId,
    required String gewerk,
  }) async {
    final label = gewerk.trim();
    if (label.isEmpty) {
      throw ArgumentError('Gewerk darf nicht leer sein');
    }
    final existing = await dbService.getDisciplinesByBuildingId(buildingId);
    Disziplin? match;
    for (final d in existing) {
      if (d.label.trim().toLowerCase() == label.toLowerCase()) {
        match = d;
        break;
      }
    }
    if (match != null) {
      final synced = await ensureDisciplinesFromTemplates(
        dbService,
        buildingId,
        projectId,
      );
      for (final d in synced) {
        if (d.label.trim().toLowerCase() == label.toLowerCase()) {
          return d;
        }
      }
      return match;
    }

    final templateRows = await dbService.getTemplatesByProjectId(projectId);
    final schemaByGewerkAndTyp = _schemaByGewerkAndTypFromRows(templateRows);
    final created = _mergeTemplateSchemasIntoDiscipline(
      base: _defaultDisciplineForGewerk(label),
      gewerk: label,
      templateRows: templateRows,
      schemaByGewerkAndTyp: schemaByGewerkAndTyp,
    );
    final next = [...existing, created];
    await dbService.replaceDisciplines(buildingId, next);
    appLog('Gewerk aus Vorlage materialisiert: $label');
    return created;
  }

  /// Aktualisiert die Disziplin-Schemata aus den importierten Vorlagen (pro Revisionsobjekt).
  static Future<void> _syncDisciplineSchemasFromTemplates(
    DatabaseService dbService,
    String buildingId,
    String projectId,
  ) async {
    await ensureDisciplinesFromTemplates(dbService, buildingId, projectId);
  }

  /// Lädt Vorlagen aus einer CSV-Datei (ohne Speichern in DB - für temporäre Verwendung)
  static Future<List<Template>> loadTemplatesFromFile(String? filePath, {String? projectId}) async {
    if (filePath == null || filePath.isEmpty) {
      // Versuche die Datei aus dem Standard-Pfad zu laden
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (result == null || result.files.single.path == null) {
        return [];
      }
      filePath = result.files.single.path!;
      
      // Prüfe, ob es eine CSV-Datei ist
      if (!filePath.toLowerCase().endsWith('.csv')) {
        return [];
      }
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('CSV-Datei nicht gefunden: $filePath');
    }

    final bytes = await file.readAsBytes();
    final csvString = CsvUtils.normalizeCsvStringFromBytes(bytes);
    final delimiter = CsvUtils.detectDelimiterFromLine(csvString.split('\n').first);
    final csvData = await compute(parseCsvRowsIsolate, {
      'csv': csvString,
      'delimiter': delimiter,
    });

    if (csvData.isEmpty) {
      return [];
    }

    final headerRow =
        csvData[0].map((e) => e.toString().trim()).toList();
    final csvSettings = projectId != null
        ? await CsvSettings.loadForProject(projectId)
        : CsvSettings.defaults();

    // Parse Datenzeilen (Parameter = _schema aus CSV-Mapping)
    final templates = <Template>[];
    for (var i = 1; i < csvData.length; i++) {
      final row = csvData[i];
      if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
        continue;
      }
      try {
        final parameterOverride = _buildParameterJsonForRow(
          row,
          csvSettings,
          headerRow: headerRow,
          rowIndex: i - 1,
        );
        final template = Template.fromCsvRowWithSettings(
          row,
          csvSettings,
        );
        final withParams = Template(
          gewerk: template.gewerk,
          anlageBauteil: template.anlageBauteil,
          anlagentyp: template.anlagentyp,
          bezeichnung: template.bezeichnung,
          parameter: parameterOverride.isEmpty ? null : parameterOverride,
        );
        if (withParams.gewerk.isNotEmpty) {
          templates.add(withParams);
        }
      } catch (e) {
        appLog('Fehler beim Parsen der Vorlage in Zeile ${i + 1}: $e');
      }
    }

    return templates;
  }

  /// Gruppiert Vorlagen nach Gewerk und Anlagentyp
  /// Gibt eine Map zurück: {gewerk: {anlagentyp: [templates]}}
  static Map<String, Map<String, List<Template>>> groupTemplatesByGewerkAndType(List<Template> templates) {
    final grouped = <String, Map<String, List<Template>>>{};
    
    for (final template in templates) {
      if (template.anlagentyp.trim().isEmpty) continue;

      if (!grouped.containsKey(template.gewerk)) {
        grouped[template.gewerk] = <String, List<Template>>{};
      }
      
      final gewerkMap = grouped[template.gewerk]!;
      if (!gewerkMap.containsKey(template.anlagentyp)) {
        gewerkMap[template.anlagentyp] = <Template>[];
      }
      
      gewerkMap[template.anlagentyp]!.add(template);
    }
    
    return grouped;
  }

  /// Findet alle Bauteile für eine gegebene Anlage (gleiches Gewerk und Anlagentyp)
  static List<Template> findBauteileForAnlage(
    List<Template> allTemplates,
    String gewerk,
    String anlagentyp,
  ) {
    return allTemplates.where((t) =>
      t.gewerk == gewerk &&
      t.anlagentyp == anlagentyp &&
      t.anlageBauteil == 'b'
    ).toList();
  }

  /// Konvertiert Template-Parameter in ein Map-Format für Anlagen.
  /// Erwartet JSON-String (Attribut → Attributwert) aus den Vorlagen-Attribut-Spalten.
  static Map<String, dynamic> parseParameters(String? parameterString) {
    return _paramsMapFromParameterJson(parameterString);
  }

  /// Extrahiert eindeutige Anlagentypen/Revisionsobjekte aus Vorlagen (ohne a/b-Filter).
  static List<String> getAnlagentypenForGewerk(List<Template> templates) {
    final anlagentypen = <String>{};
    for (final template in templates) {
      if (template.anlagentyp.trim().isNotEmpty) {
        anlagentypen.add(template.anlagentyp.trim());
      }
    }
    return anlagentypen.toList()..sort();
  }

  /// Params für den Anlage-Dialog nach Vorlagenauswahl (Schema-Ebene aus CSV-Mapping).
  static Map<String, dynamic> buildInitialParamsForSchemaItem({
    required Template parentTemplate,
    required String selectedAnlagentyp,
    String? schemaItemParamKey,
  }) {
    final params = buildEmptyParamsFromTemplate(parentTemplate.parameter);
    final type = selectedAnlagentyp.trim();
    if (type.isEmpty) return params;
    final key = schemaItemParamKey?.trim();
    if (key != null && key.isNotEmpty) {
      params[key] = type;
    }
    return params;
  }

  static String resolveParentNameFromTemplate(Template parentTemplate, String selectedAnlagentyp) {
    final bez = parentTemplate.bezeichnung.trim();
    if (bez.isNotEmpty) return bez;
    return selectedAnlagentyp.trim();
  }

  /// Erstellt eine Parameter-Map aus dem gespeicherten Template-Parameter-String.
  /// Der String ist JSON (Attributname → Attributwert), wie beim Anlagen-Import in Einzelspalten.
  static Map<String, dynamic> buildEmptyParamsFromTemplate(String? parameterString) {
    return _paramsMapFromParameterJson(parameterString);
  }

  static Map<String, dynamic> _paramsMapFromParameterJson(String? parameterString) {
    if (parameterString == null || parameterString.trim().isEmpty) return {};
    try {
      final decoded = json.decode(parameterString);
      if (decoded is! Map) return {};
      return decoded.entries
          .where((e) =>
              e.key != '_schema' &&
              e.key != CsvSettings.csvRowCellsParamKey &&
              e.key != CsvSettings.csvRowIndexParamKey)
          .map((e) => MapEntry(e.key.toString(), e.value))
          .fold<Map<String, dynamic>>({}, (m, e) => m..[e.key] = e.value);
    } catch (e) {
      appLog('Template-Parameter JSON ungültig', error: e);
      return {};
    }
  }

  /// Liest das in template.parameter gespeicherte _schema (Attribut-Definitionen) aus.
  static List<Map<String, dynamic>> getSchemaFromTemplateParameter(String? parameterString) {
    if (parameterString == null || parameterString.trim().isEmpty) return [];
    try {
      final decoded = json.decode(parameterString);
      if (decoded is! Map) return [];
      final raw = decoded['_schema'];
      if (raw is! List) return [];
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      appLog('Template-_schema JSON ungültig', error: e);
      return [];
    }
  }

  /// Vereinigt zwei Feldlisten (nach [key], spätere Einträge überschreiben).
  static List<Map<String, dynamic>> mergeSchemaFieldLists(
    List<Map<String, dynamic>> base,
    List<Map<String, dynamic>> extra,
  ) {
    final byKey = <String, Map<String, dynamic>>{};
    for (final f in base) {
      final key = (f['key'] ?? '').toString();
      if (key.isNotEmpty) byKey[key] = Map<String, dynamic>.from(f);
    }
    for (final f in extra) {
      final key = (f['key'] ?? '').toString();
      if (key.isNotEmpty) byKey[key] = Map<String, dynamic>.from(f);
    }
    return byKey.values.toList();
  }

  /// Ergänzt Felder (z. B. aus Import-Params) mit Metadaten aus der Gewerkevorlage (art, type, …).
  static List<Map<String, dynamic>> enrichSchemaFieldsFromMaster(
    List<Map<String, dynamic>> fields,
    List<Map<String, dynamic>> master,
  ) {
    if (master.isEmpty || fields.isEmpty) return fields;

    final byKey = <String, Map<String, dynamic>>{};
    final byLabel = <String, Map<String, dynamic>>{};
    for (final m in master) {
      final key = (m['key'] ?? '').toString();
      final label = (m['label'] ?? '').toString().trim().toLowerCase();
      if (key.isNotEmpty) byKey[key] = m;
      if (label.isNotEmpty) byLabel[label] = m;
    }

    return fields.map((field) {
      final copy = Map<String, dynamic>.from(field);
      final key = (field['key'] ?? '').toString();
      final label = (field['label'] ?? '').toString().trim().toLowerCase();
      final src = byKey[key] ??
          (label.isNotEmpty ? byLabel[label] : null);
      if (src == null) return copy;
      for (final meta in [
        'art',
        'type',
        'options',
        'editable',
        'label',
        'attSlot',
        'attNumber',
      ]) {
        final existing = copy[meta];
        final fromMaster = src[meta];
        if (fromMaster == null) continue;
        final existingEmpty = existing == null ||
            (existing is String && existing.toString().trim().isEmpty);
        // Fallback-Schema setzt type:'text' – Master-Dropdown/Select darf das überschreiben.
        final weakTextType = meta == 'type' &&
            existing is String &&
            existing.toString().trim().toLowerCase() == 'text' &&
            fromMaster.toString().trim().toLowerCase() != 'text';
        if (existingEmpty || weakTextType) {
          copy[meta] = fromMaster;
        }
      }
      return copy;
    }).toList();
  }

  /// Findet den gespeicherten Revisionsobjekt-Key zu einem Anzeige-/Gruppenwert.
  static String? resolveRevisionsobjektKeyForValue(
    Disziplin discipline,
    String value, {
    List<Template>? templates,
  }) {
    final direct = discipline.resolveRevisionsobjektKey(value);
    if (direct != null) return direct;

    final v = value.trim().toLowerCase();
    if (v.isEmpty) return null;

    if (templates != null) {
      for (final t in templates) {
        final typ = t.anlagentyp.trim();
        final bez = t.bezeichnung.trim();
        if (typ.toLowerCase() == v || bez.toLowerCase() == v) {
          return discipline.resolveRevisionsobjektKey(typ) ?? typ;
        }
      }
    }

    for (final k in discipline.revisionsobjektSchemas.keys) {
      final kk = k.trim().toLowerCase();
      if (kk == v || kk.contains(v) || v.contains(kk)) return k;
    }

    if (templates != null) {
      for (final t in templates) {
        final typ = t.anlagentyp.trim().toLowerCase();
        if (typ.contains(v) || v.contains(typ)) {
          return discipline.resolveRevisionsobjektKey(t.anlagentyp.trim()) ??
              t.anlagentyp.trim();
        }
      }
    }
    return null;
  }

  /// Sucht eine Gewerkevorlage (Anlage) zum Revisionsobjekt-Wert.
  static Template? findTemplateForRevisionsobjekt(
    List<Template> templates,
    String revisionsobjektValue,
  ) {
    final v = revisionsobjektValue.trim().toLowerCase();
    if (v.isEmpty) return null;

    Template? partial;
    for (final t in templates) {
      final typ = t.anlagentyp.trim();
      final bez = t.bezeichnung.trim();
      if (typ.toLowerCase() == v || bez.toLowerCase() == v) return t;
      if (partial == null &&
          (typ.toLowerCase().contains(v) ||
              v.contains(typ.toLowerCase()) ||
              bez.toLowerCase().contains(v))) {
        partial = t;
      }
    }
    return partial;
  }

  /// Disziplin mit effektivem Schema für ein Revisionsobjekt (DB + Vorlage + Einstellungen).
  static Disziplin disciplineWithSchemaForRevisionsobjekt({
    required Disziplin discipline,
    required String revisionsobjekt,
    Template? template,
    List<Template>? templatesForLookup,
  }) {
    final roRaw = revisionsobjekt.trim();
    if (roRaw.isEmpty) return discipline;

    final resolvedKey = resolveRevisionsobjektKeyForValue(
          discipline,
          roRaw,
          templates: templatesForLookup,
        ) ??
        roRaw;

    var roFields = discipline.revisionsobjektSchemas[resolvedKey] ?? const <Map<String, dynamic>>[];
    roFields = roFields.map((f) => Map<String, dynamic>.from(f)).toList();

    final templateToUse = template ??
        (templatesForLookup != null
            ? findTemplateForRevisionsobjekt(templatesForLookup, roRaw)
            : null);
    if (templateToUse != null) {
      final fromTemplate = getSchemaFromTemplateParameter(templateToUse.parameter);
      if (fromTemplate.isNotEmpty) {
        roFields = mergeSchemaFieldLists(roFields, fromTemplate);
      }
    }

    final mergedRoSchemas =
        Map<String, List<Map<String, dynamic>>>.from(discipline.revisionsobjektSchemas);
    if (roFields.isNotEmpty) {
      mergedRoSchemas[resolvedKey] = roFields;
    }

    // Flaches Schema: global + aktuelles RO (+ Legacy ohne RO-Zuordnung).
    // Nicht discipline.schema mergen – dort liegen oft alle RO-Felder und CSV-Duplikate.
    var flatSchema = mergeSchemaFieldLists(
      discipline.globalSchemaFields,
      roFields,
    );
    final legacy = discipline.legacyIndividualSchemaFields;
    if (legacy.isNotEmpty) {
      flatSchema = mergeSchemaFieldLists(flatSchema, legacy);
    }

    return Disziplin(
      label: discipline.label,
      icon: discipline.icon,
      color: AppPalette.primary,
      schema: CsvSettings.filterSchemaFieldsForDialog(flatSchema),
      groupingKey: discipline.groupingKey,
      revisionsobjektSchemas: mergedRoSchemas.map(
        (key, fields) => MapEntry(
          key,
          CsvSettings.filterSchemaFieldsForDialog(fields),
        ),
      ),
    );
  }

  // Hinweis: Früher gab es hier eine Hilfsfunktion, die automatisch Disziplinen
  // aus den in den Vorlagen vorkommenden Gewerken erstellt hat.
  // Dieses Verhalten wurde entfernt, damit beim Vorlagen-Import
  // keine neuen Gewerke mehr ungefragt in der Technik-Übersicht entstehen.

  /// Erstellt eine leere Gewerkevorlagen-CSV mit dem korrekten Header.
  /// Die Datei enthält nur die Headerzeile und kann vom Nutzer befüllt werden.
  static Future<File> buildGewerkeVorlagenCsvTemplate({
    required CsvSettings csvSettings,
    int attSlotCount = 5,
  }) async {
    final headers = <String>[];

    // Hierarchie-Spalten: Label aus gespeichertem importHeaderRow oder labelX
    final enabledLevels = csvSettings.enabledLevelsOrdered;
    for (var i = 0; i < enabledLevels.length; i++) {
      final levelNum = csvSettings.levelNumberAtEnabledIndex(i);
      final label = csvSettings.hierarchyLevelHeaderLabel(levelNum).trim();
      if (label.isNotEmpty) {
        headers.add(label);
      } else {
        if (levelNum == 1) headers.add(csvSettings.labelGewerk);
        if (levelNum == 2) headers.add(csvSettings.labelAnlage);
        if (levelNum == 3) headers.add(csvSettings.labelBauteil);
      }
    }
    if (headers.isEmpty) {
      headers.addAll([csvSettings.labelGewerk, csvSettings.labelAnlage]);
    }

    // ATT-Dreiergruppen aus vorhandenen Einstellungen oder Standard
    final triplets = csvSettings.attributeTripletColumns;
    if (triplets.isNotEmpty) {
      for (var i = 0; i < triplets.length; i++) {
        final n = i + 1;
        headers.addAll(['ATT$n', 'ATT${n}_TYPE', 'ATT${n}_WERT']);
      }
    } else {
      for (var n = 1; n <= attSlotCount; n++) {
        headers.addAll(['ATT$n', 'ATT${n}_TYPE', 'ATT${n}_WERT']);
      }
    }

    final exportDelimiter =
        csvSettings.exportDelimiter.isNotEmpty ? csvSettings.exportDelimiter : ';';
    final csvString = ListToCsvConverter(
      fieldDelimiter: exportDelimiter,
      eol: '\n',
    ).convert([headers]);

    final utf8Bom = [0xEF, 0xBB, 0xBF];
    final csvBytes = utf8Bom + utf8.encode(csvString);

    final directory = await getTemporaryDirectory();
    const fileName = 'gewerkevorlagen_vorlage.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(csvBytes);

    appLog('Gewerkevorlagen-Vorlage erstellt: ${headers.length} Spalten');
    return file;
  }
}

