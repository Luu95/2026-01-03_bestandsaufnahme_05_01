// lib/services/csv_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import '../models/anlage.dart';
import '../models/disziplin_schnittstelle.dart';
import '../database/database.dart' as db;
import '../database/database_service.dart';
import '../providers/csv_settings_provider.dart';
import '../utils/app_log.dart';
import '../utils/csv_utils.dart';

// Debug-only: verhindert Logging in Release, ohne alle Call-Sites umzubauen.
void debugPrint(String? message, {int? wrapWidth}) => appLog(message ?? '');

/// Enum für die Ordnerstruktur beim Foto-Export
enum PhotoExportStructure {
  byAnlage,   // Fotos in Ordnern pro Anlage
  byGewerk,   // Fotos in Ordnern pro Gewerk
  allInOne,   // Alle Fotos in einem Ordner
}

class CsvService {
  static const String _delimiter = ';';
  static const Uuid _uuid = Uuid();

  /// Sortiert Anlagen für den Export so, dass Bauteile (child, parentId != null)
  /// direkt unter ihrer zugehörigen Anlage (parent) erscheinen.
  static List<Anlage> _orderAnlagenHierarchically(List<Anlage> anlagen) {
    final parentsInOrder = <String, Anlage>{};
    final parentOrder = <String>[];
    final childrenByParent = <String, List<Anlage>>{};
    final orphans = <Anlage>[];

    for (final a in anlagen) {
      final pid = a.parentId;
      if (pid == null || pid.isEmpty) {
        if (!parentsInOrder.containsKey(a.id)) {
          parentsInOrder[a.id] = a;
          parentOrder.add(a.id);
        }
      } else {
        (childrenByParent[pid] ??= <Anlage>[]).add(a);
      }
    }

    final ordered = <Anlage>[];
    for (final parentId in parentOrder) {
      final parent = parentsInOrder[parentId];
      if (parent == null) continue;
      ordered.add(parent);
      final kids = childrenByParent[parent.id];
      if (kids != null && kids.isNotEmpty) {
        ordered.addAll(kids);
      }
    }

    // Falls Kinder ohne Parent exportiert werden sollen (z.B. gefilterte Liste)
    // hängen wir sie am Ende an.
    final exportedIds = ordered.map((e) => e.id).toSet();
    for (final a in anlagen) {
      if (!exportedIds.contains(a.id)) {
        if (a.parentId != null && a.parentId!.isNotEmpty) {
          orphans.add(a);
        } else {
          ordered.add(a);
        }
      }
    }
    ordered.addAll(orphans);

    return ordered;
  }

  /// Importiert Anlagen aus einer CSV-Datei.
  /// 
  /// CSV-Struktur:
  /// - Spalte 0: Laufende Nummer (lfd Nummer) - zur Identifikation und Duplikat-Prüfung
  /// - Spalte 1: Anlagenname (Pflicht)
  /// - Spalte 2: Gewerk (Pflicht)
  /// - Spalte 3+: Alle weiteren Spalten werden als Parameter übernommen
  /// 
  /// [buildingIds]: Liste von BuildingIds, denen alle importierten Anlagen zugewiesen werden.
  ///                Wenn mehrere angegeben sind, werden die Anlagen allen zugewiesen.
  /// - Neue Gewerke erzeugen automatisch ein Disziplin-Objekt.
  /// Die laufende Nummer wird in den Params als "lfdNummer" gespeichert.
  static Future<List<db.AnlagenCompanion>> importAnlagenCsv({
    required DatabaseService dbService,
    List<String>? buildingIds,
  }) async {
    try {
      // Datei auswählen (alle Dateien anzeigen, Filter später validieren)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        throw Exception('Keine Datei ausgewählt');
      }

      final filePath = result.files.single.path!;
      final extensionOk = filePath.toLowerCase().endsWith('.csv');
      if (!extensionOk) {
        throw Exception('Bitte eine CSV-Datei auswählen');
      }
      final file = File(filePath);
      
      if (!await file.exists()) {
        throw Exception('Datei existiert nicht');
      }

      // CSV robust lesen (BOM/Encoding/EOL)
      final bytes = await file.readAsBytes();
      String csvString = CsvUtils.normalizeCsvStringFromBytes(bytes);
      
      // CSV parsen
      final csvData = const CsvToListConverter(
        fieldDelimiter: _delimiter,
        eol: '\n',
      ).convert(csvString);

      if (csvData.length < 2) {
        throw Exception('CSV-Datei benötigt mindestens Header und eine Datenzeile');
      }

      // Header lesen (falls vorhanden, wird für Parameter-Namen verwendet)
      final headerRow = csvData.first.map((e) => e.toString().trim()).toList();
      
      // Feste Spaltenpositionen:
      // Spalte 0 = Laufende Nummer (lfd Nummer)
      // Spalte 1 = Anlagenname
      // Spalte 2 = Gewerk
      // Spalte 3+ = Alle weiteren Spalten als Parameter
      const lfdNummerIdx = 0;
      const nameIdx = 1;
      const disciplineIdx = 2;

      final dataRows = csvData.sublist(1).where((row) => row.isNotEmpty).toList();
      if (dataRows.isEmpty) {
        throw Exception('Keine Datenzeilen gefunden');
      }

      // Parametrische Spalten: alles ab Spalte 3 - diese werden zum Schema der Disziplin
      final schemaColumns = <int, String>{};
      for (var i = 3; i < headerRow.length; i++) {
        final headerName = headerRow[i].trim();
        if (headerName.isNotEmpty) {
          schemaColumns[i] = headerName;
        } else {
          // Wenn Header leer, verwende generischen Namen
          schemaColumns[i] = 'Spalte_${i + 1}';
        }
      }

      // Schema aus CSV-Spalten erstellen (Format: List<Map<String, String>>)
      final schema = schemaColumns.values.map<Map<String, String>>((headerName) {
        // Versuche den Typ zu erraten basierend auf dem Namen
        final lowerName = headerName.toLowerCase();
        String type = 'string';
        if (lowerName.contains('leistung') || lowerName.contains('kw') || 
            lowerName.contains('kapazität') || lowerName.contains('kapazitaet') ||
            lowerName.contains('volumen') || lowerName.contains('fläche') ||
            lowerName.contains('flaeche') || lowerName.contains('temperatur') ||
            lowerName.contains('watt') || lowerName.contains('ampere') ||
            lowerName.contains('liter') || lowerName.contains('kwh') ||
            lowerName.contains('anzahl') || lowerName.contains('stück') ||
            lowerName.contains('stueck')) {
          type = 'int';
        }
        
        return <String, String>{
          'key': headerName,
          'label': headerName,
          'type': type,
        };
      }).toList();

      // Bestehende Disziplinen für alle Gebäude laden (für Icon/Color-Reuse)
      // Wenn mehrere buildingIds angegeben sind, verwenden wir das erste für die Disziplinen
      final targetBuildingIds = buildingIds ?? <String>[];
      final primaryBuildingId = targetBuildingIds.isNotEmpty ? targetBuildingIds.first : '';
      
      // Wenn keine buildingIds angegeben sind, können wir keine Disziplinen speichern
      // (alte Logik: globale Disziplinen - wird nicht mehr unterstützt)
      if (primaryBuildingId.isEmpty) {
        throw Exception('Keine BuildingIds angegeben. Disziplinen müssen einem Gebäude zugeordnet werden.');
      }
      
      final disciplineCache = await _loadPersistedDisciplines(dbService, primaryBuildingId);

      // Zuerst: Alle Disziplinen mit Schema aktualisieren
      final uniqueDisciplines = <String>{};
      for (var i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];
        final disciplineLabel = _safeCell(row, disciplineIdx);
        final disciplineLabelValue = disciplineLabel.isEmpty ? 'Allgemein' : disciplineLabel;
        uniqueDisciplines.add(disciplineLabelValue);
      }

