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
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import '../models/csv_hierarchy_level.dart';
import '../models/anlage.dart';
import '../models/disziplin_schnittstelle.dart';
import '../database/database_service.dart';
import '../providers/csv_settings_provider.dart';
import 'template_service.dart';
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

/// Ziel des Exports: Teilen oder direkt auf dem Gerät speichern.
enum ExportDestination {
  share,
  saveToDevice,
}

/// Ergebnis eines CSV-Imports inkl. erkannter Header/Delimiter für die UI.
class CsvImportResult {
  final List<Anlage> anlagen;
  final List<String> importHeaderRow;
  final String detectedDelimiter;

  const CsvImportResult({
    required this.anlagen,
    required this.importHeaderRow,
    required this.detectedDelimiter,
  });
}

/// Erzeugte Export-Datei (noch nicht geteilt/gespeichert).
class ExportBuiltFile {
  final File file;
  final String fileName;

  const ExportBuiltFile({
    required this.file,
    required this.fileName,
  });
}

class _AttTripletSlotIndices {
  final int nameColumn;
  final int typeColumn;
  final int wertColumn;

  const _AttTripletSlotIndices({
    required this.nameColumn,
    required this.typeColumn,
    required this.wertColumn,
  });
}

/// Layout wie Gewerkevorlagen-CSV: Revisionsfeld, Revisionsobjekt, ATT1…ATTn (+ TYPE, WERT).
class _TemplateStyleExportLayout {
  final List<String> headers;
  final int revisionsfeldColumn;
  final int revisionsobjektColumn;
  final List<_AttTripletSlotIndices> attSlots;

  const _TemplateStyleExportLayout({
    required this.headers,
    required this.revisionsfeldColumn,
    required this.revisionsobjektColumn,
    required this.attSlots,
  });
}

class CsvService {
  static const String _delimiter = ';';
  static const Uuid _uuid = Uuid();

  /// Interne Param-Keys, die nicht als eigene Spalten exportiert werden.
  static const Set<String> _internalParamKeys = {
    '__parentLfdNummer',
    '__etageName',
    'photoPaths',
    '_validated',
    '_validatedAt',
    'validated',
  };

  /// True, wenn der Key ein internes Validierungs-Feld ist (nicht exportieren).
  static bool _isValidationParamKey(String key) {
    if (key.isEmpty) return false;
    if (_internalParamKeys.contains(key)) return true;
    if (key.startsWith('_field_') && key.endsWith('_validated')) return true;
    return false;
  }

  /// Baut die CSV-Header-Zeile: alle Daten-Spalten [dataColumnKeys] + ggf. angehängte Foto-Spalten.
  static List<String> _buildExportHeader(
    List<String> dataColumnKeys,
    List<String?> fotoLabels,
  ) {
    final headerRow = List<String>.from(dataColumnKeys);
    final existingSet = headerRow.toSet();
    for (int i = 0; i < 4; i++) {
      final t = fotoLabels[i]?.trim() ?? '';
      if (t.isNotEmpty && !existingSet.contains(t)) {
        headerRow.add(t);
        existingSet.add(t);
      }
    }
    return headerRow;
  }

  /// Indizes (0–3) der Foto-Spalten, die am Ende angehängt werden (noch nicht in dataColumnKeys).
  static List<int> _appendedFotoIndices(
    List<String> dataColumnKeys,
    List<String?> fotoLabels,
  ) {
    final existing = dataColumnKeys.toSet();
    final appended = <int>[];
    for (int i = 0; i < 4; i++) {
      final t = fotoLabels[i]?.trim() ?? '';
      if (t.isNotEmpty && !existing.contains(t)) appended.add(i);
    }
    return appended;
  }

  static bool _isFotoLabel(String label, List<String?> fotoLabels) {
    for (int i = 0; i < 4; i++) {
      final l = fotoLabels[i]?.trim();
      if (l != null && l.isNotEmpty && l == label) return true;
    }
    return false;
  }

  static int? _fotoLabelIndex(String label, List<String?> fotoLabels) {
    for (int i = 0; i < 4; i++) {
      if ((fotoLabels[i]?.trim() ?? '') == label) return i;
    }
    return null;
  }

  static String _fotoNumberForLabel(
    String label,
    List<String> fotoNumbers,
    List<String?> fotoLabels,
  ) {
    final idx = _fotoLabelIndex(label, fotoLabels);
    if (idx == null || idx >= fotoNumbers.length) return '';
    return fotoNumbers[idx];
  }

  /// Formatiert einen Param-Wert für eine CSV-Zelle.
  static String _paramValueToCsvCell(dynamic val) {
    if (val == null) return '';
    if (val is Map || val is List) return json.encode(val);
    return val.toString();
  }

  static const Set<String> _nonDynamicParamKeys = {
    'lfdNummer',
    '__etageName',
  };

  /// Mapping von CSV-Header-Labels zu internen Param-Keys (Legacy-Aliase).
  static const Map<String, String> _headerLabelToCanonicalKey = {
    'lfdNummer': 'lfdNummer',
    'Lfd. Nr.': 'lfdNummer',
    'Lfd Nr': 'lfdNummer',
    'Lfd. Nr': 'lfdNummer',
  };

  static String _paramKeyForHeaderLabel(String label) {
    final trimmed = label.trim();
    return _headerLabelToCanonicalKey[trimmed] ?? trimmed;
  }

