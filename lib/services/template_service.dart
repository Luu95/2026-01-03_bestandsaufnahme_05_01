// lib/services/template_service.dart

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../models/disziplin_schnittstelle.dart';

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

  /// Erstellt eine Template-Instanz aus einer CSV-Zeile
  factory Template.fromCsvRow(List<dynamic> row, Map<String, int> columnIndices) {
    String safeCell(int? idx) {
      if (idx == null || idx < 0 || idx >= row.length) return '';
      return row[idx].toString().trim();
    }

    return Template(
      gewerk: safeCell(columnIndices['gewerk']),
      anlageBauteil: safeCell(columnIndices['anlageBauteil']).toLowerCase(),
      anlagentyp: safeCell(columnIndices['anlagentyp']),
      bezeichnung: safeCell(columnIndices['bezeichnung']),
      parameter: safeCell(columnIndices['parameter']),
    );
  }
}

/// Service zum Laden und Verwalten von Vorlagen aus CSV-Dateien
class TemplateService {
  static const String _delimiter = ';';

  static String _normalizeCsvStringFromFileBytes(List<int> bytes) {
    // BOM entfernen falls vorhanden (UTF-8 BOM: EF BB BF)
    var cleanBytes = bytes;
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      cleanBytes = bytes.sublist(3);
    }

    // Encodings versuchen (UTF-8 bevorzugt, Latin1 als Fallback)
    String csvString;
    try {
      csvString = utf8.decode(cleanBytes, allowMalformed: false);
    } catch (_) {
      csvString = latin1.decode(cleanBytes);
    }
    