      // Disziplinen mit Schema erstellen/aktualisieren
      for (final discLabel in uniqueDisciplines) {
        final existing = disciplineCache[discLabel.toLowerCase()];
        if (existing == null) {
          // Neue Disziplin mit Schema aus CSV erstellen
          final newDiscipline = Disziplin(
            label: discLabel,
            icon: Icons.build,
            color: Colors.blueGrey,
            schema: schema,
          );
          disciplineCache[discLabel.toLowerCase()] = newDiscipline;
        } else {
          // Bestehende Disziplin: Schema aus CSV übernehmen (kann später manuell angepasst werden)
          // Icon und Farbe beibehalten, nur Schema aktualisieren
          existing.schema = schema;
          disciplineCache[discLabel.toLowerCase()] = existing;
        }
      }

      final companions = <db.AnlagenCompanion>[];
      for (var i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];

        // Laufende Nummer aus Spalte 0
        final lfdNummer = _safeCell(row, lfdNummerIdx);
        final lfdNummerValue = lfdNummer.trim();

        // Feste Spaltenpositionen lesen
        // Name: NUR aus Spalte 1
        final name = _safeCell(row, nameIdx);
        final nameValue = name.isEmpty ? 'Anlage_${i + 1}' : name.trim(); // Default wenn leer
        
        // Gewerk: NUR aus Spalte 2
        final disciplineLabel = _safeCell(row, disciplineIdx);
        final disciplineLabelValue = disciplineLabel.isEmpty ? 'Allgemein' : disciplineLabel.trim();
        
        // Parameter: NUR aus Spalten ab Index 3 (Werte aus CSV)
        final params = _parseParamsFromRow(row, schemaColumns);
        // Laufende Nummer zu den Parametern hinzufügen
        if (lfdNummerValue.isNotEmpty) {
          params['lfdNummer'] = lfdNummerValue;
        }

        final discipline = disciplineCache[disciplineLabelValue.toLowerCase()]!;
        
        // Sicherstellen, dass die Disziplin ein Schema hat
        if (discipline.schema.isEmpty && schema.isNotEmpty) {
          discipline.schema = schema;
          disciplineCache[disciplineLabelValue.toLowerCase()] = discipline;
        }