  /// Parameter, die weder im Import-Header noch in festen Keys (lfdNummer, Etage, etc.) vorkommen,
  /// z. B. in der App hinzugefügte Felder. Beim Export mit Import-Struktur landen diese nur in
  /// den konfigurierten Attribut-Spalten (Name/Value). Sind keine Attribut-Paare definiert,
  /// werden solche Keys nicht in festen Spalten exportiert.
  static List<MapEntry<String, dynamic>> _collectDynamicAttributeEntries(
    Anlage anlage,
    Set<String> headerLabels,
    List<String?> fotoLabels,
  ) {
    final fotoSet = fotoLabels
        .map((e) => (e ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final attrs = <MapEntry<String, dynamic>>[];
    for (final entry in anlage.params.entries) {
      final key = entry.key.toString();
      if (key.isEmpty) continue;
      if (_internalParamKeys.contains(key)) continue;
      if (_isValidationParamKey(key)) continue;
      if (_nonDynamicParamKeys.contains(key)) continue;
      if (headerLabels.contains(key)) continue;
      if (fotoSet.contains(key)) continue;
      attrs.add(MapEntry(key, entry.value));
    }
    attrs.sort((a, b) => a.key.compareTo(b.key));
    return attrs;
  }

  static List<String> _buildRowFromImportStructure({
    required Anlage anlage,
    required List<String> headerRow,
    required List<AttributeColumnPair> attributePairs,
    required List<String?> fotoLabels,
    required List<String> fotoNumbers,
  }) {
    final row = List<String>.filled(headerRow.length, '', growable: true);
    final headerSet = headerRow.toSet();
    final useFotoColumns = fotoLabels.any((l) => l != null && l.trim().isNotEmpty);

    final attributeIndices = <int>{};
    for (final p in attributePairs) {
      attributeIndices.add(p.nameColumn);
      attributeIndices.add(p.valueColumn);
    }

    for (int i = 0; i < headerRow.length; i++) {
      if (attributeIndices.contains(i)) continue;
      final label = headerRow[i];
      if (useFotoColumns && _isFotoLabel(label, fotoLabels)) {
        final fotoIdx = _fotoLabelIndex(label, fotoLabels);
        row[i] = (fotoIdx != null && fotoIdx < fotoNumbers.length) ? fotoNumbers[fotoIdx] : '';
      } else {
        final paramKey = _paramKeyForHeaderLabel(label);
        row[i] = _paramValueToCsvCell(anlage.params[paramKey]);
      }
    }

    final dynamicAttrs = _collectDynamicAttributeEntries(anlage, headerSet, fotoLabels);
    int dynIndex = 0;
    for (final pair in attributePairs) {
      if (pair.nameColumn < 0 || pair.nameColumn >= row.length) continue;
      if (pair.valueColumn < 0 || pair.valueColumn >= row.length) continue;
      if (dynIndex >= dynamicAttrs.length) break;
      final entry = dynamicAttrs[dynIndex++];
      row[pair.nameColumn] = entry.key;
      row[pair.valueColumn] = _paramValueToCsvCell(entry.value);
    }

    return row;
  }

  static String _schemaFieldParamKey(Map<String, dynamic> field) {
    return field['key']?.toString().trim() ?? '';
  }

  static String _schemaFieldLabel(Map<String, dynamic> field) {
    final label = field['label']?.toString().trim() ?? '';
    final key = _schemaFieldParamKey(field);
    return label.isNotEmpty ? label : key;
  }

  /// Import-CSV-Struktur nur, wenn Header gespeichert sind und noch importierte Zeilen existieren.
  static bool shouldExportWithAnlagenImportStructure({
    required CsvSettings csvSettings,
    required List<Anlage> anlagen,
  }) {
    if (!csvSettings.hasAnlagenCsvImport) return false;
    return anlagen.any((a) {
      final lfd = a.params['lfdNummer']?.toString().trim() ?? '';
      return lfd.isNotEmpty;
    });
  }

  static Disziplin _disciplineForAnlage(Anlage anlage, List<Disziplin> disciplines) {
    final normalized = anlage.discipline.label.trim().toLowerCase();
    return disciplines.firstWhere(
      (d) => d.label.trim().toLowerCase() == normalized,
      orElse: () => anlage.discipline,
    );
  }

  static String _exportTypeLabelForField(Map<String, dynamic> field) {
    final type = field['type']?.toString().trim().toLowerCase() ?? '';
    if (type == 'dropdown' || type == 'select') return 'option';
    if (type.isEmpty) return 'text';
    return type;
  }

  /// Felder für eine Zeile: zuerst manuelle globale Attribute, dann Gewerk/RO-Schema.
  static List<Map<String, dynamic>> _orderedExportSchemaFields({
    required Anlage anlage,
    required Disziplin discipline,
    required List<Map<String, dynamic>> globalSchema,
    required CsvSettings csvSettings,
  }) {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};

    void addField(Map<String, dynamic> field) {
      final key = _schemaFieldParamKey(field);
      if (key.isEmpty || seen.contains(key)) return;
      seen.add(key);
      result.add(field);
    }

    for (final field in globalSchema) {
      addField(field);
    }

    final ro = csvSettings.schemaItemValueFromParams(anlage.params)?.trim() ?? '';
    for (final field in discipline.effectiveSchemaFor(revisionsobjekt: ro)) {
      if (field['isGlobal'] == true) continue;
      addField(field);
    }

    return result;
  }

  static int _maxAttributeSlotsForExport({
    required List<Anlage> anlagen,
    required List<Disziplin> disciplines,
    required List<Map<String, dynamic>> globalSchema,
    required CsvSettings csvSettings,
  }) {
    var maxSlots = 0;
    for (final anlage in anlagen) {
      final discipline = _disciplineForAnlage(anlage, disciplines);
      final count = _orderedExportSchemaFields(
        anlage: anlage,
        discipline: discipline,
        globalSchema: globalSchema,
        csvSettings: csvSettings,
      ).length;
      if (count > maxSlots) maxSlots = count;
    }
    return maxSlots;
  }

  /// Import-Header für Export: ATTn_OPTIONS → ATTn_WERT (Werte statt Optionslisten).
  static List<String> _templateHeadersForExport(List<String> importHeaders) {
    return importHeaders.map((raw) {
      final h = raw.trim();
      final upper = h.toUpperCase();
      if (upper.endsWith('_OPTIONS')) {
        return '${h.substring(0, h.length - '_OPTIONS'.length)}_WERT';
      }
      return h;
    }).toList();
  }

  static int _findHeaderIndex(List<String> headers, List<String> patterns) {
    for (var i = 0; i < headers.length; i++) {
      final h = headers[i].trim().toLowerCase();
      for (final p in patterns) {
        if (h == p || h.contains(p)) return i;
      }
    }
    return -1;
  }

  static List<_AttTripletSlotIndices> _parseAttTripletSlotsFromHeaders(
    List<String> headers,
  ) {
    final namePattern = RegExp(r'^att(\d+)$', caseSensitive: false);
    final byNumber = <int, _AttTripletSlotIndices>{};

    for (var i = 0; i < headers.length; i++) {
      final match = namePattern.firstMatch(headers[i].trim());
      if (match == null) continue;
      final n = int.tryParse(match.group(1) ?? '');
      if (n == null) continue;

      final typeIdx = headers.indexWhere(
        (h) => h.trim().toUpperCase() == 'ATT${n}_TYPE',
      );
      var wertIdx = headers.indexWhere((h) {
        final u = h.trim().toUpperCase();
        return u == 'ATT${n}_WERT' ||
            u == 'ATT${n}_VALUE' ||
            u == 'ATT${n}_OPTIONS';
      });
      if (typeIdx < 0 || wertIdx < 0) continue;

      byNumber[n] = _AttTripletSlotIndices(
        nameColumn: i,
        typeColumn: typeIdx,
        wertColumn: wertIdx,
      );
    }

    final sorted = byNumber.keys.toList()..sort();
    return [for (final n in sorted) byNumber[n]!];
  }

  static List<String> _buildDefaultTemplateExportHeaders(int attSlotCount) {
    final headers = <String>['Revisionsfeld', 'Revisionsobjekt'];
    for (var n = 1; n <= attSlotCount; n++) {
      headers.addAll(['ATT$n', 'ATT${n}_TYPE', 'ATT${n}_WERT']);
    }
    return headers;
  }

  static _TemplateStyleExportLayout _layoutFromHeaders(
    List<String> headers,
    int minAttSlots,
  ) {
    var working = List<String>.from(headers);
    var slots = _parseAttTripletSlotsFromHeaders(working);

    while (slots.length < minAttSlots) {
      final n = slots.length + 1;
      working.addAll(['ATT$n', 'ATT${n}_TYPE', 'ATT${n}_WERT']);
      slots = _parseAttTripletSlotsFromHeaders(working);
    }

    final rfCol = _findHeaderIndex(
      working,
      ['revisionsfeld', 'gewerk'],
    );
    final roCol = _findHeaderIndex(working, ['revisionsobjekt', 'anlagentyp']);

    return _TemplateStyleExportLayout(
      headers: working,
      revisionsfeldColumn: rfCol >= 0 ? rfCol : 0,
      revisionsobjektColumn: roCol >= 0 ? roCol : 1,
      attSlots: slots,
    );
  }

  static Future<_TemplateStyleExportLayout> _resolveTemplateStyleExportLayout({
    required List<Anlage> anlagen,
    required CsvSettings csvSettings,
    required List<Disziplin> disciplines,
    String? projectId,
  }) async {
    final globalSchema = projectId != null && projectId.isNotEmpty
        ? await _loadGlobalSchema(projectId)
        : <Map<String, dynamic>>[];

    final minAttSlots = _maxAttributeSlotsForExport(
      anlagen: anlagen,
      disciplines: disciplines,
      globalSchema: globalSchema,
      csvSettings: csvSettings,
    );

    if (projectId != null && projectId.isNotEmpty) {
      final templateSettings =
          await TemplateService.loadTemplateCsvSettings(projectId);
      final savedHeader =
          (templateSettings['importHeaderRow'] as List?)?.cast<String>() ?? [];
      if (savedHeader.isNotEmpty) {
        final exportHeaders = _templateHeadersForExport(savedHeader);
        return _layoutFromHeaders(exportHeaders, minAttSlots);
      }
    }

    return _layoutFromHeaders(
      _buildDefaultTemplateExportHeaders(minAttSlots),
      minAttSlots,
    );
  }

  static List<String> _buildTemplateStyleExportRow({
    required Anlage anlage,
    required _TemplateStyleExportLayout layout,
    required CsvSettings csvSettings,
    required List<Disziplin> disciplines,
    required List<Map<String, dynamic>> globalSchema,
  }) {
    final row = List<String>.filled(layout.headers.length, '', growable: true);
    final discipline = _disciplineForAnlage(anlage, disciplines);

    if (layout.revisionsfeldColumn >= 0 &&
        layout.revisionsfeldColumn < row.length) {
      if (csvSettings.level1IsDiscipline) {
        row[layout.revisionsfeldColumn] = anlage.discipline.label;
      } else {
        row[layout.revisionsfeldColumn] = _paramValueToCsvCell(
          csvSettings.revisionsfeldValueFromParams(anlage.params) ??
              csvSettings.readParamValue(
                anlage.params,
                csvSettings.resolveGewerkGroupingParamKey(),
              ),
        );
      }
    }

    if (layout.revisionsobjektColumn >= 0 &&
        layout.revisionsobjektColumn < row.length) {
      row[layout.revisionsobjektColumn] = _paramValueToCsvCell(
        csvSettings.schemaItemValueFromParams(anlage.params) ?? anlage.name,
      );
    }

    final fields = _orderedExportSchemaFields(
      anlage: anlage,
      discipline: discipline,
      globalSchema: globalSchema,
      csvSettings: csvSettings,
    );

    for (var i = 0; i < layout.attSlots.length && i < fields.length; i++) {
      final slot = layout.attSlots[i];
      final field = fields[i];
      final paramKey = _schemaFieldParamKey(field);
      if (slot.nameColumn >= 0 && slot.nameColumn < row.length) {
        row[slot.nameColumn] = _schemaFieldLabel(field);
      }
      if (slot.typeColumn >= 0 && slot.typeColumn < row.length) {
        row[slot.typeColumn] = _exportTypeLabelForField(field);
      }
      if (slot.wertColumn >= 0 && slot.wertColumn < row.length) {
        row[slot.wertColumn] = _paramValueToCsvCell(
          csvSettings.readParamValue(anlage.params, paramKey) ??
              anlage.params[paramKey],
        );
      }
    }

    return row;
  }

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
  /// [csvSettings]: CSV-Einstellungen aus Riverpod (Spaltenzuordnung, Delimiter, …).
  ///
  /// Gibt [CsvImportResult] zurück (Anlagen + erkannte Header/Delimiter für die UI).
  /// Die laufende Nummer wird in den Params als "lfdNummer" gespeichert.
  static Future<CsvImportResult> importAnlagenCsvForDisciplines({
    required DatabaseService dbService,
    required String buildingId,
    required CsvSettings csvSettings,
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
      
      final projectId = await dbService.getProjectIdByBuildingId(buildingId);
      if (projectId == null || projectId.isEmpty) {
        throw Exception('Projekt für Gebäude nicht gefunden');
      }

      final settings = csvSettings;
      final enabledLevels = settings.enabledLevelsOrdered;
      final leafLevel = settings.leafLevel;
      if (leafLevel == null) {
        throw Exception('Mindestens eine Hierarchie-Ebene muss aktiv sein.');
      }

      final etageIdx = settings.etageSpalte;
      final anlageBauteilIdx = settings.anlageBauteilSpalte;
      final delimiterMode = settings.delimiterMode;
      const headerZeile = 1;
      final useDisciplineGrouping = settings.level1.enabled;
      final attributePairs = settings.attributeColumnPairs;
      final attributeColumnIndices = <int>{};
      for (final p in attributePairs) {
        attributeColumnIndices.add(p.nameColumn);
        attributeColumnIndices.add(p.valueColumn);
      }

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
      
      final anlageKuerzel = _parseKuerzel(settings.anlageKuerzel, ['a', 'anlage']);
      final bauteilKuerzel = _parseKuerzel(settings.bauteilKuerzel, ['b', 'bauteil']);


      // Datenzeilen: alle Zeilen nach der Header-Zeile
      var dataRows = csvData.sublist(headerRowIndex + 1).where((row) => row.isNotEmpty && row.any((cell) => cell.toString().trim().isNotEmpty)).toList();

      // Erste Zeile überspringen, falls sie exakt dem Header entspricht (z.B. falsche headerZeile-Einstellung)
      if (dataRows.isNotEmpty) {
        final firstRow = dataRows.first.map((c) => c.toString().trim()).toList();
        final headerTrimmed = headerRow.map((h) => h.trim()).toList();
        final matchesHeader = firstRow.length >= headerTrimmed.length &&
            headerTrimmed.asMap().entries.every((e) =>
                e.key < firstRow.length &&
                firstRow[e.key].toLowerCase() == e.value.toLowerCase());
        if (matchesHeader) {
          debugPrint('Erste Datenzeile entspricht Header – wird übersprungen (evtl. headerZeile prüfen)');
          dataRows = dataRows.sublist(1);
        }
      }

      if (dataRows.isEmpty) {
        throw Exception('Keine Datenzeilen gefunden');
      }


      // Schema ausschließlich aus CSV-Header aufbauen (keine festen Schemata aus der App).
      // Nur Spalten, die keine Attribut-Paare sind, werden als Schema-Felder übernommen.
      // Attribut-Paare liefern pro Zeile dynamische params (Attributname → Attributwert).
      final schemaColumns = <int, String>{};
      for (var i = 0; i < headerRow.length; i++) {
        if (attributeColumnIndices.contains(i)) continue;
        final headerName = headerRow[i].trim();
        if (headerName.isNotEmpty) {
          schemaColumns[i] = headerName;
        } else {
          schemaColumns[i] = 'Spalte_${i + 1}';
        }
      }

      // Schema-Einträge nur für feste Spalten (nicht für Attribut-Paare)
      final schemaFromCsv = <Map<String, dynamic>>[];
      for (var i = 0; i < headerRow.length; i++) {
        if (attributeColumnIndices.contains(i)) continue;
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


      // Bestehende Disziplinen für dieses Gebäude laden
      final disciplineCache = await _loadPersistedDisciplines(dbService, buildingId);
      debugPrint('Bestehende Disziplinen für Gebäude $buildingId: ${disciplineCache.keys.toList()}');

      // Alle eindeutigen Disziplinen sammeln.
      // Wenn Gewerk-Gruppierung deaktiviert ist, landen alle Anlagen in einer Sammel-Disziplin.
      final uniqueDisciplines = <String>{};
      if (useDisciplineGrouping) {
        final disciplineIdx = settings.level1.nameColumn;
        for (var i = 0; i < dataRows.length; i++) {
          final row = dataRows[i];
          final disciplineLabel = _safeCell(row, disciplineIdx);
          final disciplineLabelValue = disciplineLabel.trim();
          if (disciplineLabelValue.isNotEmpty) {
            uniqueDisciplines.add(disciplineLabelValue);
          }
        }
      } else {
        uniqueDisciplines.add(settings.resolveDefaultDisciplineLabel());
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
      final syntheticNodeLfdByKey = <String, String>{};
      var syntheticNodeCounter = 0;
      var parentLevels = enabledLevels.length > 1
          ? enabledLevels.sublist(0, enabledLevels.length - 1)
          : <HierarchyLevelConfig>[];
      // Ebene 1 ist bereits die Disziplin (Gewerk) – keinen doppelten Hierarchie-Knoten anlegen.
      if (useDisciplineGrouping &&
          settings.level1.enabled &&
          parentLevels.isNotEmpty &&
          parentLevels.first.nameColumn == settings.level1.nameColumn) {
        parentLevels = parentLevels.length > 1
            ? parentLevels.sublist(1)
            : <HierarchyLevelConfig>[];
      }

      for (var i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];

        final leafName = _safeCell(row, leafLevel.nameColumn);
        final leafId = leafLevel.useIdColumn && leafLevel.idColumn != null
            ? _safeCell(row, leafLevel.idColumn!).trim()
            : '';

        if (leafName.trim().isEmpty && leafId.isEmpty) {
          debugPrint(
            'Zeile ${headerRowIndex + 2 + i} übersprungen: Blatt-Ebene ohne Name und ohne ID',
          );
          continue;
        }

        final nameValue = leafName.trim().isEmpty
            ? '${settings.resolveLeafLevelLabel()}_${i + 1}'
            : leafName.trim();

        final disciplineLabel = useDisciplineGrouping
            ? _safeCell(row, settings.level1.nameColumn)
            : settings.resolveDefaultDisciplineLabel();
        if (disciplineLabel.trim().isEmpty) {
          debugPrint('Zeile ${i + 1} übersprungen: Keine Disziplin angegeben');
          continue;
        }
        final disciplineLabelValue = disciplineLabel.trim();

        final lfdNummerValue = leafId.isNotEmpty
            ? leafId
            : 'AUTO_${disciplineLabelValue}_${i + 1}';

        String? etageValue;
        if (etageIdx != null) {
          etageValue = _safeCell(row, etageIdx).trim();
        }

        String? anlageBauteilValue;
        if (anlageBauteilIdx != null) {
          anlageBauteilValue = _safeCell(row, anlageBauteilIdx).trim();
        }

        final params = _parseParamsFromRow(row, schemaColumns);
        for (final pair in attributePairs) {
          final attrName = _safeCell(row, pair.nameColumn);
          if (attrName.isEmpty) continue;
          final attrValue = _safeCell(row, pair.valueColumn);
          params[attrName] = _parseDynamicValue(attrValue);
        }

        params['lfdNummer'] = lfdNummerValue;

        if (etageValue != null && etageValue.isNotEmpty) {
          settings.writeEtageToParams(params, etageValue);
        }

        if (anlageBauteilValue != null && anlageBauteilValue.isNotEmpty) {
          settings.writeAnlageBauteilToParams(params, anlageBauteilValue);
        }

        final revisionsobjektValue =
            (settings.revisionsobjektValueFromParams(params) ??
                    settings.schemaItemValueFromParams(params) ??
                    '')
                .trim();
        if (revisionsobjektValue.isNotEmpty) {
          settings.writeHierarchyLocationToParams(
            params,
            revisionsfeld: disciplineLabelValue,
            revisionsobjekt: revisionsobjektValue,
          );
        } else {
          final level1LabelKey = settings.labelGewerk.trim();
          if (level1LabelKey.isNotEmpty &&
              !settings.isLeafNameParamKey(level1LabelKey)) {
            params[level1LabelKey] = disciplineLabelValue;
          }
        }

        final discipline = disciplineCache[disciplineLabelValue.toLowerCase()];
        if (discipline == null) {
          debugPrint('Zeile ${i + 1} übersprungen: Disziplin "$disciplineLabelValue" nicht gefunden');
          continue;
        }

        // Hierarchie über aktive Ebenen (Eltern-Knoten pro Pfad deduplizieren)
        String? immediateParentLfd;
        final pathSegments = <String>[];

        for (final level in parentLevels) {
          final levelName = _safeCell(row, level.nameColumn).trim();
          if (levelName.isEmpty) continue;

          final levelId = level.useIdColumn && level.idColumn != null
              ? _safeCell(row, level.idColumn!).trim()
              : '';
          final dedupeToken = levelId.isNotEmpty ? 'id:$levelId' : 'name:$levelName';
          pathSegments.add('${level.nameColumn}:$dedupeToken');
          final nodeKey = '${discipline.label}|$floorId|${pathSegments.join("|")}';

          var nodeLfd = syntheticNodeLfdByKey[nodeKey];
          if (nodeLfd == null) {
            syntheticNodeCounter++;
            nodeLfd = levelId.isNotEmpty
                ? levelId
                : 'GRP_${discipline.label}_$syntheticNodeCounter';
            syntheticNodeLfdByKey[nodeKey] = nodeLfd;

            final nodeParams = <String, dynamic>{
              'lfdNummer': nodeLfd,
              '__syntheticParent': true,
            };
            if (schemaColumns.containsKey(level.nameColumn)) {
              nodeParams[schemaColumns[level.nameColumn]!] = levelName;
            }
            if (levelId.isNotEmpty &&
                level.idColumn != null &&
                schemaColumns.containsKey(level.idColumn)) {
              nodeParams[schemaColumns[level.idColumn]!] = levelId;
            }

            if (immediateParentLfd != null) {
              nodeParams['__parentLfdNummer'] = immediateParentLfd;
            }

            anlagen.add(Anlage(
              id: _uuid.v4(),
              name: levelName,
              params: nodeParams,
              floorId: floorId,
              buildingId: buildingId,
              isMarker: false,
              markerInfo: null,
              markerType: discipline.label,
              discipline: discipline,
              parentId: null,
            ));
            debugPrint('Hierarchie-Knoten "$levelName" (lfd: $nodeLfd)');
          }
          immediateParentLfd = nodeLfd;
        }

        if (immediateParentLfd != null) {
          params['__parentLfdNummer'] = immediateParentLfd;
        }

        // Legacy A/B-Hierarchie (nur wenn konfiguriert und noch kein Eltern-Knoten gesetzt)
        if (anlageBauteilIdx != null && !params.containsKey('__parentLfdNummer')) {
          final abKey = settings.resolveAnlageBauteilParamKey();
          final anlageBautel = abKey != null
              ? (settings.anlageBauteilValueFromParams(params) ?? '')
              : '';
          final isBauteil = _matchesAnyToken(anlageBautel, bauteilKuerzel);

          if (isBauteil) {
            String? parentLfd;
            for (int j = anlagen.length - 1; j >= 0; j--) {
              final existing = anlagen[j];
              if (existing.discipline.label != discipline.label) continue;

              final existingLfd = existing.params['lfdNummer']?.toString();
              if (existingLfd == null || existingLfd.isEmpty) continue;

              final existingType = abKey != null
                  ? (settings.anlageBauteilValueFromParams(existing.params) ?? '')
                  : '';
              if (_matchesAnyToken(existingType, bauteilKuerzel)) continue;

              parentLfd = existingLfd;
              break;
            }

            if (parentLfd != null) {
              params['__parentLfdNummer'] = parentLfd;
            }
          }
        }

        debugPrint(
          'Blatt $nameValue (lfd: $lfdNummerValue): Disziplin=$disciplineLabelValue, '
          'Parent=${params['__parentLfdNummer']}',
        );

        anlagen.add(Anlage(
          id: _uuid.v4(),
          name: nameValue,
          params: params,
          floorId: floorId,
          buildingId: buildingId,
          isMarker: false,
          markerInfo: null,
          markerType: discipline.label,
          discipline: discipline,
          parentId: null,
        ));
      }

      debugPrint('Insgesamt ${anlagen.length} Anlagen erstellt');
      return CsvImportResult(
        anlagen: anlagen,
        importHeaderRow: headerRow,
        detectedDelimiter: delimiter,
      );
    } catch (e, stackTrace) {
      debugPrint('CSV-Import Fehler: $e');
      debugPrint('Stack Trace: $stackTrace');
      throw Exception('Fehler beim CSV-Import: $e');
    }
  }

  /// Erstellt die CSV-Datei im Temp-Ordner (ohne Teilen/Speichern-Dialog).
  static Future<ExportBuiltFile> buildAnlagenCsvExportFile({
    required List<Anlage> anlagen,
    required CsvSettings csvSettings,
    List<Disziplin> disciplines = const [],
    String? projectId,
    String? buildingId,
    DatabaseService? dbService,
  }) async {
    if (anlagen.isEmpty) {
      throw Exception('Keine Anlagen zum Exportieren vorhanden');
    }

    try {
      final fotoLabels = [
        csvSettings.foto1SpalteLabel,
        csvSettings.foto2SpalteLabel,
        csvSettings.foto3SpalteLabel,
        csvSettings.foto4SpalteLabel,
      ];
      final useFotoColumns = fotoLabels.any((l) => l != null && l.trim().isNotEmpty);

      final orderedAnlagen = _orderAnlagenHierarchically(anlagen);
      var disciplineList = List<Disziplin>.from(disciplines);
      if (disciplineList.isEmpty &&
          dbService != null &&
          buildingId != null &&
          buildingId.isNotEmpty) {
        disciplineList = await dbService.getDisciplinesByBuildingId(buildingId);
      }

      final attributePairs = csvSettings.attributeColumnPairs;
      final hasImportStructure = shouldExportWithAnlagenImportStructure(
        csvSettings: csvSettings,
        anlagen: orderedAnlagen,
      );
      _TemplateStyleExportLayout? templateLayout;
      List<String> dataColumnKeys;
      List<Map<String, dynamic>> globalSchema = [];
      if (hasImportStructure) {
        dataColumnKeys = csvSettings.importHeaderRow
            .where((k) => !_isValidationParamKey(k.trim()))
            .toList();
      } else {
        if (projectId != null && projectId.isNotEmpty) {
          globalSchema = await _loadGlobalSchema(projectId);
        }
        templateLayout = await _resolveTemplateStyleExportLayout(
          anlagen: orderedAnlagen,
          csvSettings: csvSettings,
          disciplines: disciplineList,
          projectId: projectId,
        );
        dataColumnKeys = templateLayout.headers;
      }

      final headerRow = useFotoColumns
          ? _buildExportHeader(dataColumnKeys, fotoLabels)
          : (List<String>.from(dataColumnKeys)..addAll(['Foto1', 'Foto2', 'Foto3', 'Foto4']));
      final csvData = <List<String>>[headerRow];

      debugPrint(
        'CSV Header (${hasImportStructure ? 'Anlagen-Import' : 'Gewerkevorlagen (ATT+WERT)'}, '
        '${dataColumnKeys.length} Spalten): $headerRow',
      );

      final appendedIndices = useFotoColumns ? _appendedFotoIndices(dataColumnKeys, fotoLabels) : <int>[];

      for (final anlage in orderedAnlagen) {
        const emptyFotoNumbers = ['', '', '', ''];
        final dataRow = hasImportStructure
            ? _buildRowFromImportStructure(
                anlage: anlage,
                headerRow: dataColumnKeys,
                attributePairs: attributePairs,
                fotoLabels: fotoLabels,
                fotoNumbers: emptyFotoNumbers,
              )
            : _buildTemplateStyleExportRow(
                anlage: anlage,
                layout: templateLayout!,
                csvSettings: csvSettings,
                disciplines: disciplineList,
                globalSchema: globalSchema,
              );

        if (useFotoColumns) {
          for (final i in appendedIndices) {
            dataRow.add(emptyFotoNumbers[i]);
          }
        } else {
          dataRow.addAll(['', '', '', '']);
        }

        csvData.add(dataRow);
      }

      // CSV-String erstellen (UTF-8 mit BOM für Excel-Kompatibilität)
      final exportDelimiter = csvSettings.exportDelimiter.isNotEmpty
          ? csvSettings.exportDelimiter
          : _delimiter;
      final csvString = ListToCsvConverter(
        fieldDelimiter: exportDelimiter,
        eol: '\n',
      ).convert(csvData);

      // UTF-8 BOM hinzufügen (für Excel-Kompatibilität)
      final utf8Bom = [0xEF, 0xBB, 0xBF];
      final csvBytes = utf8Bom + utf8.encode(csvString);

      // Temporäre Datei erstellen
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'anlagen_export_$timestamp.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(csvBytes);

      debugPrint('CSV-Export abgeschlossen: ${csvData.length - 1} Anlagen exportiert');

      return ExportBuiltFile(file: file, fileName: fileName);
    } catch (e, stackTrace) {
      debugPrint('CSV-Export Fehler: $e');
      debugPrint('Stack Trace: $stackTrace');
      throw Exception('Fehler beim CSV-Export: $e');
    }
  }

  /// Exportiert Anlagen zu CSV (Teilen oder Speichern-Dialog).
  static Future<String?> exportAnlagenCsvForDisciplines({
    required List<Anlage> anlagen,
    required CsvSettings csvSettings,
    List<Disziplin> disciplines = const [],
    String? projectId,
    String? buildingId,
    DatabaseService? dbService,
    ExportDestination destination = ExportDestination.share,
  }) async {
    final built = await buildAnlagenCsvExportFile(
      anlagen: anlagen,
      csvSettings: csvSettings,
      disciplines: disciplines,
      projectId: projectId,
      buildingId: buildingId,
      dbService: dbService,
    );
    return _deliverExportFile(
      file: built.file,
      fileName: built.fileName,
      destination: destination,
      shareText: 'Anlagen-Export',
      shareSubject: 'Anlagen CSV Export',
    );
  }

  /// Erstellt ein ZIP-Archiv mit CSV und Fotos. Gibt die temporäre ZIP-Datei zurück.
  static Future<ExportBuiltFile> buildAnlagenZipExportFile({
    required List<Anlage> anlagen,
    required CsvSettings csvSettings,
    required PhotoExportStructure structure,
    List<Disziplin> disciplines = const [],
    String? projectId,
    String? buildingId,
    DatabaseService? dbService,
  }) async {
    final zipFile = await _buildAnlagenZipFile(
      anlagen: anlagen,
      csvSettings: csvSettings,
      structure: structure,
      disciplines: disciplines,
      projectId: projectId,
      buildingId: buildingId,
      dbService: dbService,
    );
    return ExportBuiltFile(
      file: zipFile,
      fileName: path.basename(zipFile.path),
    );
  }

  static Future<File> _buildAnlagenZipFile({
    required List<Anlage> anlagen,
    required CsvSettings csvSettings,
    required PhotoExportStructure structure,
    List<Disziplin> disciplines = const [],
    String? projectId,
    String? buildingId,
    DatabaseService? dbService,
  }) async {
    if (anlagen.isEmpty) {
      throw Exception('Keine Anlagen zum Exportieren vorhanden');
    }

    final fotoLabels = [
      csvSettings.foto1SpalteLabel,
      csvSettings.foto2SpalteLabel,
      csvSettings.foto3SpalteLabel,
      csvSettings.foto4SpalteLabel,
    ];
    final useFotoColumns = fotoLabels.any((l) => l != null && l.trim().isNotEmpty);

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final exportDir = Directory('${tempDir.path}/anlagen_export_$timestamp');
    await exportDir.create(recursive: true);

    int fotoCounter = 1;

    final orderedAnlagenForHeader = _orderAnlagenHierarchically(anlagen);
    var disciplineList = List<Disziplin>.from(disciplines);
    if (disciplineList.isEmpty &&
        dbService != null &&
        buildingId != null &&
        buildingId.isNotEmpty) {
      disciplineList = await dbService.getDisciplinesByBuildingId(buildingId);
    }

    final attributePairs = csvSettings.attributeColumnPairs;
    final hasImportStructure = shouldExportWithAnlagenImportStructure(
      csvSettings: csvSettings,
      anlagen: orderedAnlagenForHeader,
    );
    _TemplateStyleExportLayout? templateLayout;
    List<String> dataColumnKeys;
    List<Map<String, dynamic>> globalSchema = [];
    if (hasImportStructure) {
      dataColumnKeys = csvSettings.importHeaderRow
          .where((k) => !_isValidationParamKey(k.trim()))
          .toList();
    } else {
      if (projectId != null && projectId.isNotEmpty) {
        globalSchema = await _loadGlobalSchema(projectId);
      }
      templateLayout = await _resolveTemplateStyleExportLayout(
        anlagen: orderedAnlagenForHeader,
        csvSettings: csvSettings,
        disciplines: disciplineList,
        projectId: projectId,
      );
      dataColumnKeys = templateLayout.headers;
    }

    final csvData = <List<String>>[];
    final headerRow = useFotoColumns
        ? _buildExportHeader(dataColumnKeys, fotoLabels)
        : (List<String>.from(dataColumnKeys)..addAll(['Foto1', 'Foto2', 'Foto3', 'Foto4']));
    csvData.add(headerRow);
    final appendedIndices = useFotoColumns ? _appendedFotoIndices(dataColumnKeys, fotoLabels) : <int>[];

    int neueAnlagenZaehler = 1;

    Directory fotosDir = Directory('${exportDir.path}/fotos');
    await fotosDir.create(recursive: true);

    final Map<String, Directory> gewerkDirs = {};
    final orderedAnlagen = orderedAnlagenForHeader;

    for (final anlage in orderedAnlagen) {
      String lfdNummer = anlage.params['lfdNummer']?.toString() ?? '';
      if (lfdNummer.isEmpty) {
        lfdNummer = 'Neu_${neueAnlagenZaehler.toString().padLeft(4, '0')}';
        neueAnlagenZaehler++;
      }

      final photoPaths = anlage.params['photoPaths'] as List<dynamic>?;
      final fotoNumbers = <String>[];

      if (photoPaths != null && photoPaths.isNotEmpty) {
        final maxFotos = photoPaths.length > 4 ? 4 : photoPaths.length;

        for (int i = 0; i < maxFotos; i++) {
          final photoPath = photoPaths[i].toString();
          final sourceFile = File(photoPath);

          if (await sourceFile.exists()) {
            final fotoNumber = fotoCounter.toString().padLeft(4, '0');
            fotoNumbers.add(fotoNumber);
            fotoCounter++;

            final extension = path.extension(photoPath);
            final fileName = '$fotoNumber$extension';

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

            final targetFile = File('${targetDir.path}/$fileName');
            await sourceFile.copy(targetFile.path);
          }
        }
      }

      var dataRow = hasImportStructure
          ? _buildRowFromImportStructure(
              anlage: anlage,
              headerRow: dataColumnKeys,
              attributePairs: attributePairs,
              fotoLabels: fotoLabels,
              fotoNumbers: fotoNumbers,
            )
          : _buildTemplateStyleExportRow(
              anlage: anlage,
              layout: templateLayout!,
              csvSettings: csvSettings,
              disciplines: disciplineList,
              globalSchema: globalSchema,
            );

      if (useFotoColumns) {
        for (final i in appendedIndices) {
          dataRow.add(i < fotoNumbers.length ? fotoNumbers[i] : '');
        }
      } else {
        for (int i = 0; i < 4; i++) {
          dataRow.add(i < fotoNumbers.length ? fotoNumbers[i] : '');
        }
      }

      csvData.add(dataRow);
    }

    final exportDelimiter = csvSettings.exportDelimiter.isNotEmpty
        ? csvSettings.exportDelimiter
        : _delimiter;
    final csvString = ListToCsvConverter(
      fieldDelimiter: exportDelimiter,
      eol: '\n',
    ).convert(csvData);

    final utf8Bom = [0xEF, 0xBB, 0xBF];
    final csvBytes = utf8Bom + utf8.encode(csvString);

    final csvFile = File('${exportDir.path}/anlagen.csv');
    await csvFile.writeAsBytes(csvBytes);

    final archive = Archive();
    final csvFileData = await csvFile.readAsBytes();
    archive.addFile(ArchiveFile('anlagen.csv', csvFileData.length, csvFileData));

    await _addDirectoryToArchive(archive, fotosDir, 'fotos', structure);

    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);
    if (zipBytes == null) {
      throw Exception('Fehler beim Erstellen des ZIP-Archivs');
    }

    final zipFile = File('${tempDir.path}/anlagen_export_$timestamp.zip');
    await zipFile.writeAsBytes(zipBytes);

    await exportDir.delete(recursive: true);

    debugPrint('ZIP erstellt: ${anlagen.length} Anlagen, ${fotoCounter - 1} Fotos');
    return zipFile;
  }

  /// Exportiert Anlagen mit Fotos in ein ZIP-Archiv.
  /// Gibt bei [ExportDestination.saveToDevice] den Speicherpfad zurück.
  static Future<String?> exportAnlagenWithPhotos({
    required List<Anlage> anlagen,
    required CsvSettings csvSettings,
    required PhotoExportStructure structure,
    List<Disziplin> disciplines = const [],
    String? projectId,
    String? buildingId,
    DatabaseService? dbService,
    ExportDestination destination = ExportDestination.share,
  }) async {
    try {
      final built = await buildAnlagenZipExportFile(
        anlagen: anlagen,
        csvSettings: csvSettings,
        structure: structure,
        disciplines: disciplines,
        projectId: projectId,
        buildingId: buildingId,
        dbService: dbService,
      );

      try {
        return await _deliverExportFile(
          file: built.file,
          fileName: built.fileName,
          destination: destination,
          shareText: 'Anlagen-Export mit Fotos',
          shareSubject: 'Anlagen ZIP Export',
        );
      } finally {
        if (await built.file.exists()) {
          await built.file.delete();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('ZIP-Export Fehler: $e');
      debugPrint('Stack Trace: $stackTrace');
      throw Exception('Fehler beim ZIP-Export: $e');
    }
  }

  /// Speichert eine Export-Datei direkt auf dem Gerät (Datei-Dialog oder App-Ordner).
  static Future<String?> _deliverExportFile({
    required File file,
    required String fileName,
    required ExportDestination destination,
    required String shareText,
    required String shareSubject,
  }) async {
    if (destination == ExportDestination.saveToDevice) {
      return saveFileToDevice(file: file, fileName: fileName);
    }

    await Share.shareXFiles(
      [XFile(file.path)],
      text: shareText,
      subject: shareSubject,
    );
    return null;
  }

  static Future<Directory> _writableExportDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final dir = Directory('${externalDir.path}/Bestandsaufnahme');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/Bestandsaufnahme');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> _writeBytesToDirectory(
    List<int> bytes,
    String fileName,
    String directory,
  ) async {
    final exportDir = Directory(directory);
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final targetPath = path.join(exportDir.path, fileName);
    await File(targetPath).writeAsBytes(bytes, flush: true);
    debugPrint('Datei gespeichert: $targetPath');
    return targetPath;
  }

  /// Speichert eine Datei über den nativen Datei-Dialog oder im App-Ordner.
  static Future<String?> saveFileToDevice({
    required File file,
    required String fileName,
  }) async {
    final bytes = await file.readAsBytes();
    try {
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Datei speichern',
        fileName: fileName,
        bytes: bytes,
      );
      if (savedPath != null) {
        debugPrint('Export gespeichert: $savedPath');
        return savedPath;
      }
      return null;
    } catch (e) {
      debugPrint('Speicher-Dialog fehlgeschlagen, speichere in App-Ordner: $e');
      final appDir = await _writableExportDirectory();
      return _writeBytesToDirectory(bytes, _sanitizeFileName(fileName), appDir.path);
    }
  }


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

