// lib/services/template_service.dart

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../database/database_service.dart';
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
      final typeStr = _safeCell(row, i + 1).toLowerCase();
      final optionsStr = _safeCell(row, i + 2);
      String type = 'text';
      if (typeStr == 'select' || typeStr == 'dropdown') {
        type = 'dropdown';
      } else if (typeStr == 'int' || typeStr == 'number') {
        type = 'number';
      } else if (typeStr.isNotEmpty) {
        type = typeStr;
      }
      final entry = <String, dynamic>{
        'key': name,
        'label': name,
        'type': type,
      };
      final options = _parseOptions(optionsStr);
      if (options.isNotEmpty) entry['options'] = options;
      schema.add(entry);
    }
    if (schema.isEmpty) return '';
    return json.encode({'_schema': schema});
  }

  /// Lädt die CSV-Einstellungen für Vorlagen
  static Future<Map<String, dynamic>> _loadTemplateCsvSettings(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'template_csv_settings_$projectId';
    final settingsJson = prefs.getString(key);
    
    if (settingsJson != null) {
      try {
        final settings = json.decode(settingsJson) as Map<String, dynamic>;
        return {
          'gewerkSpalte': settings['gewerkSpalte'] as int? ?? 0,
          'anlageBauteilSpalte': settings['anlageBauteilSpalte'] as int? ?? 1,
          'anlagentypSpalte': settings['anlagentypSpalte'] as int? ?? 2,
          'bezeichnungSpalte': settings['bezeichnungSpalte'] as int? ?? 3,
          'auswahlAnlagentypSpalte': settings['auswahlAnlagentypSpalte'] as int?,
          'ersteSpalteAttributDefinitionen': settings['ersteSpalteAttributDefinitionen'] as int? ?? 4,
        };
      } catch (e) {
        debugPrint('Fehler beim Laden der Vorlagen-CSV-Einstellungen: $e');
      }
    }
    
    return {
      'gewerkSpalte': 0,
      'anlageBauteilSpalte': 1,
      'anlagentypSpalte': 2,
      'bezeichnungSpalte': 3,
      'auswahlAnlagentypSpalte': null,
      'ersteSpalteAttributDefinitionen': 4,
    };
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
    final ersteSpalteAttribut = settings['ersteSpalteAttributDefinitionen'] as int? ?? 4;
    final columnIndices = {
      'gewerk': settings['gewerkSpalte'] as int,
      'anlageBauteil': settings['anlageBauteilSpalte'] as int,
      'anlagentyp': settings['anlagentypSpalte'] as int,
      'bezeichnung': settings['bezeichnungSpalte'] as int,
    };
    int requiredMaxIndex = columnIndices.values.fold<int>(0, (m, v) => v > m ? v : m);
    if (ersteSpalteAttribut + 2 > requiredMaxIndex) requiredMaxIndex = ersteSpalteAttribut + 2;

    // Delimiter-Sniffing mit zusätzlicher Prüfung: welche Variante liefert viele gültige a/b-Werte?
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
          // Muss mindestens bis zum Anlage/Bauteil-Index reichen
          if (row.length <= columnIndices['anlageBauteil']!) continue;
          if (row.length <= columnIndices['gewerk']!) continue;
          final gewerkVal = row[columnIndices['gewerk']!].toString().trim();
          final abVal = row[columnIndices['anlageBauteil']!].toString().trim().toLowerCase();
          if (gewerkVal.isEmpty) continue;
          if (abVal == 'a' || abVal == 'b') score++;
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
        final template = Template.fromCsvRow(row, columnIndices);
        final ab = template.anlageBauteil.trim().toLowerCase();
        final isValidAB = ab == 'a' || ab == 'b';
        if (template.gewerk.isNotEmpty && isValidAB) {
          final parameterJson = _buildParameterJsonFromAttributeTriplets(row, ersteSpalteAttribut);
          await dbService.insertTemplate(
            projectId,
            template.gewerk,
            ab,
            template.anlagentyp,
            template.bezeichnung,
            parameterJson.isEmpty ? null : parameterJson,
          );
          
          // Sammle Gewerke (für Disziplinen) bei jedem validen Datensatz
          uniqueGewerke.add(template.gewerk);
          if (ab == 'a') {
            validA++;
          } else {
            validB++;
          }
          
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

  /// Aktualisiert die Disziplin-Schemata aus den importierten Vorlagen (Attribut-Definitionen pro Gewerk).
  static Future<void> _syncDisciplineSchemasFromTemplates(
    DatabaseService dbService,
    String buildingId,
    String projectId,
  ) async {
    final disciplines = await dbService.getDisciplinesByBuildingId(buildingId);
    final templateRows = await dbService.getTemplatesByProjectId(projectId);
    final schemaByGewerk = <String, List<Map<String, dynamic>>>{};
    for (final row in templateRows) {
      final gewerk = row.gewerk.trim();
      if (gewerk.isEmpty) continue;
      final schema = getSchemaFromTemplateParameter(row.parameter);
      if (schema.isEmpty) continue;
      schemaByGewerk.putIfAbsent(gewerk, () => []).addAll(schema);
    }
    for (final d in disciplines) {
      final gewerkLabel = d.label.trim();
      final fromTemplates = schemaByGewerk[gewerkLabel];
      if (fromTemplates == null || fromTemplates.isEmpty) continue;
      final byKey = <String, Map<String, dynamic>>{};
      for (final f in fromTemplates) {
        final key = (f['key'] ?? '').toString();
        if (key.isEmpty) continue;
        if (!byKey.containsKey(key)) byKey[key] = Map<String, dynamic>.from(f);
      }
      final mergedSchema = byKey.values.toList();
      final mergedKeys = mergedSchema.map((f) => (f['key'] ?? '').toString()).toSet();
      final globalFields = d.schema.where((f) => f['isGlobal'] == true).map((f) => Map<String, dynamic>.from(f)).toList();
      final existingIndividual = d.schema
          .where((f) => f['isGlobal'] != true && !mergedKeys.contains((f['key'] ?? '').toString()))
          .map((f) => Map<String, dynamic>.from(f))
          .toList();
      d.schema = [...globalFields, ...mergedSchema, ...existingIndividual];
    }
    await dbService.replaceDisciplines(buildingId, disciplines);
    debugPrint('Disziplin-Schemata aus Vorlagen synchronisiert für ${disciplines.length} Disziplinen.');
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
    Map<String, int> columnIndices = {};
    int ersteSpalteAttribut = 4;
    if (projectId != null) {
      final settings = await _loadTemplateCsvSettings(projectId);
      ersteSpalteAttribut = settings['ersteSpalteAttributDefinitionen'] as int? ?? 4;
      columnIndices = {
        'gewerk': settings['gewerkSpalte'] as int,
        'anlageBauteil': settings['anlageBauteilSpalte'] as int,
        'anlagentyp': settings['anlagentypSpalte'] as int,
        'bezeichnung': settings['bezeichnungSpalte'] as int,
      };
    } else {
      // Erste Zeile ist der Header
      final headerRow = csvData[0].map((e) => e.toString().trim().toLowerCase()).toList();
      
      // Finde Spaltenindizes (ohne Parameter-Spalte; Attribute über Spaltenpaare)
      for (var i = 0; i < headerRow.length; i++) {
        final header = headerRow[i];
        if (header.contains('gewerk')) {
          columnIndices['gewerk'] = i;
        } else if (header.contains('anlage') && header.contains('bauteil')) {
          columnIndices['anlageBauteil'] = i;
        } else if (header.contains('anlagentyp')) {
          columnIndices['anlagentyp'] = i;
        } else if (header.contains('bezeichnung')) {
          columnIndices['bezeichnung'] = i;
        }
      }

      // Fallback: Wenn keine Header gefunden wurden, verwende Standard-Indizes
      if (columnIndices.isEmpty) {
        columnIndices = {
          'gewerk': 0,
          'anlageBauteil': 1,
          'anlagentyp': 2,
          'bezeichnung': 3,
        };
      }
    }

    // Parse Datenzeilen (Parameter = _schema aus Dreiergruppen Name/Typ/Optionen)
    final templates = <Template>[];
    for (var i = 1; i < csvData.length; i++) {
      final row = csvData[i];
      if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
        continue;
      }
      try {
        final parameterOverride = _buildParameterJsonFromAttributeTriplets(row, ersteSpalteAttribut);
        final template = Template.fromCsvRow(row, columnIndices, parameterOverride.isEmpty ? null : parameterOverride);
        if (template.gewerk.isNotEmpty) {
          templates.add(template);
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
      if (template.anlageBauteil != 'a') continue; // Nur Anlagen (nicht Bauteile)
      
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

  /// Extrahiert eindeutige Anlagentypen aus einer Liste von Templates
  /// Berücksichtigt nur Anlagen (anlageBauteil == 'a'), nicht Bauteile
  static List<String> getAnlagentypenForGewerk(List<Template> templates) {
    final anlagentypen = <String>{};
    for (final template in templates) {
      if (template.anlageBauteil == 'a' && template.anlagentyp.trim().isNotEmpty) {
        anlagentypen.add(template.anlagentyp.trim());
      }
    }
    return anlagentypen.toList()..sort();
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

  // Hinweis: Früher gab es hier eine Hilfsfunktion, die automatisch Disziplinen
  // aus den in den Vorlagen vorkommenden Gewerken erstellt hat.
  // Dieses Verhalten wurde entfernt, damit beim Vorlagen-Import
  // keine neuen Gewerke mehr ungefragt in der Technik-Übersicht entstehen.
}