        // Für jedes angegebene BuildingId eine Anlage erstellen
        for (final bid in targetBuildingIds) {
          companions.add(
            db.AnlagenCompanion.insert(
              id: _uuid.v4(),
              name: nameValue,//
              params: json.encode(params),
              floorId: const Value.absent(),
              buildingId: bid,
              isMarker: false,
              markerInfo: const Value.absent(),
              markerType: discipline.label,
              discipline: json.encode(discipline.toJson()),
            ),
          );
        }
      }

      // Disziplinen für alle angegebenen Gebäude persistieren
      // (gleiche Disziplinen für alle Gebäude)
      for (final bid in targetBuildingIds) {
        await _persistDisciplines(dbService, bid, disciplineCache.values.toList());
      }

      return companions;
    } catch (e) {
      throw Exception('Fehler beim CSV-Import: $e');
    }
  }

  // ---- Helfer für strukturellen Import ----

  static String _safeCell(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index].toString().trim();
  }

  static Map<String, dynamic> _parseParamsFromRow(List<dynamic> row, Map<int, String> paramColumns) {
    final params = <String, dynamic>{};
    paramColumns.forEach((idx, key) {
      final raw = _safeCell(row, idx);
      if (raw.isEmpty) return;
      params[key] = _parseDynamicValue(raw);
    });
    return params;
  }

  static List<String> _parseKuerzel(String? raw, List<String> fallback) {
    final tokens = (raw ?? '')
        .split(RegExp(r'[,;]'))
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return fallback;
    return tokens;
  }

  static bool _matchesAnyToken(String value, List<String> tokens) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    for (final token in tokens) {
      if (token.isEmpty) continue;
      if (normalized == token || normalized.startsWith(token)) {
        return true;
      }
    }
    return false;
  }

  static dynamic _parseDynamicValue(String value) {
    final lower = value.toLowerCase();
    if (lower == 'true' || lower == 'false') {
      return lower == 'true';
    }
    final intVal = int.tryParse(value);
    if (intVal != null) return intVal;
    final doubleVal = double.tryParse(value.replaceAll(',', '.'));
    if (doubleVal != null) return doubleVal;

    // Falls JSON Map/List übergeben wurde, versuchen zu parsen
    if ((value.startsWith('{') && value.endsWith('}')) ||
        (value.startsWith('[') && value.endsWith(']'))) {
      try {
        return json.decode(value);
      } catch (_) {
        // Ignorieren, wir fallen zurück auf String
      }
    }
    return value;
  }

  static Future<Map<String, Disziplin>> _loadPersistedDisciplines(
    DatabaseService dbService,
    String buildingId,
  ) async {
    final list = await dbService.getDisciplinesByBuildingId(buildingId);
    final map = <String, Disziplin>{};
    for (final disc in list) {
      map[disc.label.toLowerCase()] = disc;
    }
    return map;
  }

  static Future<void> _persistDisciplines(
    DatabaseService dbService,
    String buildingId,
    List<Disziplin> disciplines,
  ) async {
    await dbService.replaceDisciplines(buildingId, disciplines);
  }

  /// Lädt die CSV-Einstellungen für ein bestimmtes Projekt.
  /// Gibt die Standardwerte zurück, wenn keine Einstellungen gefunden werden.
  static Future<Map<String, dynamic>> _loadCsvSettings(String projectId) async {
    final cached = CsvSettingsCache.get(projectId);
    if (cached != null) {
      return cached.toJson();
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'csv_settings_$projectId';
    final settingsJson = prefs.getString(key);
    
    if (settingsJson != null) {
      try {
        final settings = json.decode(settingsJson) as Map<String, dynamic>;
        return {
          'lfdNummerSpalte': settings['lfdNummerSpalte'] as int? ?? 0,
          'nameSpalte': settings['nameSpalte'] as int? ?? 1,
          'gewerkSpalte': settings['gewerkSpalte'] as int? ?? 2,
          'etageSpalte': settings['etageSpalte'] as int?,
          'anlageBauteilSpalte': settings['anlageBauteilSpalte'] as int?,
          'parameterSpalte': settings['parameterSpalte'] as int?,
          'delimiterMode': settings['delimiterMode'] as String? ?? 'auto',
          'anlageKuerzel': settings['anlageKuerzel'] as String? ?? 'A,Anlage',
          'bauteilKuerzel': settings['bauteilKuerzel'] as String? ?? 'B,Bauteil',
          'useDisciplineGrouping': settings['useDisciplineGrouping'] as bool? ?? true,
          'labelGewerk': settings['labelGewerk'] as String? ?? 'Gewerk',
          'labelAnlage': settings['labelAnlage'] as String? ?? 'Anlage',
          'labelBauteil': settings['labelBauteil'] as String? ?? 'Bauteil',
          'headerZeile': settings['headerZeile'] as int? ?? 1,
        };
      } catch (e) {
        debugPrint('Fehler beim Laden der CSV-Einstellungen: $e');
      }
    }
    
    // Standardwerte
    return {
      'lfdNummerSpalte': 0,
      'nameSpalte': 1,
      'gewerkSpalte': 2,
      'etageSpalte': null,
      'anlageBauteilSpalte': null,
      'parameterSpalte': null,
      'delimiterMode': 'auto',
      'anlageKuerzel': 'A,Anlage',
      'bauteilKuerzel': 'B,Bauteil',
      'useDisciplineGrouping': true,
      'labelGewerk': 'Gewerk',
      'labelAnlage': 'Anlage',
      'labelBauteil': 'Bauteil',
      'headerZeile': 1,
    };
  }

  static Future<List<Map<String, dynamic>>> _loadGlobalSchema(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'global_schema_$projectId';
    final schemaJson = prefs.getString(key);
    if (schemaJson == null || schemaJson.trim().isEmpty) return [];
    try {
      return (json.decode(schemaJson) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('Fehler beim Laden des globalen Schemas: $e');
      return [];
    }
  }

  static Future<void> _saveGlobalSchema(String projectId, List<Map<String, dynamic>> schema) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'global_schema_$projectId';
      await prefs.setString(key, json.encode(schema));
    } catch (e) {
      debugPrint('Fehler beim Speichern des globalen Schemas: $e');
    }
  }

  /// Importiert Anlagen aus CSV und aktualisiert Disziplinen-Schema.
  /// 
  /// Die Spaltenzuordnung (lfd Nummer, Name, Gewerk) kann pro Gebäude in den
  /// CSV-Einstellungen konfiguriert werden. Standardwerte:
  /// - Spalte 0: Laufende Nummer (lfd Nummer)
  /// - Spalte 1: Anlagenname
  /// - Spalte 2: Disziplinname (Gewerk)
  /// - Ab der nächsten Spalte: Parameter (werden zu Schema-Einträgen der Disziplin)
  /// 
  /// Die erste Zeile (Header) definiert die Spaltennamen für die Parameter.
  /// Disziplinen, die in der CSV vorkommen, bekommen ihr Schema aus den Parameter-Spalten.
  /// Disziplinen, die nicht in der CSV vorkommen, bleiben unverändert.
  /// 
  /// [buildingId]: BuildingId, dem die importierten Anlagen zugewiesen werden.
  /// [projectId]: ProjectId, für die CSV-Einstellungen (projektbezogen).
  /// 
  /// Gibt eine Liste von Anlagen zurück, die dann in der Datenbank gespeichert werden können.
  /// Die laufende Nummer wird in den Params als "lfdNummer" gespeichert.
  static Future<List<Anlage>> importAnlagenCsvForDisciplines({
    required DatabaseService dbService,
    required String buildingId,
    required String projectId,
    String floorId = 'global',
  }) async {
    try {
      // Datei auswählen
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        throw Exception('Keine Datei ausgewählt');
      }

      final filePath = result.files.single.path!;
      final extensionOk = filePath.toLowerCase().endsWith('.csv');
      if (!extensionOk) {
        throw Exception('Bitte eine CSV-Datei auswählen');
      }
      final file = File(filePath);
      
      if (!await file.exists()) {
        throw Exception('Datei existiert nicht');
      }

      // CSV robust lesen (BOM/Encoding/EOL)
      final bytes = await file.readAsBytes();
      String csvString = CsvUtils.normalizeCsvStringFromBytes(bytes);
      
      // CSV-Einstellungen für dieses Projekt laden
      final csvSettings = await _loadCsvSettings(projectId);
      final lfdNummerIdx = csvSettings['lfdNummerSpalte']!;
      final nameIdx = csvSettings['nameSpalte']!;
      final disciplineIdx = csvSettings['gewerkSpalte']!;
      final etageIdx = csvSettings['etageSpalte'] as int?;
      final anlageBauteilIdx = csvSettings['anlageBauteilSpalte'] as int?;
      final configuredParameterIdx = csvSettings['parameterSpalte'] as int?;
      final delimiterMode = csvSettings['delimiterMode'] as String? ?? 'auto';
      final headerZeile = csvSettings['headerZeile'] as int? ?? 1;
      final useDisciplineGrouping = csvSettings['useDisciplineGrouping'] as bool? ?? true;

      // Trennzeichen: Auto oder explizit
      String delimiter = _delimiter;
      if (delimiterMode == 'auto') {
        final firstLine = csvString.split('\n').first;
        delimiter = CsvUtils.detectDelimiterFromLine(firstLine);
      } else {
        delimiter = delimiterMode;
      }
      
      // CSV parsen
      final csvData = CsvToListConverter(
        fieldDelimiter: delimiter,
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csvString);

      if (csvData.isEmpty) {
        throw Exception('CSV-Datei ist leer');
      }

      // Header-Zeile bestimmen (1-basiert für User, 0-basiert für Array)
      final headerRowIndex = headerZeile - 1;
      if (headerRowIndex < 0 || headerRowIndex >= csvData.length) {
        throw Exception('Header-Zeile $headerZeile existiert nicht in der CSV (${csvData.length} Zeilen gefunden)');
      }

      // Mindestens Header-Zeile + eine Datenzeile nach dem Header
      if (csvData.length < headerRowIndex + 2) {
        throw Exception('CSV-Datei benötigt mindestens Header-Zeile ($headerZeile) und eine Datenzeile (gefunden: ${csvData.length} Zeilen)');
      }

      // Header lesen (aus konfigurierter Zeile)
      final headerRow = csvData[headerRowIndex].map((e) => e.toString().trim()).toList();
      
      // Debug: Header ausgeben
      debugPrint('CSV Header: $headerRow');
      debugPrint('Anzahl Header-Spalten: ${headerRow.length}');
      
      final anlageKuerzel = _parseKuerzel(csvSettings['anlageKuerzel'] as String?, ['a', 'anlage']);
      final bauteilKuerzel = _parseKuerzel(csvSettings['bauteilKuerzel'] as String?, ['b', 'bauteil']);

      debugPrint(
        'CSV-Einstellungen: lfdNummer=$lfdNummerIdx, name=$nameIdx, gewerk=$disciplineIdx, '
        'etage=$etageIdx, anlageBauteil=$anlageBauteilIdx, parameter=$configuredParameterIdx, '
        'delimiter=$delimiter, anlageKuerzel=$anlageKuerzel, bauteilKuerzel=$bauteilKuerzel, '
        'useDisciplineGrouping=$useDisciplineGrouping',
      );

      // Datenzeilen: alle Zeilen nach der Header-Zeile
      final dataRows = csvData.sublist(headerRowIndex + 1).where((row) => row.isNotEmpty && row.any((cell) => cell.toString().trim().isNotEmpty)).toList();
      if (dataRows.isEmpty) {
        throw Exception('Keine Datenzeilen gefunden');
      }

      debugPrint('Anzahl Datenzeilen: ${dataRows.length}');

      // Schema aus CSV-Spalten erstellen (alle Spalten in Original-Reihenfolge)
      final schemaColumns = <int, String>{};
      for (var i = 0; i < headerRow.length; i++) {
        final headerName = headerRow[i].trim();
        if (headerName.isNotEmpty) {
          schemaColumns[i] = headerName;
        } else {
          schemaColumns[i] = 'Spalte_${i + 1}';
        }
      }

      // Schema-Einträge erstellen
      final schemaFromCsv = <Map<String, dynamic>>[];
      for (var i = 0; i < headerRow.length; i++) {
        final headerName = schemaColumns[i]!;
        final lowerName = headerName.toLowerCase();
        
        String type = 'text';
        if (lowerName.contains('leistung') || lowerName.contains('kw') || 
            lowerName.contains('kapazität') || lowerName.contains('volumen') ||
            lowerName.contains('anzahl') || lowerName.contains('jahr')) {
          type = 'number';
        }
        
        schemaFromCsv.add({
          'key': headerName,
          'label': headerName,
          'type': type,
        });
      }

      debugPrint('Vollständiges Schema aus CSV erstellt: $schemaFromCsv');

      debugPrint('Erstelltes Schema: $schemaFromCsv');

      // Bestehende Disziplinen für dieses Gebäude laden
      final disciplineCache = await _loadPersistedDisciplines(dbService, buildingId);
      debugPrint('Bestehende Disziplinen für Gebäude $buildingId: ${disciplineCache.keys.toList()}');

      // Alle eindeutigen Disziplinen aus CSV sammeln
      final uniqueDisciplines = <String>{};
      for (var i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];
        final disciplineLabel = useDisciplineGrouping
            ? _safeCell(row, disciplineIdx)
            : 'Inventur';
        final disciplineLabelValue = disciplineLabel.trim();
        if (disciplineLabelValue.isNotEmpty) {
          uniqueDisciplines.add(disciplineLabelValue);
        }
      }

      debugPrint('Gefundene Disziplinen in CSV: $uniqueDisciplines');

      // Globales Standard-Schema: aus CSV ableiten (aber bestehende globale Einstellungen behalten)
      final existingGlobalSchemaRaw = await _loadGlobalSchema(projectId);
      final existingGlobalSchema = existingGlobalSchemaRaw
          .map((f) => {...Map<String, dynamic>.from(f), 'isGlobal': true})
          .toList();
      final existingGlobalKeys = existingGlobalSchema
          .map((f) => (f['key'] ?? '').toString())
          .where((k) => k.isNotEmpty)
          .toSet();

      // Fallback: Falls ein Feld bereits in einem Gewerk existiert (z.B. typ/editable angepasst),
      // übernehmen wir diese Definition bevorzugt ins globale Schema, wenn es dort noch fehlt.
      final fallbackFieldByKey = <String, Map<String, dynamic>>{};
      for (final d in disciplineCache.values) {
        for (final field in d.schema) {
          final key = (field['key'] ?? '').toString();
          if (key.isEmpty) continue;
          fallbackFieldByKey.putIfAbsent(key, () => Map<String, dynamic>.from(field));
        }
      }

      final mergedGlobalSchema = [...existingGlobalSchema];
      final mergedGlobalKeys = {...existingGlobalKeys};
      for (final field in schemaFromCsv) {
        final key = (field['key'] ?? '').toString();
        if (key.isEmpty || mergedGlobalKeys.contains(key)) continue;
        final fallback = fallbackFieldByKey[key];
        final toAdd = fallback != null ? Map<String, dynamic>.from(fallback) : Map<String, dynamic>.from(field);
        toAdd['isGlobal'] = true;
        mergedGlobalSchema.add(toAdd);
        mergedGlobalKeys.add(key);
      }

      // Speichere globales Schema projektbezogen
      await _saveGlobalSchema(projectId, mergedGlobalSchema);

      // Stelle sicher, dass alle in der CSV vorkommenden Gewerke existieren (Schema bleibt individuell erweiterbar)
      for (final discLabel in uniqueDisciplines) {
        final discLabelLower = discLabel.toLowerCase();
        final existing = disciplineCache[discLabelLower];
        if (existing != null) continue;
        disciplineCache[discLabelLower] = Disziplin(
          label: discLabel,
          icon: Icons.build,
          color: Colors.blueGrey,
          schema: <Map<String, dynamic>>[],
        );
        debugPrint('Neue Disziplin erstellt (ohne individuelles Schema): $discLabel');
      }

      // Globales Schema in alle Disziplinen syncen (Global zuerst, danach echte individuelle Felder)
      for (final entry in disciplineCache.entries) {
        final d = entry.value;
        final individualFields = d.schema.where((f) => f['isGlobal'] != true).map((f) => Map<String, dynamic>.from(f)).toList();
        individualFields.removeWhere((f) => mergedGlobalKeys.contains((f['key'] ?? '').toString()));
        d.schema = [...mergedGlobalSchema, ...individualFields];
      }

      // Disziplinen für dieses Gebäude persistieren
      await _persistDisciplines(dbService, buildingId, disciplineCache.values.toList());
      debugPrint('Disziplinen für Gebäude $buildingId gespeichert (global gesynct): ${disciplineCache.length}');

      // Anlagen aus CSV erstellen
      final anlagen = <Anlage>[];
      for (var i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];

        // Laufende Nummer aus Spalte 0 (A = "lfd Nummer")
        final lfdNummer = _safeCell(row, lfdNummerIdx);
        if (lfdNummer.isEmpty) {
          debugPrint('Zeile ${i + 1} übersprungen: Keine laufende Nummer angegeben');
          continue; // Zeile überspringen, wenn keine laufende Nummer angegeben
        }
        final lfdNummerValue = lfdNummer.trim();

        // Anlagenname aus Spalte 1 (B = "name")
        final name = _safeCell(row, nameIdx);
        final nameValue = name.isEmpty ? 'Anlage_${i + 1}' : name.trim();
        
        // Disziplinname aus Spalte 2 (C = "Gewerk")
        final disciplineLabel = useDisciplineGrouping
            ? _safeCell(row, disciplineIdx)
            : 'Inventur';
        if (disciplineLabel.isEmpty) {
          debugPrint('Zeile ${i + 1} übersprungen: Keine Disziplin angegeben');
          continue; // Zeile überspringen, wenn keine Disziplin angegeben
        }
        final disciplineLabelValue = disciplineLabel.trim();
        
        // Etage aus konfigurierter Spalte lesen (falls vorhanden)
        String? etageValue;
        if (etageIdx != null) {
          etageValue = _safeCell(row, etageIdx).trim();
        }
        
        // Anlage/Bauteil aus konfigurierter Spalte lesen (falls vorhanden)
        String? anlageBauteilValue;
        if (anlageBauteilIdx != null) {
          anlageBauteilValue = _safeCell(row, anlageBauteilIdx).trim();
        }
        
        // Parameter aus allen Spalten lesen (Schema = Header)
        final params = _parseParamsFromRow(row, schemaColumns);
        
        // CSV-Mapping für die App-Logik anwenden
        // Die lfdNummer wird zur Identifikation benötigt
        if (lfdNummerValue.isNotEmpty) {
          params['lfdNummer'] = lfdNummerValue;
        }
        
        // Etage explizit setzen (falls aus Mapping-Spalte gelesen)
        if (etageValue != null && etageValue.isNotEmpty) {
          params['Etage'] = etageValue;
          params['__etageName'] = etageValue; // Für Kompatibilität
        }
        
        // Anlage/Bauteil explizit setzen (falls aus Mapping-Spalte gelesen)
        // Unterstütze beide Schreibweisen für Kompatibilität
        if (anlageBauteilValue != null && anlageBauteilValue.isNotEmpty) {
          params['Anlage/Bauteil'] = anlageBauteilValue;
          params['Anlage/Bautel'] = anlageBauteilValue; // Alte Schreibweise für Kompatibilität
        }

        // Leistungsparameter-Logik für Spezial-Feld beibehalten (falls konfiguriert)
        int? leistungsparameterIdx = configuredParameterIdx;
        if (leistungsparameterIdx != null) {
          final lpRaw = _safeCell(row, leistungsparameterIdx);
          if (lpRaw.isNotEmpty) {
            final Map<String, String> lpMap = {};
            for (var label in lpRaw.split(RegExp(r'[,;]')).map((e) => e.trim()).where((e) => e.isNotEmpty)) {
              if (label.contains(':')) {
                final parts = label.split(':');
                lpMap[parts[0].trim()] = parts.sublist(1).join(':').trim();
              } else {
                lpMap[label] = '';
              }
            }
            params['Leistungsparameter'] = lpMap;
          }
        }
        debugPrint('Anlage $nameValue (lfd Nummer: $lfdNummerValue): Disziplin=$disciplineLabelValue, Etage=$etageValue, Anlage/Bauteil=$anlageBauteilValue, Parameter=$params');

        final discipline = disciplineCache[disciplineLabelValue.toLowerCase()];
        if (discipline == null) {
          debugPrint('Zeile ${i + 1} übersprungen: Disziplin "$disciplineLabelValue" nicht gefunden');
          continue; // Disziplin nicht gefunden, Zeile überspringen
        }

        // Hierarchie NICHT über IDs im Parser lösen (die ändern sich beim Update via lfdNummer).
        // Stattdessen Parent-LfdNummer in Params merken; die finale parentId wird beim Speichern gesetzt.
        // Unterstütze beide Schreibweisen: "Anlage/Bauteil" und "Anlage/Bautel"
        final anlageBautel = (params['Anlage/Bauteil'] ?? params['Anlage/Bautel'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final isBauteil = _matchesAnyToken(anlageBautel, bauteilKuerzel);

        if (isBauteil) {
          String? parentLfd;
          // Suche rückwärts nach der letzten Anlage (A) im gleichen Gewerk
          // Priorität: 1) Gleiches Gewerk + Typ A, 2) Gleiches Gewerk + kein Typ B, 3) Gleiches Gewerk (egal welcher Typ)
          for (int j = anlagen.length - 1; j >= 0; j--) {
            final existing = anlagen[j];
            // Nur im gleichen Gewerk suchen
            if (existing.discipline.label != discipline.label) continue;
            
            final existingLfd = existing.params['lfdNummer']?.toString();
            if (existingLfd == null || existingLfd.isEmpty) continue;
            
            // Unterstütze beide Schreibweisen
            final existingType = (existing.params['Anlage/Bauteil'] ?? existing.params['Anlage/Bautel'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            final existingIsBauteil = _matchesAnyToken(existingType, bauteilKuerzel);
            
            // Überspringe andere Bauteile
            if (existingIsBauteil) continue;
            
            // Gefunden: Letzte Anlage (A oder leer) im gleichen Gewerk
            parentLfd = existingLfd;
            break;
          }
          
          if (parentLfd != null) {
            params['__parentLfdNummer'] = parentLfd;
            debugPrint('Bauteil $nameValue (lfd: $lfdNummerValue) -> Parent: $parentLfd (Gewerk: ${discipline.label})');
          } else {
            debugPrint('WARNUNG: Bauteil $nameValue (lfd: $lfdNummerValue, Gewerk: ${discipline.label}) hat kein Parent gefunden!');
          }
        }

        // Anlage erstellen
        final anlage = Anlage(
          id: _uuid.v4(),
          name: nameValue,
          params: params,
          floorId: floorId,
          buildingId: buildingId,
          isMarker: false,
          markerInfo: null,
          markerType: discipline.label,
          discipline: discipline,
          parentId: null, // Wird beim Speichern anhand __parentLfdNummer gesetzt
        );

        anlagen.add(anlage);
      }

      debugPrint('Insgesamt ${anlagen.length} Anlagen erstellt');
      return anlagen;
    } catch (e, stackTrace) {
      debugPrint('CSV-Import Fehler: $e');
      debugPrint('Stack Trace: $stackTrace');
      throw Exception('Fehler beim CSV-Import: $e');
    }
  }

  /// Exportiert Anlagen zu einer CSV-Datei und teilt sie
  /// 
  /// CSV-Format:
  /// Name;BuildingId;FloorId;IsMarker;MarkerType;DisciplineLabel;Params;MarkerInfo
  static Future<void> exportAnlagenToCsv(List<Anlage> anlagen) async {
    if (anlagen.isEmpty) {
      throw Exception('Keine Anlagen zum Exportieren vorhanden');
    }

    try {
      // CSV-Daten erstellen
      final csvData = <List<String>>[];

      // Header-Zeile
      csvData.add([
        'Name',
        'BuildingId',
        'FloorId',
        'IsMarker',
        'MarkerType',
        'DisciplineLabel',
        'Params',
        'MarkerInfo',
      ]);

      // Daten-Zeilen
      for (final anlage in anlagen) {
        csvData.add([
          anlage.name,
          anlage.buildingId,
          anlage.floorId,
          anlage.isMarker.toString(),
          anlage.markerType,
          anlage.discipline.label,
          json.encode(anlage.params),
          anlage.markerInfo != null ? json.encode(anlage.markerInfo) : '',
        ]);
      }

      // CSV-String erstellen
      final csvString = const ListToCsvConverter(
        fieldDelimiter: _delimiter,
        eol: '\n',
      ).convert(csvData);

      // Temporäre Datei erstellen
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/anlagen_export_$timestamp.csv');
      await file.writeAsString(csvString);

      // Datei teilen
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Anlagen-Export',
        subject: 'Anlagen CSV Export',
      );
    } catch (e) {
      throw Exception('Fehler beim CSV-Export: $e');
    }
  }

  /// Exportiert Anlagen zu einer CSV-Datei im gleichen Format wie der Import
  /// 
  /// CSV-Struktur (Standard-Format wie beim Import):
  /// - Spalte 0: Laufende Nummer (lfd Nummer) - aus params['lfdNummer']
  /// - Spalte 1: Anlagenname
  /// - Spalte 2: Gewerk (Disziplin-Label)
  /// - Spalte 3+: Alle weiteren Spalten als Parameter (basierend auf Schema der Disziplin)
  /// 
  /// [anlagen]: Liste von Anlagen, die exportiert werden sollen
  /// [projectId]: ProjectId (aktuell nicht verwendet, aber für zukünftige Erweiterungen bereitgehalten)
  /// 
  /// Alle Parameter aus dem Schema der Disziplin werden als zusätzliche Spalten hinzugefügt.
  static Future<void> exportAnlagenCsvForDisciplines({
    required List<Anlage> anlagen,
    required String projectId,
  }) async {
    if (anlagen.isEmpty) {
      throw Exception('Keine Anlagen zum Exportieren vorhanden');
    }

    try {
      // CSV-Daten erstellen
      final csvData = <List<String>>[];

      // Nutze das Schema der ersten Anlage für die Header-Reihenfolge
      // Da alle Anlagen einer Disziplin beim Import das gleiche Schema erhalten haben,
      // entspricht dies der Original-Reihenfolge der CSV.
      final exportSchema = anlagen.first.discipline.schema;
      final headerRow = exportSchema.map((e) => e['label'] as String).toList();
      
      // Foto-Spalten hinzufügen
      headerRow.addAll(['Foto1', 'Foto2', 'Foto3', 'Foto4']);
      csvData.add(headerRow);

      debugPrint('CSV Header: $headerRow');

      // Hierarchisch anordnen: Parent-Anlage, dann Bauteile darunter
      final orderedAnlagen = _orderAnlagenHierarchically(anlagen);

      // Daten-Zeilen
      for (final anlage in orderedAnlagen) {
        final dataRow = <String>[];

        // Alle Felder laut Schema exportieren
        for (final field in exportSchema) {
          final key = field['key'] as String;
          final val = anlage.params[key];
          
          if (val == null) {
            dataRow.add('');
          } else if (val is Map || val is List) {
            dataRow.add(json.encode(val));
          } else {
            dataRow.add(val.toString());
          }
        }

        // Fotonummern hinzufügen (werden später beim ZIP-Export befüllt)
        dataRow.addAll(['', '', '', '']);

        csvData.add(dataRow);
      }

      // CSV-String erstellen (UTF-8 mit BOM für Excel-Kompatibilität)
      final csvString = const ListToCsvConverter(
        fieldDelimiter: _delimiter,
        eol: '\n',
      ).convert(csvData);

      // UTF-8 BOM hinzufügen (für Excel-Kompatibilität)
      final utf8Bom = [0xEF, 0xBB, 0xBF];
      final csvBytes = utf8Bom + utf8.encode(csvString);

      // Temporäre Datei erstellen
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/anlagen_export_$timestamp.csv');
      await file.writeAsBytes(csvBytes);

      debugPrint('CSV-Export abgeschlossen: ${csvData.length - 1} Anlagen exportiert');

      // Datei teilen
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Anlagen-Export',
        subject: 'Anlagen CSV Export',
      );
    } catch (e, stackTrace) {
      debugPrint('CSV-Export Fehler: $e');
      debugPrint('Stack Trace: $stackTrace');
      throw Exception('Fehler beim CSV-Export: $e');
    }
  }

  /// Exportiert Anlagen mit Fotos in ein ZIP-Archiv
  /// 
  /// Erstellt eine CSV-Datei mit 4 Fotonummern-Spalten (Format: 0001-9999)
  /// und exportiert die Fotos in der gewählten Ordnerstruktur.
  /// 
  /// [anlagen]: Liste von Anlagen, die exportiert werden sollen
  /// [projectId]: ProjectId
  /// [structure]: Ordnerstruktur für die Fotos (Anlagen/Gewerke/Alle)
  static Future<void> exportAnlagenWithPhotos({
    required List<Anlage> anlagen,
    required String projectId,
    required PhotoExportStructure structure,
  }) async {
    if (anlagen.isEmpty) {
      throw Exception('Keine Anlagen zum Exportieren vorhanden');
    }

    try {
      // Temporäres Verzeichnis für Export erstellen
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final exportDir = Directory('${tempDir.path}/anlagen_export_$timestamp');
      await exportDir.create(recursive: true);

      // Globaler Zähler für Fotonummern (0001, 0002, etc.)
      int fotoCounter = 1;

      // CSV-Daten erstellen
      final csvData = <List<String>>[];

      // Nutze das Schema der ersten Anlage für die Header-Reihenfolge
      final exportSchema = anlagen.first.discipline.schema;
      final headerRow = exportSchema.map((e) => e['label'] as String).toList();
      
      // Foto-Spalten hinzufügen
      headerRow.addAll(['Foto1', 'Foto2', 'Foto3', 'Foto4']);
      csvData.add(headerRow);

      // Zähler für neue Anlagen ohne lfdNummer
      int neueAnlagenZaehler = 1;

      // Fotos-Ordner erstellen basierend auf Struktur
      Directory fotosDir = Directory('${exportDir.path}/fotos');
      await fotosDir.create(recursive: true);

      // Map für Gewerk-Ordner (bei byGewerk)
      final Map<String, Directory> gewerkDirs = {};

      // Hierarchisch anordnen: Parent-Anlage, dann Bauteile darunter
      final orderedAnlagen = _orderAnlagenHierarchically(anlagen);

      // Verarbeite jede Anlage
      for (final anlage in orderedAnlagen) {
        final dataRow = <String>[];

        // Alle Felder laut Schema exportieren
        for (final field in exportSchema) {
          final key = field['key'] as String;
          final val = anlage.params[key];
          
          if (val == null) {
            dataRow.add('');
          } else if (val is Map || val is List) {
            dataRow.add(json.encode(val));
          } else {
            dataRow.add(val.toString());
          }
        }

        // lfdNummer für Dateinamen holen
        String lfdNummer = anlage.params['lfdNummer']?.toString() ?? '';
        if (lfdNummer.isEmpty) {
          lfdNummer = 'Neu_${neueAnlagenZaehler.toString().padLeft(4, '0')}';
          neueAnlagenZaehler++;
        }

        // Fotos verarbeiten
        final photoPaths = anlage.params['photoPaths'] as List<dynamic>?;
        final fotoNumbers = <String>[];

        if (photoPaths != null && photoPaths.isNotEmpty) {
          // Maximal 4 Fotos pro Anlage
          final maxFotos = photoPaths.length > 4 ? 4 : photoPaths.length;

          for (int i = 0; i < maxFotos; i++) {
            final photoPath = photoPaths[i].toString();
            final sourceFile = File(photoPath);

            if (await sourceFile.exists()) {
              // Fotonummer im Format 0001-9999
              final fotoNumber = fotoCounter.toString().padLeft(4, '0');
              fotoNumbers.add(fotoNumber);
              fotoCounter++;

              // Ziel-Dateiname
              final extension = path.extension(photoPath);
              final fileName = '$fotoNumber$extension';

              // Ziel-Ordner bestimmen
              Directory targetDir;
              switch (structure) {
                case PhotoExportStructure.byAnlage:
                  final safeName = _sanitizeFileName(anlage.name);
                  final anlageDirName = '${lfdNummer}_$safeName';
                  targetDir = Directory('${fotosDir.path}/$anlageDirName');
                  await targetDir.create(recursive: true);
                  break;
                case PhotoExportStructure.byGewerk:
                  final gewerkName = _sanitizeFileName(anlage.discipline.label);
                  if (!gewerkDirs.containsKey(gewerkName)) {
                    gewerkDirs[gewerkName] = Directory('${fotosDir.path}/$gewerkName');
                    await gewerkDirs[gewerkName]!.create(recursive: true);
                  }
                  targetDir = gewerkDirs[gewerkName]!;
                  break;
                case PhotoExportStructure.allInOne:
                  targetDir = fotosDir;
                  break;
              }

              // Foto kopieren
              final targetFile = File('${targetDir.path}/$fileName');
              await sourceFile.copy(targetFile.path);
            }
          }
        }

        // Fotonummern zur CSV hinzufügen (max 4)
        for (int i = 0; i < 4; i++) {
          if (i < fotoNumbers.length) {
            dataRow.add(fotoNumbers[i]);
          } else {
            dataRow.add('');
          }
        }

        csvData.add(dataRow);
      }

      // CSV-Datei erstellen
      final csvString = const ListToCsvConverter(
        fieldDelimiter: _delimiter,
        eol: '\n',
      ).convert(csvData);

      // UTF-8 BOM hinzufügen
      final utf8Bom = [0xEF, 0xBB, 0xBF];
      final csvBytes = utf8Bom + utf8.encode(csvString);

      final csvFile = File('${exportDir.path}/anlagen.csv');
      await csvFile.writeAsBytes(csvBytes);

      // ZIP-Archiv erstellen
      final archive = Archive();
      
      // CSV-Datei zum Archiv hinzufügen
      final csvFileData = await csvFile.readAsBytes();
      archive.addFile(ArchiveFile('anlagen.csv', csvFileData.length, csvFileData));

      // Fotos zum Archiv hinzufügen
      await _addDirectoryToArchive(archive, fotosDir, 'fotos', structure);

      // ZIP-Datei erstellen
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      if (zipBytes == null) {
        throw Exception('Fehler beim Erstellen des ZIP-Archivs');
      }

      final zipFile = File('${tempDir.path}/anlagen_export_$timestamp.zip');
      await zipFile.writeAsBytes(zipBytes);

      // Temporäres Verzeichnis aufräumen
      await exportDir.delete(recursive: true);

      debugPrint('ZIP-Export abgeschlossen: ${anlagen.length} Anlagen, ${fotoCounter - 1} Fotos');

      // ZIP-Datei teilen
      await Share.shareXFiles(
        [XFile(zipFile.path)],
        text: 'Anlagen-Export mit Fotos',
        subject: 'Anlagen ZIP Export',
      );
    } catch (e, stackTrace) {
      debugPrint('ZIP-Export Fehler: $e');
      debugPrint('Stack Trace: $stackTrace');
      throw Exception('Fehler beim ZIP-Export: $e');
    }
  }

  /// Hilfsfunktion: Bereinigt Dateinamen (entfernt Sonderzeichen)
  static String _sanitizeFileName(String fileName) {
    // Ersetze ungültige Zeichen für Windows-Dateinamen
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  /// Hilfsfunktion: Fügt ein Verzeichnis rekursiv zum Archiv hinzu
  static Future<void> _addDirectoryToArchive(
    Archive archive,
    Directory directory,
    String archivePath,
    PhotoExportStructure structure,
  ) async {
    if (!await directory.exists()) {
      return;
    }

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final fileData = await entity.readAsBytes();
        
        // Für Unterordner: vollständigen Pfad beibehalten
        if (structure == PhotoExportStructure.byAnlage || 
            structure == PhotoExportStructure.byGewerk) {
          final relativeToFotos = path.relative(entity.path, from: directory.path);
          final archiveFilePath = path.join(archivePath, relativeToFotos).replaceAll('\\', '/');
          archive.addFile(ArchiveFile(archiveFilePath, fileData.length, fileData));
        } else {
          // Alle Fotos in einem Ordner - nur Dateiname
          final fileName = path.basename(entity.path);
          final archiveFilePath = path.join(archivePath, fileName).replaceAll('\\', '/');
          archive.addFile(ArchiveFile(archiveFilePath, fileData.length, fileData));
        }
      }
    }
  }
}

