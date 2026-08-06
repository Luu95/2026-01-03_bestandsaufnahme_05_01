// lib/utils/csv_column_layout.dart

import '../models/anlage.dart';
import '../models/disziplin_schnittstelle.dart';
import '../providers/csv_settings_provider.dart';

/// Größter verwendeter Spaltenindex (0-basiert) aus den CSV-Einstellungen.
int maxConfiguredColumnIndex(CsvSettings csvSettings) {
  if (csvSettings.importHeaderRow.isNotEmpty) {
    return csvSettings.importHeaderRow.length - 1;
  }

  var maxIdx = -1;
  void bump(int col) {
    if (col > maxIdx) maxIdx = col;
  }

  for (final level in csvSettings.enabledLevelsOrdered) {
    bump(level.nameColumn);
    if (level.useIdColumn && level.idColumn != null) {
      bump(level.idColumn!);
    }
  }
  if (csvSettings.anlageBauteilSpalte != null) {
    bump(csvSettings.anlageBauteilSpalte!);
  }
  if (csvSettings.displayNameSpalte != null) {
    bump(csvSettings.displayNameSpalte!);
  }
  for (final group in csvSettings.attributeTripletColumns) {
    for (final col in group.columnIndices) {
      bump(col);
    }
  }
  for (final pair in csvSettings.attributeColumnPairs) {
    bump(pair.nameColumn);
    bump(pair.valueColumn);
  }
  if (csvSettings.hasQrCodeExportColumn) {
    final qrIdx = csvSettings.columnIndexForLabel(
      csvSettings.importHeaderRow,
      csvSettings.qrCodeNummerSpalteLabel,
    );
    if (qrIdx >= 0) bump(qrIdx);
  }
  return maxIdx;
}

/// Header-Zeile für Export: identisch zur Import-CSV (importHeaderRow).
List<String> buildExportHeaderRow(CsvSettings csvSettings) {
  if (csvSettings.importHeaderRow.isNotEmpty) {
    return List<String>.from(csvSettings.importHeaderRow);
  }

  final maxIdx = maxConfiguredColumnIndex(csvSettings);
  if (maxIdx < 0) return const [];

  final headers = <String>[];
  while (headers.length <= maxIdx) {
    headers.add('');
  }
  return headers;
}

String _safeCell(List<dynamic> row, int index) {
  if (index < 0 || index >= row.length) return '';
  return row[index].toString().trim();
}

String _cellValue(dynamic value) {
  if (value == null) return '';
  if (value is Map || value is List) {
    return value.toString();
  }
  return value.toString();
}

/// Spaltenindizes der Hierarchie-Ebenen (dürfen bei 1:1-Export nicht durch Formularwerte überschrieben werden).
Set<int> hierarchyExportColumnIndices(
  CsvSettings csvSettings,
  List<String> headers,
) {
  final cols = <int>{};
  void addCol(int? col) {
    if (col != null && col >= 0 && col < headers.length) cols.add(col);
  }

  void addByLabel(String? label) {
    final t = label?.trim() ?? '';
    if (t.isEmpty) return;
    for (var i = 0; i < headers.length; i++) {
      if (CsvSettings.paramKeysMatch(headers[i], t)) addCol(i);
    }
  }

  // Immer: Header „Ebene1“/„Ebene2“/„Ebene3“ schützen.
  for (var i = 0; i < headers.length; i++) {
    if (CsvSettings.isEbeneHierarchyHeader(headers[i])) addCol(i);
  }

  for (var level = 1; level <= 3; level++) {
    addCol(csvSettings.findHierarchyColumnInHeaders(headers, level));
    switch (level) {
      case 1:
        addByLabel(csvSettings.labelGewerk);
        break;
      case 2:
        addByLabel(csvSettings.labelAnlage);
        break;
      case 3:
        addByLabel(csvSettings.labelBauteil);
        break;
    }
  }
  addByLabel(csvSettings.resolveSchemaItemParamKey());
  addByLabel(csvSettings.resolveRevisionsobjektGroupingParamKey());

  addCol(csvSettings.level1.nameColumn);
  addCol(csvSettings.level2.nameColumn);
  addCol(csvSettings.level3.nameColumn);
  if (csvSettings.level1.useIdColumn) addCol(csvSettings.level1.idColumn);
  if (csvSettings.level2.useIdColumn) addCol(csvSettings.level2.idColumn);
  if (csvSettings.level3.useIdColumn) addCol(csvSettings.level3.idColumn);

  for (final level in csvSettings.enabledLevelsOrdered) {
    addCol(level.nameColumn);
    if (level.useIdColumn) addCol(level.idColumn);
  }
  return cols;
}

/// Speichert die CSV-Zeile unverändert (Header → Zelle) in [params].
void captureCsvRowCellsToParams({
  required List<String> headerRow,
  required List<dynamic> row,
  required Map<String, dynamic> params,
  required int rowIndex,
}) {
  final cells = <String, String>{};
  for (var i = 0; i < headerRow.length; i++) {
    final header = headerRow[i].trim();
    if (header.isEmpty) continue;
    cells[header] = _safeCell(row, i);
  }
  params[CsvSettings.csvRowCellsParamKey] = cells;
  params[CsvSettings.csvRowIndexParamKey] = rowIndex;
}