    // WICHTIG: Zeilenenden normalisieren!
    // Windows: \r\n -> \n
    // Mac (alt): \r -> \n
    csvString = csvString.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    
    return csvString.trim();
  }

  static String _detectDelimiter(String csvString) {
    // Fallback (wird i.d.R. über die intelligentere Variante unten überschrieben)
    return _delimiter;
  }

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
          'parameterSpalte': settings['parameterSpalte'] as int? ?? 4,
          'auswahlAnlagentypSpalte': settings['auswahlAnlagentypSpalte'] as int?,
        };
      } catch (e) {
        debugPrint('Fehler beim Laden der Vorlagen-CSV-Einstellungen: $e');
      }
    }
    
    // Standardwerte basierend auf der Beispiel-CSV
    return {
      'gewerkSpalte': 0,
      'anlageBauteilSpalte': 1,
      'anlagentypSpalte': 2,
      'bezeichnungSpalte': 3,
      'parameterSpalte': 4,
      'auswahlAnlagentypSpalte': null,
    };
  }

  /// Lädt Vorlagen aus der Datenbank (projektbezogen)
  static Future<List<Template>> loadTemplatesFromDatabase(String projectId, {String? gewerk}) async {
    final dbService = DatabaseService.instance;
    if (dbService == null) {
      throw Exception('DatabaseService nicht initialisiert');
    }

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
  static Future<int> importTemplatesFromCsv(String projectId, String? filePath, {String? buildingId}) async {
    final dbService = DatabaseService.instance;
    if (dbService == null) {
      throw Exception('DatabaseService nicht initialisiert');
    }

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

    // CSV robust lesen (Encoding + Delimiter erkennen)
    final bytes = await file.readAsBytes();
    final csvString = _normalizeCsvStringFromFileBytes(bytes);

    // Lade CSV-Einstellungen (für Delimiter-Sniffing brauchen wir den maxIndex)
    final settings = await _loadTemplateCsvSettings(projectId);
    final columnIndices = {
      'gewerk': settings['gewerkSpalte'] as int,
      'anlageBauteil': settings['anlageBauteilSpalte'] as int,
      'anlagentyp': settings['anlagentypSpalte'] as int,
      'bezeichnung': settings['bezeichnungSpalte'] as int,
      'parameter': settings['parameterSpalte'] as int,
    };
    final requiredMaxIndex = columnIndices.values.fold<int>(0, (m, v) => v > m ? v : m);

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
          await dbService.insertTemplate(
            projectId,
            template.gewerk,
            ab,
            template.anlagentyp,
            template.bezeichnung,
            template.parameter,
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

    // Erstelle automatisch Disziplinen aus den Gewerken für alle Gebäude im Projekt
    if (uniqueGewerke.isNotEmpty && buildingId != null) {
      try {
        await _createDisciplinesFromGewerke(dbService, buildingId, uniqueGewerke);
      } catch (e) {
        debugPrint('Fehler beim Erstellen der Disziplinen: $e');
        // Fehler wird ignoriert, damit der Import nicht fehlschlägt
      }
    }

    return count;
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
    final csvString = _normalizeCsvStringFromFileBytes(bytes);
    final delimiter = _detectDelimiter(csvString);
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
    if (projectId != null) {
      final settings = await _loadTemplateCsvSettings(projectId);
      columnIndices = {
        'gewerk': settings['gewerkSpalte'] as int,
        'anlageBauteil': settings['anlageBauteilSpalte'] as int,
        'anlagentyp': settings['anlagentypSpalte'] as int,
        'bezeichnung': settings['bezeichnungSpalte'] as int,
        'parameter': settings['parameterSpalte'] as int,
      };
    } else {
      // Erste Zeile ist der Header
      final headerRow = csvData[0].map((e) => e.toString().trim().toLowerCase()).toList();
      
      // Finde Spaltenindizes
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
        } else if (header.contains('parameter')) {
          columnIndices['parameter'] = i;
        }
      }

      // Fallback: Wenn keine Header gefunden wurden, verwende Standard-Indizes
      if (columnIndices.isEmpty) {
        columnIndices = {
          'gewerk': 0,
          'anlageBauteil': 1,
          'anlagentyp': 2,
          'bezeichnung': 3,
          'parameter': 4,
        };
      }
    }

    // Parse Datenzeilen
    final templates = <Template>[];
    for (var i = 1; i < csvData.length; i++) {
      final row = csvData[i];
      if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
        continue;
      }
      try {
        final template = Template.fromCsvRow(row, columnIndices);
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
  /// Gruppiert diese unter 'Leistungsparameter'.
  static Map<String, dynamic> parseParameters(String? parameterString) {
    final Map<String, String> lpMap = {};
    if (parameterString == null || parameterString.trim().isEmpty) {
      return {'Leistungsparameter': lpMap};
    }

    // Parameter können durch Komma getrennt sein
    final parts = parameterString.split(',');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) {
        lpMap[trimmed] = trimmed;
      }
    }

    return {'Leistungsparameter': lpMap};
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

  /// Erstellt eine leere Parameter-Map aus einem Template-Parameter-String
  /// Die Keys werden aus dem Parameter-String extrahiert und in einem gruppierten
  /// 'Leistungsparameter'-Feld abgelegt, damit sie im UI im Kasten erscheinen.
  static Map<String, dynamic> buildEmptyParamsFromTemplate(String? parameterString) {
    final Map<String, String> lpMap = {};
    if (parameterString == null || parameterString.trim().isEmpty) {
      return {'Leistungsparameter': lpMap};
    }

    // Parameter können durch Komma getrennt sein
    final parts = parameterString.split(',');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) {
        lpMap[trimmed] = '';
      }
    }

    return {'Leistungsparameter': lpMap};
  }

  /// Erstellt automatisch Disziplinen aus Gewerken für ein Gebäude
  static Future<void> _createDisciplinesFromGewerke(
    DatabaseService dbService,
    String buildingId,
    Set<String> gewerke,
  ) async {
    // Lade bestehende Disziplinen
    final existingDisciplines = await dbService.getDisciplinesByBuildingId(buildingId);
    final existingLabels = existingDisciplines.map((d) => d.label.toLowerCase()).toSet();
    
    // Erstelle neue Disziplinen für Gewerke, die noch nicht existieren
    final newDisciplines = <Disziplin>[];
    
    for (final gewerk in gewerke) {
      // Gewerk-Name original beibehalten (keine Änderungen!)
      final cleanGewerk = gewerk.trim();
      
      // Prüfe, ob eine Disziplin mit diesem Namen bereits existiert
      bool exists = false;
      for (final existingLabel in existingLabels) {
        if (existingLabel == cleanGewerk.toLowerCase()) {
          exists = true;
          break;
        }
      }
      
      if (!exists && cleanGewerk.isNotEmpty) {
        // Erstelle neue Disziplin mit originalem Gewerk-Namen
        final newDiscipline = Disziplin(
          label: cleanGewerk,
          icon: Icons.build,
          color: Colors.blueGrey,
          schema: [], // Leeres Schema - kann später angepasst werden
        );
        newDisciplines.add(newDiscipline);
        existingLabels.add(cleanGewerk.toLowerCase());
      }
    }
    
    // Speichere neue Disziplinen
    if (newDisciplines.isNotEmpty) {
      final allDisciplines = [...existingDisciplines, ...newDisciplines];
      await dbService.replaceDisciplines(buildingId, allDisciplines);
      debugPrint('${newDisciplines.length} neue Disziplinen erstellt: ${newDisciplines.map((d) => d.label).join(", ")}');
    }
  }
}

