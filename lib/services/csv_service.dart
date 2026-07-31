// lib/services/csv_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
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
import '../utils/app_log.dart';
import '../utils/csv_column_layout.dart';
import '../utils/csv_utils.dart';
import '../utils/csv_parse_isolate.dart';
import '../theme/app_palette.dart';
import 'package:flutter/foundation.dart';
import 'template_service.dart';

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

class _AttQuadrupletSlotIndices {
  final int nameColumn;
  final int typeColumn;
  final int optionsColumn;
  final int valueColumn;

  const _AttQuadrupletSlotIndices({
    required this.nameColumn,
    required this.typeColumn,
    this.optionsColumn = -1,
    required this.valueColumn,
  });
}

/// Layout wie Vorlagen-CSV: Hierarchie-Spalten (pro aktiver Ebene), dann ATT1…ATTn (+ TYPE, WERT).
class _TemplateStyleExportLayout {
  final List<String> headers;
  /// Spaltenindizes je aktiver Hierarchie-Ebene (Reihenfolge = Ebene 1…n).
  final List<int> hierarchyColumnIndices;
  final List<_AttQuadrupletSlotIndices> attSlots;

  const _TemplateStyleExportLayout({
    required this.headers,
    required this.hierarchyColumnIndices,
    required this.attSlots,
  });
}

enum _AnlagenExportRowMode {
  /// Export strikt nach gespeichertem [CsvSettings.importHeaderRow].
  importHeader,
  /// Gewerkevorlage ohne vorherigen Anlagen-CSV-Import.
  templateStyle,
  /// Spalten-Mapping ohne Import-Header.
  columnMapped,
}

class _AnlagenExportContext {
  final _AnlagenExportRowMode mode;
  final List<String> headerRow;
  final List<String> dataColumnKeys;
  final _TemplateStyleExportLayout? templateLayout;
  final bool useExtraExportColumns;
  final bool qrAppended;
  final List<int> appendedFotoIndices;

  const _AnlagenExportContext({
    required this.mode,
    required this.headerRow,
    required this.dataColumnKeys,
    this.templateLayout,
    this.useExtraExportColumns = false,
    this.qrAppended = false,
    this.appendedFotoIndices = const [],
  });
}

class CsvService {
  static const String _delimiter = ';';
  static const Uuid _uuid = Uuid();
  static const List<String> _emptyFotoNumbers = ['', '', '', ''];

  /// Baut die CSV-Header-Zeile: alle Daten-Spalten [dataColumnKeys] + ggf. angehängte Foto-/QR-Spalten.
  static List<String> _buildExportHeader(
    List<String> dataColumnKeys,
    List<String?> fotoLabels, {
    String? qrCodeLabel,
  }) {
    final headerRow = List<String>.from(dataColumnKeys);
    final existingSet = headerRow.toSet();
    final qr = qrCodeLabel?.trim() ?? '';
    if (qr.isNotEmpty && !existingSet.contains(qr)) {
      headerRow.add(qr);
      existingSet.add(qr);
    }
    for (int i = 0; i < 4; i++) {
      final t = fotoLabels[i]?.trim() ?? '';
      if (t.isNotEmpty && !existingSet.contains(t)) {
        headerRow.add(t);
        existingSet.add(t);
      }
    }
    return headerRow;
  }

