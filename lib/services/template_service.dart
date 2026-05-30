// lib/services/template_service.dart

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../models/disziplin_schnittstelle.dart';
import '../providers/csv_settings_provider.dart';
import '../utils/app_log.dart';
import '../utils/csv_utils.dart';

// Debug-only: verhindert Logging in Release, ohne alle Call-Sites umzubauen.
void debugPrint(String? message, {int? wrapWidth}) => appLog(message ?? '');

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
  static Template fromCsvRowWithSettings(List<dynamic> row, Map<String, dynamic> settings) {
    final gewerkIdx = settings['gewerkSpalte'] as int? ?? 0;
    final revisObjIdx = settings['revisionsobjektSpalte'] as int? ??
        settings['anlagentypSpalte'] as int? ??
        1;
    final bezIdx = settings['bezeichnungSpalte'] as int? ?? revisObjIdx;

    final gewerk = _safeCellStatic(row, gewerkIdx);
    final anlagentyp = _safeCellStatic(row, revisObjIdx);
    final bezeichnung = bezIdx == revisObjIdx
        ? anlagentyp
        : _safeCellStatic(row, bezIdx);

    return Template(
      gewerk: gewerk,
      anlageBauteil: 'a',
      anlagentyp: anlagentyp,
      bezeichnung: bezeichnung.isEmpty ? anlagentyp : bezeichnung,
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
      } catch (_) {
        // Ignorieren, probiere nächsten Kandidaten
      }
    }

    return best;
  }

  static String _safeCell(List<dynamic> row, int idx) {
    if (idx < 0 || idx >= row.length) return '';
    return row[idx].toString().trim();
  }

  /// Parst Optionen-String (Semikolon- oder Komma-getrennt) in eine Liste.
  static List<String> _parseOptions(String? optionsStr) {
    if (optionsStr == null || optionsStr.trim().isEmpty) return [];
    final s = optionsStr.trim();
    final split = s.contains(';') ? s.split(';') : s.split(',');
    return split.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// Baut aus einer CSV-Zeile die Attribut-Definitionen (Dreiergruppen: Name, Typ, Optionen) ab [startColumn].
  /// Liefert JSON für template.parameter mit "_schema": [{ key, label, type, options? }].
  static String _buildParameterJsonFromAttributeTriplets(List<dynamic> row, int startColumn) {
    final schema = <Map<String, dynamic>>[];
    for (var i = startColumn; i + 2 < row.length; i += 3) {
      final name = _safeCell(row, i);
      if (name.isEmpty) continue;
      schema.add(_schemaEntryFromTripletCells(name, _safeCell(row, i + 1), _safeCell(row, i + 2)));
    }
    if (schema.isEmpty) return '';
    return json.encode({'_schema': schema});
  }

  static Map<String, dynamic> _schemaEntryFromTripletCells(String name, String typeStr, String optionsStr) {
    final normalizedType = typeStr.toLowerCase();
    String type = 'text';
    if (normalizedType == 'select' || normalizedType == 'dropdown') {
      type = 'dropdown';
    } else if (normalizedType == 'int' || normalizedType == 'number') {
      type = 'number';
    } else if (normalizedType.isNotEmpty) {
      type = normalizedType;
    }
    final entry = <String, dynamic>{
      'key': name,
      'label': name,
      'type': type,
    };
    final options = _parseOptions(optionsStr);
    if (options.isNotEmpty) entry['options'] = options;
    return entry;
  }

  /// Baut Attribut-Schema aus explizit konfigurierten Spalten-Dreiergruppen.
  static String _buildParameterJsonFromConfiguredTriplets(
    List<dynamic> row,
    List<AttributeTripletColumn> triplets,
  ) {
    final schema = <Map<String, dynamic>>[];
    for (final triplet in triplets) {
      final name = _safeCell(row, triplet.nameColumn);
      if (name.isEmpty) continue;
      schema.add(_schemaEntryFromTripletCells(
        name,
        _safeCell(row, triplet.typeColumn),
        _safeCell(row, triplet.optionsColumn),
      ));
    }
    if (schema.isEmpty) return '';
    return json.encode({'_schema': schema});
  }

  static List<AttributeTripletColumn> _parseAttributeTripletColumns(dynamic raw) {
    if (raw is! List) return [];
    final triplets = <AttributeTripletColumn>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        triplets.add(AttributeTripletColumn.fromJson(e));
      } else if (e is Map) {
        triplets.add(AttributeTripletColumn.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return triplets;
  }

  /// Lädt die CSV-Einstellungen für Vorlagen
  static Future<Map<String, dynamic>> _loadTemplateCsvSettings(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'template_csv_settings_$projectId';
    final settingsJson = prefs.getString(key);

    const defaultGewerkSpalte = 0;
    const defaultRevisionsobjektSpalte = 1;
    const defaultErsteSpalteAttribut = 2;

    if (settingsJson != null) {
      try {
        final settings = json.decode(settingsJson) as Map<String, dynamic>;
        final gewerkSpalte = settings['revisionsfeldSpalte'] as int? ??
            settings['gewerkSpalte'] as int? ??
            defaultGewerkSpalte;
        final revisionsobjektSpalte = settings['revisionsobjektSpalte'] as int? ??
            settings['anlagentypSpalte'] as int? ??
            defaultRevisionsobjektSpalte;
        final attributeTripletColumns = _parseAttributeTripletColumns(settings['attributeTripletColumns']);
        return {
          'gewerkSpalte': gewerkSpalte,
          'revisionsobjektSpalte': revisionsobjektSpalte,
          'anlagentypSpalte': revisionsobjektSpalte,
          'bezeichnungSpalte': settings['bezeichnungSpalte'] as int? ?? revisionsobjektSpalte,
          'ersteSpalteAttributDefinitionen':
              settings['ersteSpalteAttributDefinitionen'] as int? ?? defaultErsteSpalteAttribut,
          'attributeTripletColumns': attributeTripletColumns,
        };
      } catch (e) {
        debugPrint('Fehler beim Laden der Vorlagen-CSV-Einstellungen: $e');
      }
    }

    return {
      'gewerkSpalte': defaultGewerkSpalte,
      'revisionsobjektSpalte': defaultRevisionsobjektSpalte,
      'anlagentypSpalte': defaultRevisionsobjektSpalte,
      'bezeichnungSpalte': defaultRevisionsobjektSpalte,
      'ersteSpalteAttributDefinitionen': defaultErsteSpalteAttribut,
      'attributeTripletColumns': <AttributeTripletColumn>[],
    };
  }

  static String _buildParameterJsonForRow(
    List<dynamic> row,
    Map<String, dynamic> settings,
  ) {
    final triplets = settings['attributeTripletColumns'] as List<AttributeTripletColumn>? ?? [];
    if (triplets.isNotEmpty) {
      return _buildParameterJsonFromConfiguredTriplets(row, triplets);
    }
    final ersteSpalteAttribut = settings['ersteSpalteAttributDefinitionen'] as int? ?? 2;
    return _buildParameterJsonFromAttributeTriplets(row, ersteSpalteAttribut);
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
        type: FileType.any,
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

    // Lade CSV-Einstellungen (für Delimiter-Sniffing brauchen wir den maxIndex)
    final settings = await _loadTemplateCsvSettings(projectId);
    final gewerkIdx = settings['gewerkSpalte'] as int? ?? 0;
    final revisObjIdx = settings['revisionsobjektSpalte'] as int? ??
        settings['anlagentypSpalte'] as int? ??
        1;
    final triplets = settings['attributeTripletColumns'] as List<AttributeTripletColumn>? ?? [];
    final ersteSpalteAttribut = settings['ersteSpalteAttributDefinitionen'] as int? ?? 2;

    int requiredMaxIndex = gewerkIdx > revisObjIdx ? gewerkIdx : revisObjIdx;
    if (triplets.isNotEmpty) {
      for (final t in triplets) {
        if (t.nameColumn > requiredMaxIndex) requiredMaxIndex = t.nameColumn;
        if (t.typeColumn > requiredMaxIndex) requiredMaxIndex = t.typeColumn;
        if (t.optionsColumn > requiredMaxIndex) requiredMaxIndex = t.optionsColumn;
      }
    } else if (ersteSpalteAttribut + 2 > requiredMaxIndex) {
      requiredMaxIndex = ersteSpalteAttribut + 2;
    }

    // Delimiter-Sniffing anhand Revisionsfeld/Revisionsobjekt
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
          if (row.length <= gewerkIdx || row.length <= revisObjIdx) continue;
          final gewerkVal = row[gewerkIdx].toString().trim();
          if (gewerkVal.isEmpty) continue;
          final revisObjVal = row[revisObjIdx].toString().trim();
          if (revisObjVal.isNotEmpty) score++;
        }

        if (score > bestScore || (score == bestScore && d == ';' && bestDelimiter != ';')) {
          bestScore = score;
          bestDelimiter = d;
        }
      } catch (_) {}
    }
    delimiter = bestDelimiter;
    final csvData = CsvToListConverter(
      fieldDelimiter: delimiter,
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(csvString);

    if (csvData.isEmpty) {
      throw Exception('CSV-Datei ist leer');
    }

    // columnIndices sind oben bereits geladen (für Delimiter-Erkennung)

    // Lösche alle bestehenden Vorlagen für dieses Projekt
    await dbService.deleteTemplatesByProjectId(projectId);

    // Sammle alle eindeutigen Gewerke aus den Vorlagen
    // (nicht nur "a", damit auch bei unvollständigen Vorlagen Disziplinen entstehen)
    final uniqueGewerke = <String>{};
    
    // Parse Datenzeilen und speichere direkt in DB
    int count = 0;
    int validA = 0;
    int validB = 0;
    int skipped = 0;
    for (var i = 1; i < csvData.length; i++) {
      final row = csvData[i];
      if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
        continue;
      }
      try {
        final template = Template.fromCsvRowWithSettings(row, settings);
        if (template.gewerk.isNotEmpty && template.anlagentyp.isNotEmpty) {
          final parameterJson = _buildParameterJsonForRow(row, settings);
          await dbService.insertTemplate(
            projectId,
            template.gewerk,
            'a',
            template.anlagentyp,
            template.bezeichnung,
            parameterJson.isEmpty ? null : parameterJson,
          );
          
          uniqueGewerke.add(template.gewerk);
          validA++;
          count++;
        } else {
          skipped++;
        }
      } catch (e) {
        debugPrint('Fehler beim Parsen der Vorlage in Zeile ${i + 1}: $e');
        skipped++;
      }
    }

    debugPrint(
      'Vorlagen-Import abgeschlossen: projectId=$projectId, valid=$count, a=$validA, b=$validB, skipped=$skipped, delimiter=$delimiter, requiredMaxIndex=$requiredMaxIndex, uniqueGewerke=${uniqueGewerke.length}',
    );

    // Optional: Disziplin-Schemata aus Vorlagen synchronisieren,
    // aber keine neuen Gewerke mehr automatisch anlegen.
    if (buildingId != null) {
      try {
        await _syncDisciplineSchemasFromTemplates(dbService, buildingId, projectId);
      } catch (e) {
        debugPrint('Fehler beim Sync der Disziplinen aus Vorlagen: $e');
        // Fehler wird ignoriert, damit der Import nicht fehlschlägt
      }
    }

    return count;
  }

  /// Aktualisiert die Disziplin-Schemata aus den importierten Vorlagen (pro Revisionsobjekt).
  static Future<void> _syncDisciplineSchemasFromTemplates(
    DatabaseService dbService,
    String buildingId,
    String projectId,
  ) async {
    final disciplines = await dbService.getDisciplinesByBuildingId(buildingId);
    final templateRows = await dbService.getTemplatesByProjectId(projectId);
    final schemaByGewerkAndTyp = <String, Map<String, List<Map<String, dynamic>>>>{};

    for (final row in templateRows) {
      final gewerk = row.gewerk.trim();
      final typ = row.anlagentyp.trim();
      if (gewerk.isEmpty || typ.isEmpty) continue;
      final schema = getSchemaFromTemplateParameter(row.parameter);
      if (schema.isEmpty) continue;

      schemaByGewerkAndTyp.putIfAbsent(gewerk, () => {});
      final existing = schemaByGewerkAndTyp[gewerk]![typ] ?? const <Map<String, dynamic>>[];
      final byKey = <String, Map<String, dynamic>>{};
      for (final f in existing) {
        final key = (f['key'] ?? '').toString();
        if (key.isNotEmpty) byKey[key] = Map<String, dynamic>.from(f);
      }
      for (final f in schema) {
        final key = (f['key'] ?? '').toString();
        if (key.isEmpty) continue;
        byKey[key] = Map<String, dynamic>.from(f);
      }
      schemaByGewerkAndTyp[gewerk]![typ] = byKey.values.toList();
    }

    for (final d in disciplines) {
      final gewerkLabel = d.label.trim();
      final byTyp = schemaByGewerkAndTyp[gewerkLabel];
      if (byTyp == null || byTyp.isEmpty) continue;

      final globalFields = d.globalSchemaFields;
      final mergedRoSchemas = Map<String, List<Map<String, dynamic>>>.from(d.revisionsobjektSchemas);
      for (final entry in byTyp.entries) {
        mergedRoSchemas[entry.key] = entry.value.map((f) => Map<String, dynamic>.from(f)).toList();
      }

      d.revisionsobjektSchemas = mergedRoSchemas;
      d.schema = globalFields;
    }
    await dbService.replaceDisciplines(buildingId, disciplines);
    debugPrint('Disziplin-Schemata pro Revisionsobjekt synchronisiert für ${disciplines.length} Disziplinen.');
  }

  /// Lädt Vorlagen aus einer CSV-Datei (ohne Speichern in DB - für temporäre Verwendung)
  static Future<List<Template>> loadTemplatesFromFile(String? filePath, {String? projectId}) async {
    if (filePath == null || filePath.isEmpty) {
      // Versuche die Datei aus dem Standard-Pfad zu laden
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
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
    final csvData = CsvToListConverter(
      fieldDelimiter: delimiter,
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(csvString);

    if (csvData.isEmpty) {
      return [];
    }

    // Lade CSV-Einstellungen, falls projectId vorhanden
    Map<String, dynamic>? settings;
    if (projectId != null) {
      settings = await _loadTemplateCsvSettings(projectId);
    } else {
      // Erste Zeile ist der Header
      final headerRow = csvData[0].map((e) => e.toString().trim().toLowerCase()).toList();
      int? gewerkIdx;
      int? revisObjIdx;
      for (var i = 0; i < headerRow.length; i++) {
        final header = headerRow[i];
        if (header.contains('revisionsfeld') || header == 'gewerk' || header.contains('gewerk')) {
          gewerkIdx = i;
        } else if (header.contains('revisionsobjekt') || header.contains('anlagentyp')) {
          revisObjIdx = i;
        }
      }
      settings = {
        'gewerkSpalte': gewerkIdx ?? 0,
        'revisionsobjektSpalte': revisObjIdx ?? 1,
        'bezeichnungSpalte': revisObjIdx ?? 1,
        'ersteSpalteAttributDefinitionen': (revisObjIdx ?? 1) + 1,
        'attributeTripletColumns': <AttributeTripletColumn>[],
      };
    }

    // Parse Datenzeilen (Parameter = _schema aus Dreiergruppen Name/Typ/Optionen)
    final templates = <Template>[];
    for (var i = 1; i < csvData.length; i++) {
      final row = csvData[i];
      if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
        continue;
      }
      try {
        final parameterOverride = _buildParameterJsonForRow(row, settings);
        final template = Template.fromCsvRowWithSettings(row, settings);
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
        debugPrint('Fehler beim Parsen der Vorlage in Zeile ${i + 1}: $e');
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
    params['Anlagentyp'] = type;
    params['Revisionsobjekt'] = type;
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
          .where((e) => e.key != '_schema')
          .map((e) => MapEntry(e.key.toString(), e.value))
          .fold<Map<String, dynamic>>({}, (m, e) => m..[e.key] = e.value);
    } catch (_) {
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
    } catch (_) {
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

    // Flaches Schema direkt zusammenbauen – withEffectiveSchema würde bei fehlendem
    // Map-Eintrag sonst auf nur globale Felder zurückfallen.
    var flatSchema = mergeSchemaFieldLists(
      discipline.globalSchemaFields,
      roFields,
    );
    flatSchema = mergeSchemaFieldLists(flatSchema, discipline.schema);

    return Disziplin(
      label: discipline.label,
      icon: discipline.icon,
      color: discipline.color,
      schema: flatSchema,
      groupingKey: discipline.groupingKey,
      revisionsobjektSchemas: mergedRoSchemas,
    );
  }

  // Hinweis: Früher gab es hier eine Hilfsfunktion, die automatisch Disziplinen
  // aus den in den Vorlagen vorkommenden Gewerken erstellt hat.
  // Dieses Verhalten wurde entfernt, damit beim Vorlagen-Import
  // keine neuen Gewerke mehr ungefragt in der Technik-Übersicht entstehen.
}

