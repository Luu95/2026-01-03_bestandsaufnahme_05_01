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

  static bool _isAnlageBauteilKey(String key) {
    final k = key.trim().toLowerCase();
    return k == 'anlage/bautel' || k == 'anlage/bauteil';
  }

  static String _getAnlageBauteilFlag(Anlage anlage) {
    // Kinder sind immer "B". Für Parents "A", außer wenn explizit gesetzt.
    if (anlage.parentId != null && anlage.parentId!.trim().isNotEmpty) return 'B';
    final existing = (anlage.params['Anlage/Bautel'] ?? anlage.params['Anlage/Bauteil'] ?? '')
        .toString()
        .trim();
    return existing.isNotEmpty ? existing : 'A';
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
  static Future<List<db.AnlagenCompanion>> importAnlagenCsv({List<String>? buildingIds}) async {
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

      // CSV-Datei lesen - verschiedene Encodings versuchen
      final bytes = await file.readAsBytes();
      
      // BOM entfernen falls vorhanden (UTF-8 BOM: EF BB BF)
      List<int> cleanBytes = bytes;
      if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
        cleanBytes = bytes.sublist(3);
      }
      
      // Encodings in Prioritätsreihenfolge versuchen
      String csvString = latin1.decode(cleanBytes); // Fallback: Latin1 (funktioniert immer)
      
      try {
        // Zuerst UTF-8 versuchen (Standard)
        csvString = utf8.decode(cleanBytes, allowMalformed: false);
      } catch (_) {
        // UTF-8 fehlgeschlagen, Latin1 wird als Fallback verwendet (bereits gesetzt)
      }
      
      // Leerzeichen am Anfang/Ende entfernen
      csvString = csvString.trim();
      
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
      
      final disciplineCache = await _loadPersistedDisciplines(primaryBuildingId);

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
              name: nameValue,
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
        await _persistDisciplines(bid, disciplineCache.values.toList());
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

  static Future<Map<String, Disziplin>> _loadPersistedDisciplines(String buildingId) async {
    final dbService = DatabaseService.instance;
    if (dbService != null) {
      final list = await dbService.getDisciplinesByBuildingId(buildingId);
      final map = <String, Disziplin>{};
      for (final disc in list) {
        map[disc.label.toLowerCase()] = disc;
      }
      return map;
    }

    // Fallback (z.B. wenn DatabaseService noch nicht initialisiert ist)
    final prefs = await SharedPreferences.getInstance();
    final key = 'disziplinen_$buildingId';
    final jsonStr = prefs.getString(key);
    if (jsonStr == null) return {};
    final List<dynamic> list = json.decode(jsonStr);
    final map = <String, Disziplin>{};
    for (final entry in list) {
      final disc = Disziplin.fromJson(entry as Map<String, dynamic>);
      map[disc.label.toLowerCase()] = disc;
    }
    return map;
  }

  static Future<void> _persistDisciplines(String buildingId, List<Disziplin> disciplines) async {
    final dbService = DatabaseService.instance;
    if (dbService != null) {
      await dbService.replaceDisciplines(buildingId, disciplines);
      return;
    }

    // Fallback
    final prefs = await SharedPreferences.getInstance();
    final key = 'disziplinen_$buildingId';
    final jsonList = disciplines.map((d) => d.toJson()).toList();
    await prefs.setString(key, json.encode(jsonList));
  }

  /// Lädt die CSV-Einstellungen für ein bestimmtes Projekt.
  /// Gibt die Standardwerte zurück, wenn keine Einstellungen gefunden werden.
  static Future<Map<String, dynamic>> _loadCsvSettings(String projectId) async {
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
          'anlageBauteilSpalte': settings['anlageBauteilSpalte'] as int?,
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
      'anlageBauteilSpalte': null,
    };
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

      // CSV-Datei lesen - verschiedene Encodings versuchen
      final bytes = await file.readAsBytes();
      
      // BOM entfernen falls vorhanden (UTF-8 BOM: EF BB BF)
      List<int> cleanBytes = bytes;
      if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
        cleanBytes = bytes.sublist(3);
      }
      
      // Encodings in Prioritätsreihenfolge versuchen
      String csvString = latin1.decode(cleanBytes); // Fallback: Latin1
      
      try {
        // Zuerst UTF-8 versuchen (Standard)
        csvString = utf8.decode(cleanBytes, allowMalformed: false);
      } catch (_) {
        // UTF-8 fehlgeschlagen, Latin1 wird als Fallback verwendet
      }
      
      // Leerzeichen am Anfang/Ende entfernen
      csvString = csvString.trim();
      
      // Delimiter automatisch erkennen (Semikolon oder Komma)
      String delimiter = _delimiter; // Standard: Semikolon
      if (csvString.contains(',') && !csvString.contains(';')) {
        delimiter = ',';
      } else if (csvString.contains(';')) {
        delimiter = ';';
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

      if (csvData.length < 2) {
        throw Exception('CSV-Datei benötigt mindestens Header und eine Datenzeile (gefunden: ${csvData.length} Zeilen)');
      }

      // Header lesen (erste Zeile)
      final headerRow = csvData.first.map((e) => e.toString().trim()).toList();
      
      // Debug: Header ausgeben
      debugPrint('CSV Header: $headerRow');
      debugPrint('Anzahl Header-Spalten: ${headerRow.length}');
      
      // CSV-Einstellungen für dieses Projekt laden
      final csvSettings = await _loadCsvSettings(projectId);
      final lfdNummerIdx = csvSettings['lfdNummerSpalte']!;
      final nameIdx = csvSettings['nameSpalte']!;
      final disciplineIdx = csvSettings['gewerkSpalte']!;
      final anlageBauteilIdx = csvSettings['anlageBauteilSpalte'] as int?;
      
      debugPrint('CSV-Einstellungen: lfdNummer=$lfdNummerIdx, name=$nameIdx, gewerk=$disciplineIdx, anlageBauteil=$anlageBauteilIdx');

      final dataRows = csvData.sublist(1).where((row) => row.isNotEmpty && row.any((cell) => cell.toString().trim().isNotEmpty)).toList();
      if (dataRows.isEmpty) {
        throw Exception('Keine Datenzeilen gefunden');
      }

      debugPrint('Anzahl Datenzeilen: ${dataRows.length}');

      // Bestimme die höchste Spaltennummer für die festen Felder
      final fixedColumns = [lfdNummerIdx, nameIdx, disciplineIdx];
      if (anlageBauteilIdx != null) {
        fixedColumns.add(anlageBauteilIdx);
      }
      final maxFixedColumn = fixedColumns.reduce((a, b) => a > b ? a : b);
      
      // Schema aus CSV-Spalten erstellen (ab der Spalte nach der höchsten festen Spalte)
      final schemaColumns = <int, String>{};
      for (var i = maxFixedColumn + 1; i < headerRow.length; i++) {
        final headerName = headerRow[i].trim();
        if (headerName.isNotEmpty) {
          // Verwende den Header-Namen als Key (normalisiert)
          schemaColumns[i] = headerName;
        } else {
          // Wenn Header leer, verwende generischen Namen
          schemaColumns[i] = 'Spalte_${i + 1}';
        }
      }

      debugPrint('Schema-Spalten: $schemaColumns');

      // Schema aus CSV-Spalten erstellen (Format: List<Map<String, String>>)
      final schema = schemaColumns.values.map<Map<String, String>>((headerName) {
        // Versuche den Typ zu erraten basierend auf dem Namen
        final lowerName = headerName.toLowerCase();
        String type = 'text';
        if (lowerName.contains('leistung') || lowerName.contains('kw') || 
            lowerName.contains('kapazität') || lowerName.contains('kapazitaet') ||
            lowerName.contains('volumen') || lowerName.contains('fläche') ||
            lowerName.contains('flaeche') || lowerName.contains('temperatur') ||
            lowerName.contains('watt') || lowerName.contains('ampere') ||
            lowerName.contains('liter') || lowerName.contains('kwh') ||
            lowerName.contains('anzahl') || lowerName.contains('stück') ||
            lowerName.contains('stueck') || lowerName.contains('baujahr') ||
            lowerName.contains('jahr')) {
          type = 'number';
        }
        
        return <String, String>{
          'key': headerName,
          'label': headerName,
          'type': type,
        };
      }).toList();

      debugPrint('Erstelltes Schema: $schema');

      // Bestehende Disziplinen für dieses Gebäude laden
      final disciplineCache = await _loadPersistedDisciplines(buildingId);
      debugPrint('Bestehende Disziplinen für Gebäude $buildingId: ${disciplineCache.keys.toList()}');

      // Alle eindeutigen Disziplinen aus CSV sammeln
      final uniqueDisciplines = <String>{};
      for (var i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];
        final disciplineLabel = _safeCell(row, disciplineIdx);
        if (disciplineLabel.isNotEmpty) {
          uniqueDisciplines.add(disciplineLabel.trim());
        }
      }

      debugPrint('Gefundene Disziplinen in CSV: $uniqueDisciplines');

      // Disziplinen-Schema aktualisieren oder neue erstellen
      for (final discLabel in uniqueDisciplines) {
        final discLabelLower = discLabel.toLowerCase();
        final existing = disciplineCache[discLabelLower];
        if (existing != null) {
          // Bestehende Disziplin: Schema aus CSV übernehmen
          // Icon und Farbe beibehalten, nur Schema aktualisieren
          existing.schema = schema;
          disciplineCache[discLabelLower] = existing;
          debugPrint('Disziplin aktualisiert: $discLabel');
        } else {
          // Neue Disziplin mit Schema aus CSV erstellen
          final newDiscipline = Disziplin(
            label: discLabel,
            icon: Icons.build,
            color: Colors.blueGrey,
            schema: schema,
          );
          disciplineCache[discLabelLower] = newDiscipline;
          debugPrint('Neue Disziplin erstellt: $discLabel mit Schema: $schema');
        }
      }

      // Disziplinen für dieses Gebäude persistieren
      await _persistDisciplines(buildingId, disciplineCache.values.toList());
      debugPrint('Disziplinen für Gebäude $buildingId gespeichert: ${disciplineCache.length}');

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
        final disciplineLabel = _safeCell(row, disciplineIdx);
        if (disciplineLabel.isEmpty) {
          debugPrint('Zeile ${i + 1} übersprungen: Keine Disziplin angegeben');
          continue; // Zeile überspringen, wenn keine Disziplin angegeben
        }
        final disciplineLabelValue = disciplineLabel.trim();
        
        // Anlage/Bauteil aus konfigurierter Spalte lesen (falls vorhanden)
        String? anlageBauteilValue;
        if (anlageBauteilIdx != null) {
          anlageBauteilValue = _safeCell(row, anlageBauteilIdx).trim();
        }
        
        // Parameter aus Spalten ab Index 3 (D+ = "Hersteller", "Typ", etc.)
        final params = _parseParamsFromRow(row, schemaColumns);
        // Laufende Nummer zu den Parametern hinzufügen
        params['lfdNummer'] = lfdNummerValue;
        // Anlage/Bauteil zu den Parametern hinzufügen (falls vorhanden)
        if (anlageBauteilValue != null && anlageBauteilValue.isNotEmpty) {
          params['Anlage/Bautel'] = anlageBauteilValue;
        }
        debugPrint('Anlage $nameValue (lfd Nummer: $lfdNummerValue): Disziplin=$disciplineLabelValue, Anlage/Bauteil=$anlageBauteilValue, Parameter=$params');

        final discipline = disciplineCache[disciplineLabelValue.toLowerCase()];
        if (discipline == null) {
          debugPrint('Zeile ${i + 1} übersprungen: Disziplin "$disciplineLabelValue" nicht gefunden');
          continue; // Disziplin nicht gefunden, Zeile überspringen
        }

        // Hierarchie NICHT über IDs im Parser lösen (die ändern sich beim Update via lfdNummer).
        // Stattdessen Parent-LfdNummer in Params merken; die finale parentId wird beim Speichern gesetzt.
        final anlageBautel = (params['Anlage/Bautel'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final isBauteil = anlageBautel == 'b' || anlageBautel.startsWith('b');

        if (isBauteil) {
          String? parentLfd;
          String? fallbackParentLfd;
          for (int j = anlagen.length - 1; j >= 0; j--) {
            final existing = anlagen[j];
            final existingType = (existing.params['Anlage/Bautel'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            final existingIsAnlage = existingType == 'a' || existingType.startsWith('a');
            if (!existingIsAnlage) continue;

            final existingLfd = existing.params['lfdNummer']?.toString();
            if (existingLfd == null || existingLfd.isEmpty) continue;

            if (existing.discipline.label == discipline.label) {
              parentLfd = existingLfd;
              break;
            }
            fallbackParentLfd ??= existingLfd;
          }
          parentLfd ??= fallbackParentLfd;
          if (parentLfd != null) {
            params['__parentLfdNummer'] = parentLfd;
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
      // CSV-Einstellungen laden (Spaltenzuordnung)
      final csvSettings = await _loadCsvSettings(projectId);
      final lfdNummerIdx = csvSettings['lfdNummerSpalte'] as int? ?? 0;
      final nameIdx = csvSettings['nameSpalte'] as int? ?? 1;
      final disciplineIdx = csvSettings['gewerkSpalte'] as int? ?? 2;
      final anlageBauteilIdx = csvSettings['anlageBauteilSpalte'] as int?;

      // Bestimme alle eindeutigen Schemas aus den Disziplinen
      // Wir brauchen eine Vereinigung aller Schema-Keys, um konsistente Spalten zu haben
      final allSchemaKeys = <String>{};
      for (final anlage in anlagen) {
        if (anlage.discipline.schema.isNotEmpty) {
          for (final schemaEntry in anlage.discipline.schema) {
            final key = schemaEntry['key'] ?? schemaEntry['label'] ?? '';
            if (key.isNotEmpty && key != 'lfdNummer' && !_isAnlageBauteilKey(key)) {
              // lfdNummer wird separat behandelt, nicht als Schema-Key
              allSchemaKeys.add(key);
            }
          }
        }
      }

      // Schema-Keys sortieren für konsistente Reihenfolge
      final sortedSchemaKeys = allSchemaKeys.toList()..sort();

      debugPrint('Schema-Keys für Export: $sortedSchemaKeys');

      // CSV-Daten erstellen
      final csvData = <List<String>>[];

      // Header-Zeile erstellen basierend auf den CSV-Einstellungen (Spaltenzuordnung)
      final fixedColumns = <int>[lfdNummerIdx, nameIdx, disciplineIdx];
      if (anlageBauteilIdx != null) fixedColumns.add(anlageBauteilIdx);
      final maxFixedColumn = fixedColumns.reduce((a, b) => a > b ? a : b);
      final headerRow = List<String>.filled(maxFixedColumn + 1, '', growable: true);
      headerRow[lfdNummerIdx] = 'lfd Nummer';
      headerRow[nameIdx] = 'Name';
      headerRow[disciplineIdx] = 'Gewerk';
      if (anlageBauteilIdx != null) {
        headerRow[anlageBauteilIdx] = 'Anlage/Bauteil';
      }
      headerRow.addAll(sortedSchemaKeys);
      headerRow.addAll(['Foto1', 'Foto2', 'Foto3', 'Foto4']);

      csvData.add(headerRow);

      debugPrint('CSV Header: $headerRow');

      // Zähler für neue Anlagen ohne lfdNummer
      int neueAnlagenZaehler = 1;

      // Hierarchisch anordnen: Parent-Anlage, dann Bauteile darunter
      final orderedAnlagen = _orderAnlagenHierarchically(anlagen);

      // Daten-Zeilen
      for (final anlage in orderedAnlagen) {
        final dataRow = List<String>.filled(maxFixedColumn + 1, '', growable: true);

        // Laufende Nummer aus params
        String lfdNummer = anlage.params['lfdNummer']?.toString() ?? '';
        if (lfdNummer.isEmpty || lfdNummer.trim().isEmpty) {
          lfdNummer = 'Neu_${neueAnlagenZaehler.toString().padLeft(4, '0')}';
          neueAnlagenZaehler++;
        }
        dataRow[lfdNummerIdx] = lfdNummer;

        // Name
        dataRow[nameIdx] = anlage.name;

        // Gewerk
        dataRow[disciplineIdx] = anlage.discipline.label;

        // Anlage/Bauteil (a/b)
        if (anlageBauteilIdx != null) {
          dataRow[anlageBauteilIdx] = _getAnlageBauteilFlag(anlage);
        }

        // Parameter aus Schema der Disziplin (beginnen nach den festen Spalten)
        for (final schemaKey in sortedSchemaKeys) {
          final paramValue = anlage.params[schemaKey];
          if (paramValue != null) {
            // Wert als String konvertieren
            if (paramValue is Map || paramValue is List) {
              dataRow.add(json.encode(paramValue));
            } else {
              dataRow.add(paramValue.toString());
            }
          } else {
            // Leere Zelle für fehlende Parameter
            dataRow.add('');
          }
        }

        // Fotonummern hinzufügen (werden später beim ZIP-Export befüllt)
        // Hier zunächst leer lassen, werden in exportAnlagenWithPhotos gesetzt
        dataRow.add(''); // Foto1
        dataRow.add(''); // Foto2
        dataRow.add(''); // Foto3
        dataRow.add(''); // Foto4

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
      // CSV-Einstellungen laden (Spaltenzuordnung)
      final csvSettings = await _loadCsvSettings(projectId);
      final lfdNummerIdx = csvSettings['lfdNummerSpalte'] as int? ?? 0;
      final nameIdx = csvSettings['nameSpalte'] as int? ?? 1;
      final disciplineIdx = csvSettings['gewerkSpalte'] as int? ?? 2;
      final anlageBauteilIdx = csvSettings['anlageBauteilSpalte'] as int?;

      // Temporäres Verzeichnis für Export erstellen
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final exportDir = Directory('${tempDir.path}/anlagen_export_$timestamp');
      await exportDir.create(recursive: true);

      // Globaler Zähler für Fotonummern (0001, 0002, etc.)
      int fotoCounter = 1;

      // Bestimme alle eindeutigen Schemas aus den Disziplinen
      final allSchemaKeys = <String>{};
      for (final anlage in anlagen) {
        if (anlage.discipline.schema.isNotEmpty) {
          for (final schemaEntry in anlage.discipline.schema) {
            final key = schemaEntry['key'] ?? schemaEntry['label'] ?? '';
            if (key.isNotEmpty && key != 'lfdNummer' && !_isAnlageBauteilKey(key)) {
              allSchemaKeys.add(key);
            }
          }
        }
      }

      final sortedSchemaKeys = allSchemaKeys.toList()..sort();

      // CSV-Daten erstellen
      final csvData = <List<String>>[];

      // Header-Zeile
      final fixedColumns = <int>[lfdNummerIdx, nameIdx, disciplineIdx];
      if (anlageBauteilIdx != null) fixedColumns.add(anlageBauteilIdx);
      final maxFixedColumn = fixedColumns.reduce((a, b) => a > b ? a : b);
      final headerRow = List<String>.filled(maxFixedColumn + 1, '', growable: true);
      headerRow[lfdNummerIdx] = 'lfd Nummer';
      headerRow[nameIdx] = 'Name';
      headerRow[disciplineIdx] = 'Gewerk';
      if (anlageBauteilIdx != null) {
        headerRow[anlageBauteilIdx] = 'Anlage/Bauteil';
      }
      headerRow.addAll(sortedSchemaKeys);
      headerRow.addAll(['Foto1', 'Foto2', 'Foto3', 'Foto4']);
      csvData.add(headerRow);

      // Zähler für neue Anlagen ohne lfdNummer
      int neueAnlagenZaehler = 1;

      // Fotos-Ordner erstellen basierend auf Struktur
      Directory fotosDir;
      switch (structure) {
        case PhotoExportStructure.byAnlage:
        case PhotoExportStructure.byGewerk:
          fotosDir = Directory('${exportDir.path}/fotos');
          await fotosDir.create(recursive: true);
          break;
        case PhotoExportStructure.allInOne:
          fotosDir = Directory('${exportDir.path}/fotos');
          await fotosDir.create(recursive: true);
          break;
      }

      // Map für Gewerk-Ordner (bei byGewerk)
      final Map<String, Directory> gewerkDirs = {};

      // Hierarchisch anordnen: Parent-Anlage, dann Bauteile darunter
      final orderedAnlagen = _orderAnlagenHierarchically(anlagen);

      // Verarbeite jede Anlage
      for (final anlage in orderedAnlagen) {
        final dataRow = List<String>.filled(maxFixedColumn + 1, '', growable: true);

        // Laufende Nummer
        String lfdNummer = anlage.params['lfdNummer']?.toString() ?? '';
        if (lfdNummer.isEmpty || lfdNummer.trim().isEmpty) {
          lfdNummer = 'Neu_${neueAnlagenZaehler.toString().padLeft(4, '0')}';
          neueAnlagenZaehler++;
        }
        dataRow[lfdNummerIdx] = lfdNummer;

        // Name
        dataRow[nameIdx] = anlage.name;

        // Gewerk
        dataRow[disciplineIdx] = anlage.discipline.label;

        // Anlage/Bauteil (a/b)
        if (anlageBauteilIdx != null) {
          dataRow[anlageBauteilIdx] = _getAnlageBauteilFlag(anlage);
        }

        // Parameter
        for (final schemaKey in sortedSchemaKeys) {
          final paramValue = anlage.params[schemaKey];
          if (paramValue != null) {
            if (paramValue is Map || paramValue is List) {
              dataRow.add(json.encode(paramValue));
            } else {
              dataRow.add(paramValue.toString());
            }
          } else {
            dataRow.add('');
          }
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
                  // Ordner pro Anlage: {lfdNummer}_{Anlagenname}
                  final safeName = _sanitizeFileName(anlage.name);
                  final anlageDirName = '${lfdNummer}_$safeName';
                  targetDir = Directory('${fotosDir.path}/$anlageDirName');
                  await targetDir.create(recursive: true);
                  break;

                case PhotoExportStructure.byGewerk:
                  // Ordner pro Gewerk
                  final gewerkName = _sanitizeFileName(anlage.discipline.label);
                  if (!gewerkDirs.containsKey(gewerkName)) {
                    gewerkDirs[gewerkName] = Directory('${fotosDir.path}/$gewerkName');
                    await gewerkDirs[gewerkName]!.create(recursive: true);
                  }
                  targetDir = gewerkDirs[gewerkName]!;
                  break;

                case PhotoExportStructure.allInOne:
                  // Alle Fotos in einem Ordner
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