  static bool _isQrAppended(List<String> dataColumnKeys, String? qrLabel) {
    final t = qrLabel?.trim() ?? '';
    return t.isNotEmpty && !dataColumnKeys.contains(t);
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

  /// Formatiert einen Param-Wert für eine CSV-Zelle.
  static String _paramValueToCsvCell(dynamic val) {
    if (val == null) return '';
    if (val is Map || val is List) return json.encode(val);
    return val.toString();
  }

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

  static String _schemaFieldParamKey(Map<String, dynamic> field) {
    return field['key']?.toString().trim() ?? '';
  }

  static String _schemaFieldLabel(Map<String, dynamic> field) {
    final label = field['label']?.toString().trim() ?? '';
    final key = _schemaFieldParamKey(field);
    return label.isNotEmpty ? label : key;
  }

  static Disziplin _disciplineForAnlage(Anlage anlage, List<Disziplin> disciplines) {
    final normalized = anlage.discipline.label.trim().toLowerCase();
    Disziplin? building;
    for (final d in disciplines) {
      if (d.label.trim().toLowerCase() == normalized) {
        building = d;
        break;
      }
    }
    if (building == null) return anlage.discipline;
    return mergeDisciplineForExport(base: building, stored: anlage.discipline);
  }

  /// Export-Zeile: Spalten strikt nach [CsvSettings.importHeaderRow] aus [Anlage.params].
  static List<String> _buildImportHeaderExportRow({
    required Anlage anlage,
    required CsvSettings csvSettings,
    required List<Disziplin> disciplines,
    List<String?> fotoLabels = const [null, null, null, null],
    List<String> fotoNumbers = _emptyFotoNumbers,
  }) {
    final row = buildAnlageExportRow(
      anlage: anlage,
      csvSettings: csvSettings,
      discipline: _disciplineForAnlage(anlage, disciplines),
    );
    final headerRow = csvSettings.importHeaderRow;
    final aligned = _alignExportRowLength(row, headerRow.length);

    final useFotoInColumns =
        fotoLabels.any((l) => l != null && l.trim().isNotEmpty);
    if (!useFotoInColumns) return aligned;

    final withFotos = List<String>.from(aligned);
    for (var col = 0; col < headerRow.length && col < withFotos.length; col++) {
      final label = headerRow[col];
      final fotoIdx = _fotoLabelIndex(label, fotoLabels);
      if (fotoIdx != null && fotoIdx < fotoNumbers.length) {
        withFotos[col] = fotoNumbers[fotoIdx];
      }
    }
    return withFotos;
  }

  /// Felder für eine Zeile: zuerst manuelle globale Attribute, dann Gewerk/RO-Schema.
  /// Datenzeile nur über konfigurierte Spaltennummern (kein Header-Matching).
  static List<String> _buildColumnMappedExportRow({
    required Anlage anlage,
    required CsvSettings csvSettings,
    required List<Disziplin> disciplines,
    required List<Map<String, dynamic>> globalSchema,
    required int targetLength,
  }) {
    final discipline = _disciplineForAnlage(anlage, disciplines);
    final row = buildAnlageExportRow(
      anlage: anlage,
      csvSettings: csvSettings,
      discipline: discipline,
    );
    if (csvSettings.importHeaderRow.isNotEmpty) {
      final expected = buildExportHeaderRow(csvSettings).length;
      if (row.length == expected) return List<String>.from(row);
      if (row.length > expected) return List<String>.from(row.sublist(0, expected));
      return List<String>.from([
        ...row,
        ...List.filled(expected - row.length, ''),
      ]);
    }
    if (row.length >= targetLength) {
      return List<String>.from(
        row.length == targetLength ? row : row.sublist(0, targetLength),
      );
    }
    return List<String>.from([
      ...row,
      ...List.filled(targetLength - row.length, ''),
    ]);
  }

  static List<Map<String, dynamic>> _orderedExportSchemaFields({
    required Anlage anlage,
    required Disziplin discipline,
    required List<Map<String, dynamic>> globalSchema,
    required CsvSettings csvSettings,
  }) {
    return exportAttributeSchemaFields(
      anlage: anlage,
      discipline: discipline,
      csvSettings: csvSettings,
    );
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

  /// Import-Header für Export: TYPE/OPTIONS entfernen, ART → WERT.
  static List<String> _templateHeadersForExport(List<String> importHeaders) {
    return CsvSettings.headersForAnlagenExport(importHeaders);
  }

  static void _setHeaderLabelIfEmpty(List<String> headers, int index, String label) {
    if (index < 0) return;
    while (headers.length <= index) {
      headers.add('');
    }
    if (headers[index].trim().isEmpty) {
      headers[index] = label;
    }
  }

  static void _ensureHeaderRowFitsColumns(
    List<String> headers,
    List<_AttQuadrupletSlotIndices> slots,
    CsvSettings csvSettings,
  ) {
    var maxIdx = 0;
    for (final slot in slots) {
      for (final col in [
        slot.nameColumn,
        slot.typeColumn,
        if (slot.optionsColumn >= 0) slot.optionsColumn,
        slot.valueColumn,
      ]) {
        if (col > maxIdx) maxIdx = col;
      }
    }
    for (var i = 0; i < csvSettings.enabledLevelsOrdered.length; i++) {
      final config = csvSettings.enabledLevelsOrdered[i];
      if (config.nameColumn > maxIdx) maxIdx = config.nameColumn;
      if (config.useIdColumn &&
          config.idColumn != null &&
          config.idColumn! > maxIdx) {
        maxIdx = config.idColumn!;
      }
    }
    while (headers.length <= maxIdx) {
      headers.add('');
    }
  }

  static List<_AttQuadrupletSlotIndices> _slotsFromQuadrupletSettings(
    List<AttributeTripletColumn> quadruplets,
  ) {
    return quadruplets
        .map(
          (q) => _AttQuadrupletSlotIndices(
            nameColumn: q.nameColumn,
            typeColumn: q.typeColumn,
            optionsColumn: q.optionsColumn,
            valueColumn: q.artColumn,
          ),
        )
        .toList();
  }

  static _TemplateStyleExportLayout _layoutFromConfiguredQuadruplets({
    required CsvSettings csvSettings,
    required int minAttSlots,
  }) {
    var slots = _slotsFromQuadrupletSettings(csvSettings.attributeTripletColumns);

    int nextFreeAfterSlots() {
      var maxIdx = 0;
      for (final slot in slots) {
        for (final col in [
          slot.nameColumn,
          slot.typeColumn,
          if (slot.optionsColumn >= 0) slot.optionsColumn,
          slot.valueColumn,
        ]) {
          if (col > maxIdx) maxIdx = col;
        }
      }
      for (final level in csvSettings.enabledLevelsOrdered) {
        if (level.nameColumn > maxIdx) maxIdx = level.nameColumn;
        if (level.useIdColumn &&
            level.idColumn != null &&
            level.idColumn! > maxIdx) {
          maxIdx = level.idColumn!;
        }
      }
      return maxIdx + 1;
    }

    while (slots.length < minAttSlots) {
      final base = nextFreeAfterSlots();
      slots.add(
        _AttQuadrupletSlotIndices(
          nameColumn: base,
          typeColumn: base + 1,
          valueColumn: base + 2,
        ),
      );
    }

    final working = csvSettings.importHeaderRow.isNotEmpty
        ? _templateHeadersForExport(csvSettings.importHeaderRow)
        : <String>[];

    _ensureHeaderRowFitsColumns(working, slots, csvSettings);

    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final n = i + 1;
      _setHeaderLabelIfEmpty(working, slot.nameColumn, 'ATT$n');
      _setHeaderLabelIfEmpty(working, slot.typeColumn, 'ATT${n}_TYPE');
      _setHeaderLabelIfEmpty(working, slot.valueColumn, 'ATT${n}_WERT');
    }

    final hierarchyCols = <int>[];
    for (var i = 0; i < csvSettings.enabledLevelsOrdered.length; i++) {
      final levelNum = csvSettings.levelNumberAtEnabledIndex(i);
      final config = csvSettings.enabledLevelsOrdered[i];
      final col = _resolveHierarchyColumnIndex(
        headers: working,
        csvSettings: csvSettings,
        level: levelNum,
        fallbackIndex: config.nameColumn,
      );
      hierarchyCols.add(col >= 0 ? col : config.nameColumn);
    }

    return _TemplateStyleExportLayout(
      headers: working,
      hierarchyColumnIndices: hierarchyCols,
      attSlots: slots,
    );
  }

  static List<_AttQuadrupletSlotIndices> _attSlotsFromSettings(
    CsvSettings csvSettings,
  ) {
    return _slotsFromQuadrupletSettings(csvSettings.attributeTripletColumns);
  }

  static List<String> _buildDefaultTemplateExportHeaders(
    int attSlotCount,
    CsvSettings csvSettings,
  ) {
    final headers = <String>[];
    final l1 = csvSettings.hierarchyLevelHeaderLabel(1);
    final l2 = csvSettings.hierarchyLevelHeaderLabel(2);
    if (l1.isNotEmpty) headers.add(l1);
    if (l2.isNotEmpty) headers.add(l2);
    if (headers.isEmpty) {
      headers.addAll([
        csvSettings.labelGewerk,
        csvSettings.labelAnlage,
      ]);
    }
    if (csvSettings.level3.enabled) {
      final l3 = csvSettings.hierarchyLevelHeaderLabel(3);
      if (l3.isNotEmpty) headers.add(l3);
    }
    for (var n = 1; n <= attSlotCount; n++) {
      headers.addAll(['ATT$n', 'ATT${n}_TYPE', 'ATT${n}_WERT']);
    }
    return headers;
  }

  static int _resolveHierarchyColumnIndex({
    required List<String> headers,
    required CsvSettings csvSettings,
    required int level,
    required int fallbackIndex,
  }) {
    final fromLabel = csvSettings.findHierarchyColumnInHeaders(headers, level);
    if (fromLabel >= 0) return fromLabel;

    if (fallbackIndex >= 0 && fallbackIndex < headers.length) {
      return fallbackIndex;
    }
    return -1;
  }

  static _TemplateStyleExportLayout _layoutFromHeaders(
    List<String> headers,
    int minAttSlots, {
    required CsvSettings csvSettings,
  }) {
    final working = List<String>.from(headers);
    var slots = _attSlotsFromSettings(csvSettings);
    if (slots.length < minAttSlots && slots.isNotEmpty) {
      slots = List<_AttQuadrupletSlotIndices>.from(slots);
    }

    final hierarchyCols = <int>[];
    for (var i = 0; i < csvSettings.enabledLevelsOrdered.length; i++) {
      final levelNum = csvSettings.levelNumberAtEnabledIndex(i);
      final config = csvSettings.enabledLevelsOrdered[i];
      final col = _resolveHierarchyColumnIndex(
        headers: working,
        csvSettings: csvSettings,
        level: levelNum,
        fallbackIndex: config.nameColumn,
      );
      hierarchyCols.add(col >= 0 ? col : config.nameColumn);
    }

    return _TemplateStyleExportLayout(
      headers: working,
      hierarchyColumnIndices: hierarchyCols,
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

    if (csvSettings.attributeTripletColumns.isNotEmpty) {
      return _layoutFromConfiguredQuadruplets(
        csvSettings: csvSettings,
        minAttSlots: minAttSlots,
      );
    }

    if (csvSettings.importHeaderRow.isNotEmpty) {
      final exportHeaders = _templateHeadersForExport(csvSettings.importHeaderRow);
      final parsed = _layoutFromHeaders(
        exportHeaders,
        minAttSlots,
        csvSettings: csvSettings,
      );
      if (parsed.attSlots.isNotEmpty) return parsed;
    }

    return _layoutFromHeaders(
      _buildDefaultTemplateExportHeaders(minAttSlots, csvSettings),
      minAttSlots,
      csvSettings: csvSettings,
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

    for (var i = 0; i < layout.hierarchyColumnIndices.length; i++) {
      final col = layout.hierarchyColumnIndices[i];
      if (col < 0 || col >= row.length) continue;
      final levelNum = csvSettings.levelNumberAtEnabledIndex(i);
      if (levelNum == 1 && csvSettings.level1IsDiscipline) {
        row[col] = anlage.discipline.label;
      } else {
        final value = csvSettings.hierarchyLevelValueFromParams(
              anlage.params,
              levelNum,
            ) ??
            (levelNum == csvSettings.schemaItemLevelNumber
                ? csvSettings.schemaItemValueFromParams(anlage.params)
                : null);
        row[col] = _paramValueToCsvCell(
          value ?? (levelNum == (csvSettings.leafLevel != null
                  ? csvSettings.levelNumberAtEnabledIndex(
                      csvSettings.enabledLevelsOrdered.length - 1)
                  : levelNum)
              ? anlage.name
              : ''),
        );
      }
    }

    final fields = _orderedExportSchemaFields(
      anlage: anlage,
      discipline: discipline,
      globalSchema: globalSchema,
      csvSettings: csvSettings,
    );

    for (var i = 0; i < layout.attSlots.length; i++) {
      final slot = layout.attSlots[i];
      final attSlot = i + 1;
      final field = CsvSettings.schemaFieldAtAttSlot(attSlot, fields);
      if (field == null) continue;

      final paramKey = _schemaFieldParamKey(field);
      final label = _schemaFieldLabel(field);
      if (slot.nameColumn >= 0 && slot.nameColumn < row.length) {
        row[slot.nameColumn] = label;
      }
      if (slot.valueColumn >= 0 && slot.valueColumn < row.length) {
        final value = csvSettings.readParamValue(anlage.params, paramKey) ??
            anlage.params[paramKey];
        row[slot.valueColumn] = _paramValueToCsvCell(value);
      }
    }

    return row;
  }

  /// Sortiert Anlagen für den Export so, dass Bauteile (child, parentId != null)
  /// direkt unter ihrer zugehörigen Anlage (parent) erscheinen.
  /// Nur echte Blatt-Datensätze exportieren (keine synthetischen Hierarchie-Knoten).
  static bool _isSyntheticHierarchyNode(Anlage anlage) {
    return anlage.params['__syntheticParent'] == true;
  }

  static List<Anlage> _leafAnlagenForExport(List<Anlage> anlagen) {
    return anlagen.where((a) => !_isSyntheticHierarchyNode(a)).toList();
  }

  /// Export-Reihenfolge: strikt nach Original-Zeilenindex beim Import.
  /// Synthetische Hierarchie-Knoten werden ausgeschlossen.
  static List<Anlage> _anlagenForCsvExport(
    List<Anlage> anlagen,
    CsvSettings csvSettings,
  ) {
    final leaves = _leafAnlagenForExport(anlagen);
    if (leaves.isEmpty) return leaves;

    return List<Anlage>.from(leaves)
      ..sort((a, b) {
        final rawA = a.params[CsvSettings.csvRowIndexParamKey];
        final rawB = b.params[CsvSettings.csvRowIndexParamKey];
        if (rawA == null && rawB == null) return 0;
        if (rawA == null) return 1;
        if (rawB == null) return -1;
        return compareAnlagenCsvRowIndex(a.params, b.params);
      });
  }

  static Future<_AnlagenExportContext> _resolveAnlagenExportContext({
    required List<Anlage> orderedAnlagen,
    required CsvSettings csvSettings,
    required List<Disziplin> disciplineList,
    required List<String?> fotoLabels,
    required bool useFotoColumns,
    String? projectId,
  }) async {
    final qrLabel = csvSettings.qrCodeNummerSpalteLabel;
    final useQrColumn = csvSettings.hasQrCodeExportColumn;
    final useExtra = useFotoColumns || useQrColumn;

    // 1:1-Export: gespeicherter Import-Header ist maßgeblich (kein Template-Umbau).
    if (csvSettings.importHeaderRow.isNotEmpty) {
      final keys = List<String>.from(csvSettings.importHeaderRow);
      final qrAppended = useQrColumn && _isQrAppended(keys, qrLabel);
      final appendedFotoIndices =
          useFotoColumns ? _appendedFotoIndices(keys, fotoLabels) : <int>[];
      final headerRow = useExtra
          ? _buildExportHeader(keys, fotoLabels, qrCodeLabel: qrLabel)
          : keys;
      return _AnlagenExportContext(
        mode: _AnlagenExportRowMode.importHeader,
        headerRow: headerRow,
        dataColumnKeys: keys,
        useExtraExportColumns: useExtra,
        qrAppended: qrAppended,
        appendedFotoIndices: appendedFotoIndices,
      );
    }

    if (csvSettings.attributeTripletColumns.isNotEmpty) {
      final layout = await _resolveTemplateStyleExportLayout(
        anlagen: orderedAnlagen,
        csvSettings: csvSettings,
        disciplines: disciplineList,
        projectId: projectId,
      );
      return _AnlagenExportContext(
        mode: _AnlagenExportRowMode.templateStyle,
        headerRow: List<String>.from(layout.headers),
        dataColumnKeys: List<String>.from(layout.headers),
        templateLayout: layout,
      );
    }

    final dataColumnKeys = buildExportHeaderRow(csvSettings);
    if (dataColumnKeys.isEmpty) {
      throw Exception(
        'Keine CSV-Spalten konfiguriert. Bitte Hierarchie- und Attribut-Spalten in den CSV-Einstellungen setzen.',
      );
    }
    final keys = dataColumnKeys;
    final qrAppended = useQrColumn && _isQrAppended(keys, qrLabel);
    final appendedFotoIndices =
        useFotoColumns ? _appendedFotoIndices(keys, fotoLabels) : <int>[];

    final headerRow = useExtra
        ? _buildExportHeader(keys, fotoLabels, qrCodeLabel: qrLabel)
        : (List<String>.from(keys)..addAll(['Foto1', 'Foto2', 'Foto3', 'Foto4']));

    return _AnlagenExportContext(
      mode: _AnlagenExportRowMode.columnMapped,
      headerRow: headerRow,
      dataColumnKeys: keys,
      useExtraExportColumns: useExtra,
      qrAppended: qrAppended,
      appendedFotoIndices: appendedFotoIndices,
    );
  }

  static List<String> _alignExportRowLength(List<String> row, int targetLength) {
    if (row.length == targetLength) return List<String>.from(row);
    if (row.length > targetLength) {
      return List<String>.from(row.sublist(0, targetLength));
    }
    return List<String>.from([
      ...row,
      ...List.filled(targetLength - row.length, ''),
    ]);
  }

  static List<String> _buildAnlageExportDataRow({
    required Anlage anlage,
    required _AnlagenExportContext context,
    required CsvSettings csvSettings,
    required List<Disziplin> disciplineList,
    required List<Map<String, dynamic>> globalSchema,
    List<String?> fotoLabels = const [null, null, null, null],
    List<String> fotoNumbers = _emptyFotoNumbers,
  }) {
    switch (context.mode) {
      case _AnlagenExportRowMode.importHeader:
        return _buildImportHeaderExportRow(
          anlage: anlage,
          csvSettings: csvSettings,
          disciplines: disciplineList,
          fotoLabels: fotoLabels,
          fotoNumbers: fotoNumbers,
        );

      case _AnlagenExportRowMode.templateStyle:
        return _buildTemplateStyleExportRow(
          anlage: anlage,
          layout: context.templateLayout!,
          csvSettings: csvSettings,
          disciplines: disciplineList,
          globalSchema: globalSchema,
        );

      case _AnlagenExportRowMode.columnMapped:
        return _buildColumnMappedExportRow(
          anlage: anlage,
          csvSettings: csvSettings,
          disciplines: disciplineList,
          globalSchema: globalSchema,
          targetLength: context.dataColumnKeys.length,
        );
    }
  }

  static void _appendExtraExportColumns(
    List<String> dataRow, {
    required Anlage anlage,
    required _AnlagenExportContext context,
    required bool useFotoColumns,
    List<String> fotoNumbers = _emptyFotoNumbers,
  }) {
    if (context.mode == _AnlagenExportRowMode.templateStyle) {
      return;
    }

    if (context.mode == _AnlagenExportRowMode.importHeader) {
      if (!context.useExtraExportColumns) return;
      if (context.qrAppended) {
        dataRow.add(
          anlage.params[CsvSettings.qrCodeNummerParamKey]?.toString().trim() ??
              '',
        );
      }
      if (useFotoColumns) {
        for (final i in context.appendedFotoIndices) {
          dataRow.add(i < fotoNumbers.length ? fotoNumbers[i] : '');
        }
      }
      return;
    }

    if (context.useExtraExportColumns) {
      if (context.qrAppended) {
        dataRow.add(
          anlage.params[CsvSettings.qrCodeNummerParamKey]?.toString().trim() ??
              '',
        );
      }
      if (useFotoColumns) {
        for (final i in context.appendedFotoIndices) {
          dataRow.add(i < fotoNumbers.length ? fotoNumbers[i] : '');
        }
      }
    } else {
      for (var i = 0; i < 4; i++) {
        dataRow.add(i < fotoNumbers.length ? fotoNumbers[i] : '');
      }
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

  /// Baut Schema-Felder aus ATT-Namen + TYPE einer Anlagen-CSV-Zeile
  /// (auch wenn ART/WERT leer ist – damit leere Eingabefelder erscheinen).
  static List<Map<String, dynamic>> _schemaFieldsFromAnlagenTripletRow({
    required List<dynamic> row,
    required List<String> headerRow,
    required List<AttributeTripletColumn> quadruplets,
  }) {
    final fields = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (var i = 0; i < quadruplets.length; i++) {
      final quad = quadruplets[i];
      if (quad.nameColumn < 0) continue;
      final nameCell = _safeCell(row, quad.nameColumn);
      if (nameCell.isEmpty || CsvSettings.isAnlagenCsvColumnParamKey(nameCell)) {
        continue;
      }
      if (CsvSettings.looksLikeTypeOrOptionsDefinition(nameCell)) {
        continue;
      }
      final nameHeader =
          quad.nameColumn < headerRow.length ? headerRow[quad.nameColumn] : '';
      final attSlot =
          CsvSettings.attNumberFromHeaderLabel(nameHeader) ?? (i + 1);

      var typeStr = '';
      if (quad.typeColumn >= 0) {
        typeStr = _safeCell(row, quad.typeColumn);
      }
      // TYPE-Spalte kann Options (a|b) oder Datentyp enthalten – nie als Feldwert.
      final entry = CsvSettings.schemaFieldFromGewerkeTypeCell(
        nameCell,
        typeStr,
      );
      entry['attSlot'] = attSlot;
      entry.remove('art'); // ART in Anlagen-CSV = Wert, nicht Schema-Gruppe
      final key = (entry['key'] ?? '').toString();
      if (key.isEmpty || seen.contains(key.toLowerCase())) continue;
      seen.add(key.toLowerCase());
      fields.add(entry);
    }
    return fields;
  }

  static void _mergeSchemaIntoDisciplineForRevisionsobjekt({
    required Disziplin discipline,
    required String revisionsobjekt,
    required List<Map<String, dynamic>> fields,
  }) {
    if (fields.isEmpty) return;
    final ro = revisionsobjekt.trim();
    if (ro.isEmpty) {
      // Kein RO: als individuelle Felder ans Flat-Schema hängen
      final existing = discipline.legacyIndividualSchemaFields;
      final merged = TemplateService.mergeSchemaFieldLists(existing, fields);
      final globals = discipline.globalSchemaFields;
      discipline.schema = [...globals, ...merged];
      return;
    }

    final existingKey = discipline.resolveRevisionsobjektKey(ro) ?? ro;
    final existing = discipline.revisionsobjektSchemas[existingKey] ??
        const <Map<String, dynamic>>[];
    final merged = TemplateService.mergeSchemaFieldLists(existing, fields);
    discipline.revisionsobjektSchemas = {
      ...discipline.revisionsobjektSchemas,
      existingKey: merged,
    };
  }

  /// Anlagen-CSV mit TYPE-Spalten: Wert nur aus ART/WERT-Spalte (leer = kein Wert).
  /// Schema-Feld kommt aus Gewerkevorlage; ATT-Slot aus Header-Nummer.
  static void _applyAnlagenAttributeParamsFromRow({
    required Map<String, dynamic> params,
    required List<dynamic> row,
    required List<String> headerRow,
    required List<AttributeTripletColumn> quadruplets,
    required Disziplin discipline,
    required CsvSettings settings,
  }) {
    final ro = settings.schemaItemValueFromParams(params)?.trim() ??
        settings.revisionsobjektValueFromParams(params)?.trim() ??
        '';

    // Schema aus ATT-Namen (+ TYPE) auch bei leerem Wert anlegen
    final schemaFromRow = _schemaFieldsFromAnlagenTripletRow(
      row: row,
      headerRow: headerRow,
      quadruplets: quadruplets,
    );
    _mergeSchemaIntoDisciplineForRevisionsobjekt(
      discipline: discipline,
      revisionsobjekt: ro,
      fields: schemaFromRow,
    );

    final schemaFields = <Map<String, dynamic>>[];
    for (final field in discipline.effectiveSchemaFor(revisionsobjekt: ro)) {
      if (field['isGlobal'] == true) continue;
      schemaFields.add(field);
    }

    for (var i = 0; i < quadruplets.length; i++) {
      final quad = quadruplets[i];
      final nameCol = quad.nameColumn;
      if (nameCol < 0) continue;

      final nameHeader = nameCol < headerRow.length ? headerRow[nameCol] : '';
      final attSlot =
          CsvSettings.attNumberFromHeaderLabel(nameHeader) ?? (i + 1);

      final nameCell = _safeCell(row, nameCol);
      var paramKey = '';
      final field = CsvSettings.schemaFieldAtAttSlot(attSlot, schemaFields);
      if (field != null) {
        paramKey = _schemaFieldParamKey(field);
      }
      if (paramKey.isEmpty && nameCell.isNotEmpty) {
        for (final schemaField in schemaFields) {
          final key = _schemaFieldParamKey(schemaField);
          final label = (schemaField['label'] ?? '').toString();
          if (CsvSettings.paramKeysMatch(key, nameCell) ||
              CsvSettings.paramKeysMatch(label, nameCell)) {
            paramKey = key;
            break;
          }
        }
        if (paramKey.isEmpty) {
          paramKey = _paramKeyForHeaderLabel(nameCell);
        }
      }
      if (paramKey.isEmpty) continue;

      // ATT-Slot immer merken (Export-Zuordnung), auch ohne Wert
      CsvSettings.writeAttSlotForParam(params, paramKey, attSlot);

      // Nur ART/WERT als Wert – TYPE/OPTIONS nie als Feldwert übernehmen.
      if (quad.valueColumn < 0) continue;
      if (quad.valueColumn == quad.typeColumn) continue;
      if (quad.valueColumn < headerRow.length &&
          CsvSettings.isGewerkeTypeDefinitionHeader(
            headerRow[quad.valueColumn],
          )) {
        continue;
      }
      final cellValue = _safeCell(row, quad.valueColumn);
      if (cellValue.isEmpty) continue;

      params[paramKey] = _parseDynamicValue(cellValue);
    }
  }

  /// Schema aus Name-Zellen des Paar-Formats (auch ohne Wert).
  static List<Map<String, dynamic>> _schemaFieldsFromAnlagenPairRow({
    required List<dynamic> row,
    required List<AttributeColumnPair> pairs,
  }) {
    final fields = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (var i = 0; i < pairs.length; i++) {
      final pair = pairs[i];
      if (pair.nameColumn < 0) continue;
      final nameCell = _safeCell(row, pair.nameColumn);
      if (nameCell.isEmpty || CsvSettings.isAnlagenCsvColumnParamKey(nameCell)) {
        continue;
      }
      if (seen.contains(nameCell.toLowerCase())) continue;
      seen.add(nameCell.toLowerCase());
      fields.add({
        'key': nameCell,
        'label': CsvSettings.normalizeFieldLabelForDisplay(nameCell),
        'type': 'text',
        'attSlot': CsvSettings.attSlotForPair(pair, i),
      });
    }
    return fields;
  }

  /// Anlagen-CSV (ATTn + ATTn_wert): Wert aus Wert-Spalte, Zuordnung über Gewerkevorlagen-Schema.
  static void _applyAnlagenAttributePairsFromRow({
    required Map<String, dynamic> params,
    required List<dynamic> row,
    required List<String> headerRow,
    required List<AttributeColumnPair> pairs,
    required Disziplin discipline,
    required CsvSettings settings,
  }) {
    final ro = settings.schemaItemValueFromParams(params)?.trim() ??
        settings.revisionsobjektValueFromParams(params)?.trim() ??
        '';

    final schemaFromRow = _schemaFieldsFromAnlagenPairRow(
      row: row,
      pairs: pairs,
    );
    _mergeSchemaIntoDisciplineForRevisionsobjekt(
      discipline: discipline,
      revisionsobjekt: ro,
      fields: schemaFromRow,
    );

    final schemaFields = <Map<String, dynamic>>[];
    for (final field in discipline.effectiveSchemaFor(revisionsobjekt: ro)) {
      if (field['isGlobal'] == true) continue;
      schemaFields.add(field);
    }

    for (var i = 0; i < pairs.length; i++) {
      final pair = pairs[i];
      final attSlot = CsvSettings.attSlotForPair(pair, i);
      if (pair.valueColumn < 0) continue;
      if (pair.valueColumn < headerRow.length &&
          CsvSettings.isGewerkeTypeDefinitionHeader(
            headerRow[pair.valueColumn],
          )) {
        continue;
      }
      final attrValue = _safeCell(row, pair.valueColumn);

      var paramKey = '';
      final field = CsvSettings.schemaFieldAtAttSlot(attSlot, schemaFields);
      if (field != null) {
        paramKey = _schemaFieldParamKey(field);
      }
      if (paramKey.isEmpty) {
        final nameCell = _safeCell(row, pair.nameColumn);
        if (nameCell.isNotEmpty) {
          for (final schemaField in schemaFields) {
            final key = _schemaFieldParamKey(schemaField);
            final label = (schemaField['label'] ?? '').toString();
            if (CsvSettings.paramKeysMatch(key, nameCell) ||
                CsvSettings.paramKeysMatch(label, nameCell)) {
              paramKey = key;
              break;
            }
          }
        }
      }
      if (paramKey.isEmpty) {
        final nameCell = _safeCell(row, pair.nameColumn);
        if (nameCell.isNotEmpty &&
            !CsvSettings.isAnlagenCsvColumnParamKey(nameCell)) {
          paramKey = _paramKeyForHeaderLabel(nameCell);
        }
      }
      if (paramKey.isEmpty &&
          pair.nameColumn >= 0 &&
          pair.nameColumn < headerRow.length) {
        final header = headerRow[pair.nameColumn].trim();
        if (header.isNotEmpty && !CsvSettings.isAnlagenCsvColumnParamKey(header)) {
          paramKey = _paramKeyForHeaderLabel(header);
        }
      }
      if (paramKey.isEmpty) continue;

      // ATT-Slot immer merken, auch ohne Wert
      CsvSettings.writeAttSlotForParam(params, paramKey, attSlot);
      if (attrValue.isEmpty) continue;

      final parsed = _parseDynamicValue(attrValue);
      params[paramKey] = parsed;
      if (pair.valueColumn >= 0 && pair.valueColumn < headerRow.length) {
        final valueHeader = headerRow[pair.valueColumn].trim();
        if (valueHeader.isNotEmpty) {
          params[valueHeader] = parsed;
        }
      }
    }
  }

  static Set<int> _reservedImportIndices({
    required CsvSettings settings,
    required List<AttributeColumnPair> attributePairs,
    required List<AttributeTripletColumn> attributeQuadruplets,
  }) {
    final indices = <int>{
      ...settings.reservedImportColumnIndices(),
    };
    for (final pair in attributePairs) {
      indices.add(pair.nameColumn);
      indices.add(pair.valueColumn);
    }
    for (final group in attributeQuadruplets) {
      indices.addAll(group.columnIndices);
    }
    return indices;
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
      appLog('Fehler beim Laden des globalen Schemas: $e');
      return [];
    }
  }

  static Future<void> _saveGlobalSchema(String projectId, List<Map<String, dynamic>> schema) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'global_schema_$projectId';
      await prefs.setString(key, json.encode(schema));
    } catch (e) {
      appLog('Fehler beim Speichern des globalen Schemas: $e');
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
        type: FileType.custom,
        allowedExtensions: const ['csv'],
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

      final delimiterMode = settings.delimiterMode;
      const headerZeile = 1;
      final useDisciplineGrouping = settings.level1.enabled;

      // Trennzeichen: Auto oder explizit
      String delimiter = _delimiter;
      if (delimiterMode == 'auto') {
        final firstLine = csvString.split('\n').first;
        delimiter = CsvUtils.detectDelimiterFromLine(firstLine);
      } else {
        delimiter = delimiterMode;
      }
      
      // CSV parsen (Isolate, damit große Dateien den UI-Thread nicht blockieren)
      final csvData = await compute(parseCsvRowsIsolate, {
        'csv': csvString,
        'delimiter': delimiter,
      });

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
      appLog('CSV Header: $headerRow');
      appLog('Anzahl Header-Spalten: ${headerRow.length}');

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
          appLog('Erste Datenzeile entspricht Header – wird übersprungen (evtl. headerZeile prüfen)');
          dataRows = dataRows.sublist(1);
        }
      }

      if (dataRows.isEmpty) {
        throw Exception('Keine Datenzeilen gefunden');
      }

      final importMapping = CsvSettings.resolveImportAttributeMapping(
        headerRow: headerRow,
        settings: settings,
      );
      final attributePairs = importMapping.pairs;
      final attributeQuadruplets = importMapping.quadruplets;

      // EAV: Spalten, die nicht zu Hierarchie-Ebenen oder Attribut-Spalten gehören.
      final reservedIndices = _reservedImportIndices(
        settings: settings,
        attributePairs: attributePairs,
        attributeQuadruplets: attributeQuadruplets,
      );
      final eavColumns = <int, String>{};
      final qrLabel = settings.qrCodeNummerSpalteLabel?.trim() ?? '';
      for (var i = 0; i < headerRow.length; i++) {
        if (reservedIndices.contains(i)) continue;
        final headerName = headerRow[i].trim();
        if (CsvSettings.isAnlagenCsvColumnParamKey(headerName)) continue;
        // Foto-/QR-Spalten bewusst als EAV mitimportieren (Labels nur für Export-Zuordnung
        // und zusätzlich QR → qrCodeNummer). So können Fotonummern/QR auch als Attribute
        // aus Anlagen-CSVs kommen.
        eavColumns[i] = headerName.isNotEmpty ? headerName : 'Spalte_${i + 1}';
      }

      // Schema-Einträge nur für EAV-Spalten (nicht für Hierarchie/Attribut-Paare)
      final schemaFromCsv = <Map<String, dynamic>>[];
      for (final entry in eavColumns.entries) {
        final headerName = entry.value;
        final lowerName = headerName.toLowerCase();

        String type = 'text';
        if (lowerName.contains('leistung') || lowerName.contains('kw') ||
            lowerName.contains('kapazität') || lowerName.contains('volumen') ||
            lowerName.contains('anzahl') || lowerName.contains('jahr')) {
          type = 'number';
        }

        if (CsvSettings.isAnlagenCsvColumnParamKey(headerName)) continue;

        schemaFromCsv.add({
          'key': headerName,
          'label': headerName,
          'type': type,
        });
      }


      // Bestehende Disziplinen für dieses Gebäude laden
      final disciplineCache = await _loadPersistedDisciplines(dbService, buildingId);
      appLog('Bestehende Disziplinen für Gebäude $buildingId: ${disciplineCache.keys.toList()}');

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

      appLog('Gefundene Disziplinen in CSV: $uniqueDisciplines');

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
          color: AppPalette.iconMuted,
          schema: <Map<String, dynamic>>[],
        );
        appLog('Neue Disziplin erstellt (ohne individuelles Schema): $discLabel');
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
      appLog('Disziplinen für Gebäude $buildingId gespeichert (global gesynct): ${disciplineCache.length}');

      // Anlagen aus CSV erstellen
      final anlagen = <Anlage>[];
      final syntheticNodeLfdByKey = <String, String>{};
      var syntheticNodeCounter = 0;

      for (var i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];

        // Hierarchie-Werte aller aktiven Ebenen (leere Zellen zählen nicht)
        final levelValues = <int, String>{};
        for (var li = 0; li < enabledLevels.length; li++) {
          final levelNum = settings.levelNumberAtEnabledIndex(li);
          final level = enabledLevels[li];
          final levelName = _safeCell(row, level.nameColumn).trim();
          if (levelName.isNotEmpty) {
            levelValues[levelNum] = levelName;
          }
        }

        final effectiveLeafNum =
            settings.resolveEffectiveLeafLevelNumber(levelValues);
        if (effectiveLeafNum == null) {
          appLog(
            'Zeile ${headerRowIndex + 2 + i} übersprungen: '
            'keine aktive Hierarchie-Ebene mit Wert',
          );
          continue;
        }

        final leafConfig =
            settings.hierarchyLevelConfig(effectiveLeafNum) ??
                settings.hierarchyLevelConfigAlways(effectiveLeafNum);
        final leafName = levelValues[effectiveLeafNum] ?? '';
        final leafId = leafConfig.useIdColumn && leafConfig.idColumn != null
            ? _safeCell(row, leafConfig.idColumn!).trim()
            : '';

        if (leafName.trim().isEmpty && leafId.isEmpty) {
          appLog(
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
          appLog('Zeile ${i + 1} übersprungen: Keine Disziplin angegeben');
          continue;
        }
        final disciplineLabelValue = disciplineLabel.trim();

        final lfdNummerValue = leafId.isNotEmpty
            ? leafId
            : settings.syntheticLfdForImportRow(
                rowIndex: i,
                contextLabel: disciplineLabelValue,
              );

        final discipline = disciplineCache[disciplineLabelValue.toLowerCase()];
        if (discipline == null) {
          appLog('Zeile ${i + 1} übersprungen: Disziplin "$disciplineLabelValue" nicht gefunden');
          continue;
        }

        final params = _parseParamsFromRow(row, eavColumns);
        params['lfdNummer'] = lfdNummerValue;
        if (qrLabel.isNotEmpty) {
          final qrIdx = settings.columnIndexForLabel(headerRow, qrLabel);
          if (qrIdx >= 0) {
            final qrVal = _safeCell(row, qrIdx);
            if (qrVal.isNotEmpty) {
              params[CsvSettings.qrCodeNummerParamKey] = qrVal;
            }
          }
        }

        if (levelValues.isNotEmpty) {
          settings.writeHierarchyPathToParams(params, levelValues: levelValues);
        } else if (useDisciplineGrouping) {
          final level1Key = settings.resolveHierarchyLevelParamKey(1);
          if (level1Key != null &&
              level1Key.isNotEmpty &&
              !settings.isLeafNameParamKey(level1Key)) {
            params[level1Key] = disciplineLabelValue;
          }
        }

        if (attributePairs.isNotEmpty) {
          _applyAnlagenAttributePairsFromRow(
            params: params,
            row: row,
            headerRow: headerRow,
            pairs: attributePairs,
            discipline: discipline,
            settings: settings,
          );
        } else if (attributeQuadruplets.isNotEmpty) {
          _applyAnlagenAttributeParamsFromRow(
            params: params,
            row: row,
            headerRow: headerRow,
            quadruplets: attributeQuadruplets,
            discipline: discipline,
            settings: settings,
          );
        }

        // Eltern = aktive Ebenen oberhalb des effektiven Blatts (mit Wert)
        String? immediateParentLfd;
        final pathSegments = <String>[];

        for (var li = 0; li < enabledLevels.length; li++) {
          final levelNum = settings.levelNumberAtEnabledIndex(li);
          if (levelNum >= effectiveLeafNum) break;
          // Ebene 1 = Disziplin-Tab → keinen synthetischen Parent
          if (useDisciplineGrouping &&
              settings.level1.enabled &&
              levelNum == 1) {
            continue;
          }

          final level = enabledLevels[li];
          final levelName = levelValues[levelNum]?.trim() ?? '';
          if (levelName.isEmpty) continue;

          final levelId = level.useIdColumn && level.idColumn != null
              ? _safeCell(row, level.idColumn!).trim()
              : '';
          final dedupeToken =
              levelId.isNotEmpty ? 'id:$levelId' : 'name:$levelName';
          pathSegments.add('${level.nameColumn}:$dedupeToken');
          final nodeKey =
              '${discipline.label}|$floorId|${pathSegments.join("|")}';

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
            settings.writeHierarchyLevelToParams(
                nodeParams, levelNum, levelName);
            if (levelId.isNotEmpty &&
                level.idColumn != null &&
                level.idColumn! < headerRow.length) {
              final idKey = headerRow[level.idColumn!].trim();
              if (idKey.isNotEmpty) nodeParams[idKey] = levelId;
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
            appLog('Hierarchie-Knoten "$levelName" (lfd: $nodeLfd)');
          }
          immediateParentLfd = nodeLfd;
        }

        if (immediateParentLfd != null) {
          params['__parentLfdNummer'] = immediateParentLfd;
        }

        captureCsvRowCellsToParams(
          headerRow: headerRow,
          row: row,
          params: params,
          rowIndex: i,
        );

        appLog(
          'Blatt $nameValue (lfd: $lfdNummerValue): Disziplin=$disciplineLabelValue, '
          'Parent=${params['__parentLfdNummer']}, leafLevel=$effectiveLeafNum',
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

      // Schema aus ATT-Namen (auch leere Werte) persistieren
      await _persistDisciplines(
        dbService,
        buildingId,
        disciplineCache.values.toList(),
      );

      appLog('Insgesamt ${anlagen.length} Anlagen erstellt');
      return CsvImportResult(
        anlagen: anlagen,
        importHeaderRow: headerRow,
        detectedDelimiter: delimiter,
      );
    } catch (e, stackTrace) {
      appLog('CSV-Import Fehler: $e');
      appLog('Stack Trace: $stackTrace');
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

      final orderedAnlagen = _anlagenForCsvExport(anlagen, csvSettings);
      var disciplineList = List<Disziplin>.from(disciplines);
      if (disciplineList.isEmpty &&
          dbService != null &&
          buildingId != null &&
          buildingId.isNotEmpty) {
        disciplineList = await dbService.getDisciplinesByBuildingId(buildingId);
      }

      List<Map<String, dynamic>> globalSchema = [];
      if (projectId != null && projectId.isNotEmpty) {
        globalSchema = await _loadGlobalSchema(projectId);
      }

      final exportContext = await _resolveAnlagenExportContext(
        orderedAnlagen: orderedAnlagen,
        csvSettings: csvSettings,
        disciplineList: disciplineList,
        fotoLabels: fotoLabels,
        useFotoColumns: useFotoColumns,
        projectId: projectId,
      );

      final csvData = <List<String>>[exportContext.headerRow];
      appLog(
        'CSV Export (${exportContext.mode.name}, ${orderedAnlagen.length} Zeilen, '
        '${exportContext.headerRow.length} Spalten)',
      );

      for (final anlage in orderedAnlagen) {
        final dataRow = _buildAnlageExportDataRow(
          anlage: anlage,
          context: exportContext,
          csvSettings: csvSettings,
          disciplineList: disciplineList,
          globalSchema: globalSchema,
          fotoLabels: fotoLabels,
        );
        _appendExtraExportColumns(
          dataRow,
          anlage: anlage,
          context: exportContext,
          useFotoColumns: useFotoColumns,
        );
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

      appLog('CSV-Export abgeschlossen: ${csvData.length - 1} Anlagen exportiert');

      return ExportBuiltFile(file: file, fileName: fileName);
    } catch (e, stackTrace) {
      appLog('CSV-Export Fehler: $e');
      appLog('Stack Trace: $stackTrace');
      throw Exception('Fehler beim CSV-Export: $e');
    }
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

    final orderedAnlagen = _anlagenForCsvExport(anlagen, csvSettings);
    var disciplineList = List<Disziplin>.from(disciplines);
    if (disciplineList.isEmpty &&
        dbService != null &&
        buildingId != null &&
        buildingId.isNotEmpty) {
      disciplineList = await dbService.getDisciplinesByBuildingId(buildingId);
    }

    List<Map<String, dynamic>> globalSchema = [];
    if (projectId != null && projectId.isNotEmpty) {
      globalSchema = await _loadGlobalSchema(projectId);
    }

    final exportContext = await _resolveAnlagenExportContext(
      orderedAnlagen: orderedAnlagen,
      csvSettings: csvSettings,
      disciplineList: disciplineList,
      fotoLabels: fotoLabels,
      useFotoColumns: useFotoColumns,
      projectId: projectId,
    );

    final csvData = <List<String>>[exportContext.headerRow];

    int neueAnlagenZaehler = 1;

    Directory fotosDir = Directory('${exportDir.path}/fotos');
    await fotosDir.create(recursive: true);

    final Map<String, Directory> gewerkDirs = {};

    for (final anlage in orderedAnlagen) {
      String lfdNummer = anlage.params['lfdNummer']?.toString() ?? '';
      if (lfdNummer.isEmpty) {
        lfdNummer = csvSettings.exportPlaceholderLfd(neueAnlagenZaehler);
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

      var dataRow = _buildAnlageExportDataRow(
        anlage: anlage,
        context: exportContext,
        csvSettings: csvSettings,
        disciplineList: disciplineList,
        globalSchema: globalSchema,
        fotoLabels: fotoLabels,
        fotoNumbers: fotoNumbers,
      );
      _appendExtraExportColumns(
        dataRow,
        anlage: anlage,
        context: exportContext,
        useFotoColumns: useFotoColumns,
        fotoNumbers: fotoNumbers,
      );

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

    appLog('ZIP erstellt: ${anlagen.length} Anlagen, ${fotoCounter - 1} Fotos');
    return zipFile;
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
    appLog('Datei gespeichert: $targetPath');
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
        appLog('Export gespeichert: $savedPath');
        return savedPath;
      }
      return null;
    } catch (e) {
      appLog('Speicher-Dialog fehlgeschlagen, speichere in App-Ordner: $e');
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

  /// Erstellt eine leere Anlagen-Vorlage-CSV mit dem korrekten Header des Projekts.
  /// Die Datei enthält nur die Headerzeile und kann vom Nutzer befüllt werden.
  static Future<ExportBuiltFile> buildAnlagenCsvTemplate({
    required CsvSettings csvSettings,
  }) async {
    try {
      final fotoLabels = [
        csvSettings.foto1SpalteLabel,
        csvSettings.foto2SpalteLabel,
        csvSettings.foto3SpalteLabel,
        csvSettings.foto4SpalteLabel,
      ];
      List<String> headerRow;
      if (csvSettings.importHeaderRow.isNotEmpty) {
        headerRow = List<String>.from(csvSettings.importHeaderRow);
      } else {
        final dataColumnKeys = buildExportHeaderRow(csvSettings);
        headerRow = _buildExportHeader(
          dataColumnKeys,
          fotoLabels,
          qrCodeLabel: csvSettings.qrCodeNummerSpalteLabel,
        );
      }

      final exportDelimiter = csvSettings.exportDelimiter.isNotEmpty
          ? csvSettings.exportDelimiter
          : _delimiter;
      final csvString = ListToCsvConverter(
        fieldDelimiter: exportDelimiter,
        eol: '\n',
      ).convert([headerRow]);

      final utf8Bom = [0xEF, 0xBB, 0xBF];
      final csvBytes = utf8Bom + utf8.encode(csvString);

      final directory = await getTemporaryDirectory();
      const fileName = 'anlagen_vorlage.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(csvBytes);

      appLog('Anlagen-Vorlage erstellt: ${headerRow.length} Spalten');
      return ExportBuiltFile(file: file, fileName: fileName);
    } catch (e) {
      appLog('Anlagen-Vorlage Fehler: $e');
      throw Exception('Fehler beim Erstellen der Vorlage: $e');
    }
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