bool hasCsvRowCellsForExport(Map<String, dynamic> params) {
  final raw = params[CsvSettings.csvRowCellsParamKey];
  return raw is Map && raw.isNotEmpty;
}

Map<String, String> csvRowCellsFromParams(Map<String, dynamic> params) {
  final raw = params[CsvSettings.csvRowCellsParamKey];
  if (raw is! Map) return const {};
  return raw.map(
    (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
  );
}

/// Export-Zeile 1:1 aus gespeicherten CSV-Zellen (keine Sortierung/Umordnung).
List<String> buildExportRowFromCsvRowCells(
  Map<String, dynamic> params,
  List<String> headerRow,
) {
  final cells = csvRowCellsFromParams(params);
  return headerRow
      .map((header) => cells[header.trim()] ?? '')
      .toList(growable: false);
}

int csvRowIndexFromParams(Map<String, dynamic> params) {
  final raw = params[CsvSettings.csvRowIndexParamKey];
  if (raw is int) return raw;
  if (raw is String) return int.tryParse(raw.trim()) ?? 0;
  return 0;
}

int compareAnlagenCsvRowIndex(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  return csvRowIndexFromParams(a).compareTo(csvRowIndexFromParams(b));
}

/// True, wenn alle Blatt-Anlagen gespeicherte Import-Zellen haben und der
/// Export 1:1 wie die Import-CSV ausgegeben werden kann.
bool canRoundTripAnlagenCsvExport(
  CsvSettings csvSettings,
  List<Anlage> leafAnlagen,
) {
  if (csvSettings.importHeaderRow.isEmpty) return false;
  if (leafAnlagen.isEmpty) return false;
  return leafAnlagen.every((a) => hasCsvRowCellsForExport(a.params));
}

/// Interne Param-Keys (Validierung etc.) nicht als CSV-Attribute exportieren.
bool isInternalExportParamKey(String key) {
  final k = key.trim();
  if (k.isEmpty) return true;
  if (k.startsWith('__')) return true;
  if (CsvSettings.isAttSlotParamKey(k)) return true;
  if (k.startsWith('_field_')) return true;
  if (k.startsWith('_') &&
      (k.endsWith('_validated') || k.endsWith('_missing'))) {
    return true;
  }
  return k == '_validated' ||
      k == '_validatedAt' ||
      k == 'validated' ||
      k == 'validatedAt';
}

/// Gebäude-Disziplin mit gespeichertem Anlagen-Schema für Export zusammenführen.
Disziplin mergeDisciplineForExport({
  required Disziplin base,
  required Disziplin stored,
}) {
  final baseKeys = base.schema
      .map((f) => (f['key'] ?? '').toString())
      .where((k) => k.isNotEmpty)
      .toSet();
  final additional = stored.schema
      .where((f) {
        final k = (f['key'] ?? '').toString();
        return k.isNotEmpty && !baseKeys.contains(k);
      })
      .map((f) => Map<String, dynamic>.from(f))
      .toList();

  final mergedRoSchemas =
      Map<String, List<Map<String, dynamic>>>.from(base.revisionsobjektSchemas);
  for (final entry in stored.revisionsobjektSchemas.entries) {
    final existing = mergedRoSchemas[entry.key];
    if (existing == null || existing.isEmpty) {
      mergedRoSchemas[entry.key] =
          entry.value.map((f) => Map<String, dynamic>.from(f)).toList();
    }
  }

  return Disziplin(
    label: base.label,
    icon: base.icon,
    color: base.color,
    schema: [...base.schema, ...additional],
    groupingKey: base.groupingKey,
    revisionsobjektSchemas: mergedRoSchemas,
  );
}

String _revisionsobjektForExport(
  CsvSettings csvSettings,
  Map<String, dynamic> params,
) {
  return csvSettings.schemaItemValueFromParams(params)?.trim() ??
      csvSettings.revisionsobjektValueFromParams(params)?.trim() ??
      '';
}

List<MapEntry<String, dynamic>> _exportableAttributeParamEntries(
  Map<String, dynamic> params,
  CsvSettings csvSettings,
) {
  final entries = <MapEntry<String, dynamic>>[];
  for (final e in params.entries) {
    final k = e.key.toString().trim();
    if (k.isEmpty) continue;
    if (isInternalExportParamKey(k)) continue;
    if (CsvSettings.isAnlagenCsvColumnParamKey(k)) continue;
    if (CsvSettings.isReservedDialogParamKey(k, csvSettings)) continue;
    final v = e.value?.toString().trim() ?? '';
    if (v.isEmpty) continue;
    entries.add(MapEntry(k, e.value));
  }
  return entries;
}

/// Wie [_exportableAttributeParamEntries], sortiert nach Import-ATT-Slot (nicht alphabetisch).
List<MapEntry<String, dynamic>> _exportableAttributeParamEntriesBySlot(
  Map<String, dynamic> params,
  CsvSettings csvSettings,
) {
  const noSlot = 999;
  final entries = _exportableAttributeParamEntries(params, csvSettings);
  entries.sort((a, b) {
    final slotA = CsvSettings.attSlotForParam(params, a.key) ?? noSlot;
    final slotB = CsvSettings.attSlotForParam(params, b.key) ?? noSlot;
    if (slotA == noSlot && slotB == noSlot) {
      return a.key.compareTo(b.key);
    }
    return slotA.compareTo(slotB);
  });
  return entries;
}

Map<String, dynamic>? _schemaFieldAtAttSlot(
  int attSlot,
  List<Map<String, dynamic>> orderedFields,
) {
  return CsvSettings.schemaFieldAtAttSlot(attSlot, orderedFields);
}

/// Attribut-Bezeichnung für festen ATT-Slot (unabhängig vom Wert).
String attributeLabelAtAttSlot(
  int attSlot,
  List<Map<String, dynamic>> orderedFields,
) {
  final field = _schemaFieldAtAttSlot(attSlot, orderedFields);
  if (field == null) return '';
  final key = (field['key'] ?? '').toString().trim();
  final label = CsvSettings.normalizeFieldLabelForDisplay(
    (field['label'] ?? key).toString(),
  );
  return label.isNotEmpty ? label : key;
}

/// Param-Key des Attributs, das beim Import den ATT-Slot [attSlot] hatte.
String? paramKeyForAttSlot(Map<String, dynamic> params, int attSlot) {
  if (attSlot <= 0) return null;
  for (final entry in params.entries) {
    final k = entry.key.toString().trim();
    if (k.isEmpty || CsvSettings.isAttSlotParamKey(k)) continue;
    if (CsvSettings.attSlotForParam(params, k) == attSlot) return k;
  }
  return null;
}

/// Anzeigename für einen Param-Key (Schema-Label oder Key).
String displayLabelForParamKey(
  String paramKey,
  List<Map<String, dynamic>> orderedFields,
) {
  for (final field in orderedFields) {
    final key = (field['key'] ?? '').toString().trim();
    if (CsvSettings.paramKeysMatch(key, paramKey)) {
      final label = CsvSettings.normalizeFieldLabelForDisplay(
        (field['label'] ?? key).toString(),
      );
      return label.isNotEmpty ? label : key;
    }
  }
  return paramKey;
}

void _appendExportSchemaField(
  List<Map<String, dynamic>> target,
  Set<String> seen,
  Map<String, dynamic> field,
  CsvSettings csvSettings,
) {
  if (field['isGlobal'] == true) return;
  final key = (field['key'] ?? '').toString().trim();
  if (key.isEmpty || seen.contains(key)) return;
  if (isInternalExportParamKey(key)) return;
  if (csvSettings.isUpperHierarchyParamKey(key)) return;
  if (csvSettings.isLeafNameParamKey(key)) return;
  seen.add(key);
  target.add(Map<String, dynamic>.from(field));
}

/// RO-spezifische Schema-Felder in fester Import-Reihenfolge (ein Slot = ein ATT-Paar).
List<Map<String, dynamic>> orderedAttributeSchemaFieldsForExport({
  required Disziplin discipline,
  required CsvSettings csvSettings,
  required Map<String, dynamic> params,
}) {
  final ro = _revisionsobjektForExport(csvSettings, params);
  final result = <Map<String, dynamic>>[];
  final seen = <String>{};

  for (final field in discipline.effectiveSchemaFor(revisionsobjekt: ro)) {
    _appendExportSchemaField(result, seen, field, csvSettings);
  }

  if (result.isEmpty) {
    for (final field in discipline.legacyIndividualSchemaFields) {
      _appendExportSchemaField(result, seen, field, csvSettings);
    }
  }

  for (final field in CsvSettings.schemaFieldsFromParams(
    params,
    settings: csvSettings,
  )) {
    _appendExportSchemaField(result, seen, field, csvSettings);
  }

  return result;
}

List<String> _lookupKeysForPairSlot({
  required int attSlot,
  required AttributeColumnPair pair,
  required List<String> headers,
  required List<Map<String, dynamic>> orderedFields,
}) {
  final keys = <String>[];
  void add(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return;
    for (final existing in keys) {
      if (CsvSettings.paramKeysMatch(existing, t)) return;
    }
    keys.add(t);
  }

  if (pair.valueColumn >= 0 && pair.valueColumn < headers.length) {
    add(headers[pair.valueColumn]);
  }

  final field = _schemaFieldAtAttSlot(attSlot, orderedFields);
  if (field != null) {
    add(field['key']?.toString());
    add(field['label']?.toString());
    add(CsvSettings.normalizeFieldLabelForDisplay(field['label']?.toString()));
  }

  add(attributeLabelAtAttSlot(attSlot, orderedFields));

  if (pair.nameColumn >= 0 && pair.nameColumn < headers.length) {
    final nameHeader = headers[pair.nameColumn].trim();
    if (!CsvSettings.isAnlagenCsvColumnParamKey(nameHeader)) {
      add(nameHeader);
    }
  }

  return keys;
}

String? _paramValueForPairSlot({
  required int attSlot,
  required AttributeColumnPair pair,
  required List<String> headers,
  required Map<String, dynamic> params,
  required CsvSettings csvSettings,
  required List<Map<String, dynamic>> orderedFields,
  required List<MapEntry<String, dynamic>> fallbackEntries,
}) {
  final lookupKeys = _lookupKeysForPairSlot(
    attSlot: attSlot,
    pair: pair,
    headers: headers,
    orderedFields: orderedFields,
  );

  for (final key in lookupKeys) {
    final v = _exportParamValue(params, csvSettings, key);
    if (v != null && v.isNotEmpty) return v;
  }

  for (final key in lookupKeys) {
    for (final entry in params.entries) {
      final paramKey = entry.key.toString().trim();
      if (paramKey.isEmpty) continue;
      if (CsvSettings.isReservedDialogParamKey(paramKey, csvSettings)) continue;
      if (!CsvSettings.paramKeysMatch(paramKey, key)) continue;
      final v = entry.value?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
  }

  for (final entry in fallbackEntries) {
    for (final key in lookupKeys) {
      if (CsvSettings.paramKeysMatch(entry.key, key)) {
        final v = entry.value?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
    }
  }

  return null;
}

String _resolvePairExportValue({
  required int pairIndex,
  required AttributeColumnPair pair,
  required List<String> headers,
  required Map<String, dynamic> params,
  required CsvSettings csvSettings,
  required List<Map<String, dynamic>> orderedFields,
  required List<MapEntry<String, dynamic>> fallbackEntries,
}) {
  final attSlot = CsvSettings.attSlotForPair(pair, pairIndex);
  return _paramValueForPairSlot(
    attSlot: attSlot,
    pair: pair,
    headers: headers,
    params: params,
    csvSettings: csvSettings,
    orderedFields: orderedFields,
    fallbackEntries: fallbackEntries,
  ) ??
      '';
}

/// Attribut-Schema für Export – gleiche Reihenfolge wie beim Anlagen-Import.
List<Map<String, dynamic>> exportAttributeSchemaFields({
  required Anlage anlage,
  required Disziplin discipline,
  required CsvSettings csvSettings,
}) {
  return orderedAttributeSchemaFieldsForExport(
    discipline: discipline,
    csvSettings: csvSettings,
    params: anlage.params,
  );
}

List<AttributeColumnPair> _effectiveAttributePairs(
  CsvSettings csvSettings,
  List<String> headers,
) {
  // Spaltenpositionen immer aus dem gespeicherten Import-Header (kein Verschieben).
  if (csvSettings.importHeaderRow.isNotEmpty) {
    final fromImport = CsvSettings.detectAnlagenAttributePairsFromHeader(headers);
    if (fromImport.isNotEmpty) return fromImport;
  }
  if (csvSettings.attributeColumnPairs.isNotEmpty) {
    return csvSettings.attributeColumnPairs;
  }
  return CsvSettings.detectAnlagenAttributePairsFromHeader(headers);
}

List<AttributeTripletColumn> _effectiveAttributeTriplets(
  CsvSettings csvSettings,
  List<String> headers,
) {
  if (headers.isNotEmpty) {
    final detected = CsvSettings.detectQuadrupletsFromHeader(headers);
    if (detected.isNotEmpty) return detected;
  }
  if (csvSettings.attributeTripletColumns.isNotEmpty) {
    return csvSettings.attributeTripletColumns;
  }
  return const [];
}

/// Wert für einen ATT-Slot: zuerst Slot-Key, sonst Schema-/Header-Lookup.
String _resolveSlotOrPairExportValue({
  required String? slotParamKey,
  required int pairIndex,
  required AttributeColumnPair pair,
  required List<String> headers,
  required Map<String, dynamic> params,
  required CsvSettings csvSettings,
  required List<Map<String, dynamic>> orderedFields,
  required List<MapEntry<String, dynamic>> fallbackEntries,
}) {
  if (slotParamKey != null && slotParamKey.trim().isNotEmpty) {
    final fromSlot = csvSettings.paramValueForKey(params, slotParamKey) ??
        params[slotParamKey]?.toString().trim();
    if (fromSlot != null && fromSlot.trim().isNotEmpty) {
      return fromSlot.trim();
    }
  }
  return _resolvePairExportValue(
    pairIndex: pairIndex,
    pair: pair,
    headers: headers,
    params: params,
    csvSettings: csvSettings,
    orderedFields: orderedFields,
    fallbackEntries: fallbackEntries,
  );
}

/// Liest Hierarchie-Wert für Export.
/// Kein Anzeigename/Bezeichnung als Fallback für Schema-/RO-Ebenen (sonst landet
/// z. B. „test1“ in Ebene2 statt dem festen Revisionsobjekt).
String? hierarchyExportValue(
  Map<String, dynamic> params,
  CsvSettings csvSettings,
  int level, {
  String? disciplineLabel,
  String? leafName,
}) {
  if (level == 1 && csvSettings.level1IsDiscipline) {
    return disciplineLabel?.trim();
  }

  final displayName = csvSettings.displayNameValueFromParams(params)?.trim() ??
      csvSettings.paramValueForKey(params, 'Bezeichnung')?.trim() ??
      '';

  bool isLikelyDisplayNameLeak(String value) {
    if (displayName.isEmpty) return false;
    if (csvSettings.schemaItemLevelNumber != level) return false;
    return value.trim() == displayName;
  }

  final fromHierarchy = csvSettings.hierarchyLevelValueFromParams(params, level);
  if (fromHierarchy != null &&
      fromHierarchy.isNotEmpty &&
      !isLikelyDisplayNameLeak(fromHierarchy)) {
    return fromHierarchy;
  }

  // Direkter Header-Key (Ebene1/Ebene2/…) – ohne Anzeigename-Fallback.
  for (final key in csvSettings.allParamKeysForHierarchyLevel(level)) {
    if (csvSettings.isLeafNameParamKey(key)) continue;
    if (CsvSettings.paramKeysMatch(key, 'Bezeichnung')) continue;
    final value = csvSettings.paramValueForKey(params, key);
    if (value != null &&
        value.isNotEmpty &&
        !isLikelyDisplayNameLeak(value)) {
      return value;
    }
  }

  // Schema-/RO-Ebene: niemals Anzeigename als Hierarchie-Wert.
  if (csvSettings.schemaItemLevelNumber == level) {
    return null;
  }

  final leaf = csvSettings.leafLevel;
  if (leaf != null &&
      csvSettings.levelNumberForConfig(leaf) == level &&
      leafName != null &&
      leafName.trim().isNotEmpty) {
    return leafName.trim();
  }
  return null;
}

/// TYPE-Zelle aus Schema-Feld (text / number / Opt1|Opt2).
String typeExportCellFromSchemaField(Map<String, dynamic>? field) {
  if (field == null) return '';
  final type = (field['type'] ?? '').toString().trim().toLowerCase();
  final options = field['options'];
  if (options is List && options.isNotEmpty) {
    return options.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join('|');
  }
  if (type == 'dropdown' || type == 'select') return '';
  if (type.isEmpty) return 'text';
  return type;
}

/// Fallback für leere Wert-/ART-Spalte: Schema-`art` (z. B. „Allgemein“).
String artFallbackFromSchemaField(Map<String, dynamic>? field) {
  if (field == null) return '';
  return CsvSettings.normalizeFieldLabelForDisplay(field['art']?.toString());
}

String? _exportParamValue(
  Map<String, dynamic> params,
  CsvSettings csvSettings,
  String paramKey,
) {
  final key = paramKey.trim();
  if (key.isEmpty) return null;
  return csvSettings.paramValueForKey(params, key) ??
      params[key]?.toString().trim();
}

String _resolveTripletExportValue({
  required int slotIndex,
  required AttributeTripletColumn triplet,
  required List<String> importHeaders,
  required Map<String, dynamic> params,
  required CsvSettings csvSettings,
  required List<Map<String, dynamic>> orderedFields,
  required List<MapEntry<String, dynamic>> fallbackEntries,
}) {
  final pseudoPair = AttributeColumnPair(
    nameColumn: triplet.nameColumn,
    valueColumn: triplet.valueColumn,
    attNumber: slotIndex + 1,
  );
  return _resolvePairExportValue(
    pairIndex: slotIndex,
    pair: pseudoPair,
    headers: importHeaders,
    params: params,
    csvSettings: csvSettings,
    orderedFields: orderedFields,
    fallbackEntries: fallbackEntries,
  );
}

/// Export-Zeile in Struktur ohne TYPE/OPTIONS-Spalten (Bezeichnung + Wert).
/// Mit [preserveFullImportHeader] bleibt das exakte Import-Spaltenlayout erhalten;
/// geänderte Werte kommen aus [params], leere Metadaten-Spalten aus gespeicherten Import-Zellen.
List<String> buildAnlageExportRowFromImportStructure({
  required Anlage anlage,
  required CsvSettings csvSettings,
  Disziplin? discipline,
  bool preserveFullImportHeader = false,
}) {
  final importHeaders = csvSettings.importHeaderRow;
  if (importHeaders.isEmpty) return const [];

  final useGewerkeTriplets = !preserveFullImportHeader &&
      (csvSettings.attributeTripletColumns.isNotEmpty ||
          CsvSettings.detectQuadrupletsFromHeader(importHeaders).isNotEmpty) &&
      CsvSettings.headerLooksLikeGewerkeQuadrupletFormat(importHeaders);
  final headers = useGewerkeTriplets
      ? CsvSettings.headersForAnlagenExport(importHeaders)
      : importHeaders;

  final exportDiscipline = discipline ?? anlage.discipline;
  final row = List<String>.filled(headers.length, '');
  final params = anlage.params;
  final pairs = useGewerkeTriplets
      ? const <AttributeColumnPair>[]
      : _effectiveAttributePairs(csvSettings, importHeaders);
  // 1:1-Header: wenn keine WERT-Paare, Tripletts für Wert-Overlay (ART-Spalten).
  final triplets = useGewerkeTriplets
      ? _effectiveAttributeTriplets(csvSettings, importHeaders)
      : (preserveFullImportHeader && pairs.isEmpty
          ? _effectiveAttributeTriplets(csvSettings, importHeaders)
          : const <AttributeTripletColumn>[]);
  final orderedFields = orderedAttributeSchemaFieldsForExport(
    discipline: exportDiscipline,
    csvSettings: csvSettings,
    params: params,
  );
  final handledImportCols = <int>{};
  final hierarchyCols =
      hierarchyExportColumnIndices(csvSettings, importHeaders);
  final storedCells = hasCsvRowCellsForExport(params)
      ? csvRowCellsFromParams(params)
      : const <String, String>{};

  // Basis: gespeicherte Import-Zellen 1:1 (ATT-Namen/Positionen bleiben erhalten).
  if (preserveFullImportHeader && storedCells.isNotEmpty) {
    for (var i = 0; i < importHeaders.length; i++) {
      final header = importHeaders[i].trim();
      if (header.isNotEmpty) {
        row[i] = storedCells[header] ?? '';
      }
    }
  }

  int exportColForImportIndex(int importIndex) {
    if (preserveFullImportHeader || !useGewerkeTriplets) return importIndex;
    var exportCol = 0;
    for (var i = 0; i < importHeaders.length; i++) {
      if (CsvSettings.isGewerkeTypeDefinitionHeader(importHeaders[i])) {
        continue;
      }
      if (i == importIndex) return exportCol;
      exportCol++;
    }
    return -1;
  }

  void setExportCell(
    int importIndex,
    String value, {
    bool allowHierarchyOverwrite = false,
  }) {
    // Hierarchie-Ebenen nicht durch Attribut-/Rest-Mapping überschreiben.
    // Erlaubt nur bei explizitem Hierarchie-Write aus Params.
    if (hierarchyCols.contains(importIndex) &&
        !allowHierarchyOverwrite) {
      return;
    }
    final exportCol = exportColForImportIndex(importIndex);
    if (exportCol >= 0 && exportCol < row.length) {
      row[exportCol] = value;
    }
  }

  // Hierarchie-Spalten immer als belegt markieren (auch ohne Überschreiben).
  handledImportCols.addAll(hierarchyCols);

  void writeHierarchyCol(int nameCol, int levelNum) {
    if (nameCol < 0 || nameCol >= importHeaders.length) return;
    final v = hierarchyExportValue(
      params,
      csvSettings,
      levelNum,
      disciplineLabel: anlage.discipline.label,
      leafName: anlage.name,
    );
    if (v != null && v.isNotEmpty) {
      setExportCell(nameCol, v, allowHierarchyOverwrite: true);
    }
    handledImportCols.add(nameCol);
  }

  for (var li = 0; li < csvSettings.enabledLevelsOrdered.length; li++) {
    final config = csvSettings.enabledLevelsOrdered[li];
    final levelNum = csvSettings.levelNumberAtEnabledIndex(li);
    writeHierarchyCol(config.nameColumn, levelNum);

    if (config.useIdColumn && config.idColumn != null) {
      final idCol = config.idColumn!;
      if (idCol >= 0 && idCol < importHeaders.length) {
        final lfd = params['lfdNummer']?.toString().trim() ?? '';
        if (lfd.isNotEmpty) {
          setExportCell(idCol, lfd, allowHierarchyOverwrite: true);
        }
        handledImportCols.add(idCol);
      }
    }
  }

  // Explizit Ebene1/2/3 aus Hierarchie-Params (auch wenn Config-Index abweicht).
  for (var i = 0; i < importHeaders.length; i++) {
    if (!CsvSettings.isEbeneHierarchyHeader(importHeaders[i])) continue;
    final n = int.tryParse(
      importHeaders[i].replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (n == null || n < 1 || n > 3) continue;
    writeHierarchyCol(i, n);
  }

  final abCol = csvSettings.anlageBauteilSpalte;
  if (abCol != null && abCol >= 0 && abCol < importHeaders.length) {
    final ab = csvSettings.anlageBauteilValueFromParams(params);
    if (ab != null && ab.isNotEmpty) {
      setExportCell(abCol, ab);
      handledImportCols.add(abCol);
    }
  }

  final fallbackAttributeEntries =
      _exportableAttributeParamEntriesBySlot(params, csvSettings);

  for (var ti = 0; ti < triplets.length; ti++) {
    final triplet = triplets[ti];
    final nameHeader = (triplet.nameColumn >= 0 &&
            triplet.nameColumn < importHeaders.length)
        ? importHeaders[triplet.nameColumn]
        : '';
    final attSlot =
        CsvSettings.attNumberFromHeaderLabel(nameHeader) ?? (ti + 1);
    final slotParamKey = paramKeyForAttSlot(params, attSlot);
    final schemaField = _schemaFieldAtAttSlot(attSlot, orderedFields);

    if (triplet.nameColumn >= 0) {
      handledImportCols.add(triplet.nameColumn);
    }
    if (triplet.typeColumn >= 0) {
      handledImportCols.add(triplet.typeColumn);
    }
    if (triplet.optionsColumn >= 0) {
      handledImportCols.add(triplet.optionsColumn);
    }
    if (triplet.valueColumn >= 0) {
      handledImportCols.add(triplet.valueColumn);
    }

    if (triplet.nameColumn >= 0 &&
        triplet.nameColumn < importHeaders.length &&
        (!preserveFullImportHeader || storedCells.isEmpty)) {
      final labelKey = slotParamKey ??
          attributeLabelAtAttSlot(attSlot, orderedFields);
      if (labelKey.isNotEmpty) {
        setExportCell(
          triplet.nameColumn,
          slotParamKey != null
              ? displayLabelForParamKey(slotParamKey, orderedFields)
              : labelKey,
        );
      }
    }

    // TYPE/OPTIONS: aus Schema (Vorlage), sonst Import-Snapshot behalten.
    if (triplet.typeColumn >= 0 &&
        triplet.typeColumn < importHeaders.length) {
      final typeCell = typeExportCellFromSchemaField(schemaField);
      if (typeCell.isNotEmpty) {
        final exportCol = exportColForImportIndex(triplet.typeColumn);
        final already = (exportCol >= 0 && exportCol < row.length)
            ? row[exportCol].trim()
            : '';
        if (already.isEmpty) {
          setExportCell(triplet.typeColumn, typeCell);
        }
      }
    }
    if (triplet.optionsColumn >= 0 &&
        triplet.optionsColumn < importHeaders.length) {
      final typeCell = typeExportCellFromSchemaField(schemaField);
      if (typeCell.contains('|')) {
        final exportCol = exportColForImportIndex(triplet.optionsColumn);
        final already = (exportCol >= 0 && exportCol < row.length)
            ? row[exportCol].trim()
            : '';
        if (already.isEmpty) {
          setExportCell(triplet.optionsColumn, typeCell);
        }
      }
    }

    if (triplet.valueColumn >= 0 &&
        triplet.valueColumn < importHeaders.length) {
      final value = _resolveSlotOrPairExportValue(
        slotParamKey: slotParamKey,
        pairIndex: ti,
        pair: AttributeColumnPair(
          nameColumn: triplet.nameColumn,
          valueColumn: triplet.valueColumn,
          attNumber: attSlot,
        ),
        headers: importHeaders,
        params: params,
        csvSettings: csvSettings,
        orderedFields: orderedFields,
        fallbackEntries: fallbackAttributeEntries,
      );
      if (value.isNotEmpty) {
        setExportCell(triplet.valueColumn, _cellValue(value));
      } else if (!useGewerkeTriplets) {
        // Volllayout mit ART-Spalte: Gruppentitel aus Schema wieder in ART schreiben.
        final exportCol = exportColForImportIndex(triplet.valueColumn);
        final already = (exportCol >= 0 && exportCol < row.length)
            ? row[exportCol].trim()
            : '';
        if (already.isEmpty) {
          final artFallback = artFallbackFromSchemaField(schemaField);
          if (artFallback.isNotEmpty) {
            setExportCell(triplet.valueColumn, artFallback);
          }
        }
      }
      // useGewerkeTriplets: ART→WERT-Export – Gruppentitel nicht als Anlagenwert schreiben.
    }
  }

  for (var pi = 0; pi < pairs.length; pi++) {
    final pair = pairs[pi];
    final attSlot = CsvSettings.attSlotForPair(pair, pi);
    final slotParamKey = paramKeyForAttSlot(params, attSlot);

    if (pair.nameColumn >= 0) handledImportCols.add(pair.nameColumn);
    if (pair.valueColumn >= 0) handledImportCols.add(pair.valueColumn);

    if (pair.nameColumn != pair.valueColumn &&
        pair.nameColumn >= 0 &&
        pair.nameColumn < importHeaders.length &&
        (!preserveFullImportHeader || storedCells.isEmpty)) {
      final label = slotParamKey != null
          ? displayLabelForParamKey(slotParamKey, orderedFields)
          : attributeLabelAtAttSlot(attSlot, orderedFields);
      if (label.isNotEmpty) {
        setExportCell(pair.nameColumn, label);
      }
    }

    if (pair.valueColumn >= 0 && pair.valueColumn < importHeaders.length) {
      final value = _resolveSlotOrPairExportValue(
        slotParamKey: slotParamKey,
        pairIndex: pi,
        pair: pair,
        headers: importHeaders,
        params: params,
        csvSettings: csvSettings,
        orderedFields: orderedFields,
        fallbackEntries: fallbackAttributeEntries,
      );
      if (value.isNotEmpty) {
        setExportCell(pair.valueColumn, _cellValue(value));
      }
    }
  }

  for (var i = 0; i < importHeaders.length; i++) {
    if (handledImportCols.contains(i)) continue;
    if (hierarchyCols.contains(i)) continue;

    final header = importHeaders[i].trim();
    if (header.isEmpty) continue;
    if (!preserveFullImportHeader &&
        CsvSettings.isGewerkeTypeDefinitionHeader(header)) {
      continue;
    }

    String? cellValue;
    if (CsvSettings.paramKeysMatch(header, CsvSettings.qrCodeNummerParamKey)) {
      final qr =
          params[CsvSettings.qrCodeNummerParamKey]?.toString().trim() ?? '';
      if (qr.isNotEmpty) cellValue = qr;
    } else if (CsvSettings.isAnlagenCsvColumnParamKey(header)) {
      final direct = params[header]?.toString().trim();
      if (direct != null && direct.isNotEmpty) {
        cellValue = _cellValue(direct);
      }
    } else {
      // Keine Param-Werte in Hierarchie-Header schreiben (Prefix-Match-Schutz).
      if (csvSettings.isUpperHierarchyParamKey(header) ||
          csvSettings.isHierarchyParamKey(header)) {
        continue;
      }
      final val = _exportParamValue(params, csvSettings, header);
      if (val != null && val.isNotEmpty) {
        cellValue = _cellValue(val);
      }
    }

    if (cellValue != null) {
      setExportCell(i, cellValue);
    }
  }

  if (preserveFullImportHeader) {
    // Nur Metadaten-Spalten (TYPE/OPTIONS) aus Import-Zellen auffüllen,
    // wenn sie in params nicht vorkommen – Attributwerte bleiben aus params.
    final stored = csvRowCellsFromParams(params);
    for (var i = 0; i < importHeaders.length; i++) {
      final header = importHeaders[i].trim();
      if (header.isEmpty) continue;
      if (!CsvSettings.isGewerkeTypeDefinitionHeader(header)) continue;
      final exportCol = exportColForImportIndex(i);
      if (exportCol < 0 || exportCol >= row.length) continue;
      if (row[exportCol].isNotEmpty) continue;
      final fallback = stored[header];
      if (fallback != null && fallback.isNotEmpty) {
        row[exportCol] = fallback;
      }
    }
  }

  return row;
}

/// Baut eine Export-Zeile (Import-Struktur bevorzugt, sonst Spalten-Mapping).
List<String> buildAnlageExportRow({
  required Anlage anlage,
  required CsvSettings csvSettings,
  Disziplin? discipline,
}) {
  if (csvSettings.importHeaderRow.isNotEmpty) {
    // Strikter 1:1-Export: exakt der gespeicherte Import-Header, keine Spalten-Umordnung.
    return buildAnlageExportRowFromImportStructure(
      anlage: anlage,
      csvSettings: csvSettings,
      discipline: discipline,
      preserveFullImportHeader: true,
    );
  }

  final maxIdx = maxConfiguredColumnIndex(csvSettings);
  if (maxIdx < 0) return const [];

  final row = List<String>.filled(maxIdx + 1, '', growable: true);

  for (var i = 0; i < csvSettings.enabledLevelsOrdered.length; i++) {
    final levelNum = csvSettings.levelNumberAtEnabledIndex(i);
    final config = csvSettings.enabledLevelsOrdered[i];
    final value = hierarchyExportValue(
      anlage.params,
      csvSettings,
      levelNum,
      disciplineLabel: anlage.discipline.label,
      leafName: anlage.name,
    );
    if (value != null && config.nameColumn >= 0 && config.nameColumn < row.length) {
      row[config.nameColumn] = value;
    }
    if (config.useIdColumn &&
        config.idColumn != null &&
        config.idColumn! >= 0 &&
        config.idColumn! < row.length) {
      final lfd = anlage.params['lfdNummer']?.toString().trim() ?? '';
      if (lfd.isNotEmpty) {
        row[config.idColumn!] = lfd;
      }
    }
  }

  final displayCol = csvSettings.displayNameSpalte;
  if (displayCol != null && displayCol >= 0 && displayCol < row.length) {
    final display =
        csvSettings.displayNameValueFromParams(anlage.params)?.trim();
    if (display != null && display.isNotEmpty) {
      row[displayCol] = display;
    } else if (anlage.name.trim().isNotEmpty) {
      row[displayCol] = anlage.name.trim();
    }
  }

  return row;
}

/// Hierarchie-Spaltenindizes nur aus Einstellungen (kein Header-Abgleich).
List<int> hierarchyColumnIndicesFromSettings(CsvSettings csvSettings) =>
    csvSettings.hierarchyNameColumnIndices();

/// Spalte für Anzeige/Bezeichnung in Vorlagenzeilen (Ebene 3 oder konfiguriert).
int? templateBezeichnungColumnIndex(CsvSettings csvSettings) {
  if (csvSettings.level3.enabled) {
    return csvSettings.level3.nameColumn;
  }
  final displayCol = csvSettings.displayNameSpalte;
  if (displayCol != null && displayCol >= 0) return displayCol;
  final levels = hierarchyColumnIndicesFromSettings(csvSettings);
  if (levels.length >= 2) return levels[1];
  return levels.isNotEmpty ? levels.first : null;
}

/// Liest eine CSV-Zeile für Gewerkevorlagen-Import (nur Spaltennummern).
({String gewerk, String schemaItem, String bezeichnung}) readTemplateHierarchyFromRow(
  List<dynamic> row,
  CsvSettings csvSettings,
) {
  final levels = hierarchyColumnIndicesFromSettings(csvSettings);
  final gewerkIdx = levels.isNotEmpty ? levels.first : 0;
  final schemaLevel = csvSettings.schemaItemLevelNumber ?? 2;
  final schemaIdx = levels.length >= schemaLevel
      ? levels[schemaLevel - 1]
      : (levels.length >= 2 ? levels[1] : gewerkIdx);
  final bezIdx = templateBezeichnungColumnIndex(csvSettings) ?? schemaIdx;

  final gewerk = _safeCell(row, gewerkIdx);
  final schemaItem = _safeCell(row, schemaIdx);
  final bezeichnung = bezIdx == schemaIdx
      ? schemaItem
      : _safeCell(row, bezIdx);

  return (
    gewerk: gewerk,
    schemaItem: schemaItem,
    bezeichnung: bezeichnung.isEmpty ? schemaItem : bezeichnung,
  );
}
