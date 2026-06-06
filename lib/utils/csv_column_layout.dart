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

/// Liest Hierarchie-Wert für Export.
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

  final fromHierarchy = csvSettings.hierarchyLevelValueFromParams(params, level);
  if (fromHierarchy != null && fromHierarchy.isNotEmpty) {
    return fromHierarchy;
  }

  for (final key in csvSettings.allParamKeysForHierarchyLevel(level)) {
    final value = csvSettings.paramValueForKey(params, key);
    if (value != null && value.isNotEmpty) return value;
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
      csvSettings.attributeTripletColumns.isNotEmpty &&
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
  final triplets = useGewerkeTriplets
      ? csvSettings.attributeTripletColumns
      : const <AttributeTripletColumn>[];
  final orderedFields = orderedAttributeSchemaFieldsForExport(
    discipline: exportDiscipline,
    csvSettings: csvSettings,
    params: params,
  );
  final handledImportCols = <int>{};

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

  void setExportCell(int importIndex, String value) {
    final exportCol = exportColForImportIndex(importIndex);
    if (exportCol >= 0 && exportCol < row.length) {
      row[exportCol] = value;
    }
  }

  for (var li = 0; li < csvSettings.enabledLevelsOrdered.length; li++) {
    final config = csvSettings.enabledLevelsOrdered[li];
    final levelNum = csvSettings.levelNumberAtEnabledIndex(li);

    final nameCol = config.nameColumn;
    if (nameCol >= 0 && nameCol < importHeaders.length) {
      setExportCell(
        nameCol,
        hierarchyExportValue(
              params,
              csvSettings,
              levelNum,
              disciplineLabel: anlage.discipline.label,
              leafName: anlage.name,
            ) ??
            '',
      );
      handledImportCols.add(nameCol);
    }

    if (config.useIdColumn && config.idColumn != null) {
      final idCol = config.idColumn!;
      if (idCol >= 0 && idCol < importHeaders.length) {
        final lfd = params['lfdNummer']?.toString().trim() ?? '';
        if (lfd.isNotEmpty) setExportCell(idCol, lfd);
        handledImportCols.add(idCol);
      }
    }
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
      _exportableAttributeParamEntries(params, csvSettings);

  for (var ti = 0; ti < triplets.length; ti++) {
    final triplet = triplets[ti];
    if (triplet.nameColumn >= 0 &&
        triplet.nameColumn < importHeaders.length) {
      setExportCell(
        triplet.nameColumn,
        attributeLabelAtAttSlot(ti + 1, orderedFields),
      );
      handledImportCols.add(triplet.nameColumn);
    }
    if (triplet.typeColumn >= 0) {
      handledImportCols.add(triplet.typeColumn);
    }
    if (triplet.optionsColumn >= 0) {
      handledImportCols.add(triplet.optionsColumn);
    }
    if (triplet.valueColumn >= 0 &&
        triplet.valueColumn < importHeaders.length) {
      setExportCell(
        triplet.valueColumn,
        _resolveTripletExportValue(
          slotIndex: ti,
          triplet: triplet,
          importHeaders: importHeaders,
          params: params,
          csvSettings: csvSettings,
          orderedFields: orderedFields,
          fallbackEntries: fallbackAttributeEntries,
        ),
      );
      handledImportCols.add(triplet.valueColumn);
    }
  }

  for (var pi = 0; pi < pairs.length; pi++) {
    final pair = pairs[pi];

    if (pair.nameColumn != pair.valueColumn &&
        pair.nameColumn >= 0 &&
        pair.nameColumn < importHeaders.length) {
      setExportCell(
        pair.nameColumn,
        attributeLabelAtAttSlot(
          CsvSettings.attSlotForPair(pair, pi),
          orderedFields,
        ),
      );
      handledImportCols.add(pair.nameColumn);
    }

    if (pair.valueColumn >= 0 && pair.valueColumn < importHeaders.length) {
      setExportCell(
        pair.valueColumn,
        _resolvePairExportValue(
          pairIndex: pi,
          pair: pair,
          headers: importHeaders,
          params: params,
          csvSettings: csvSettings,
          orderedFields: orderedFields,
          fallbackEntries: fallbackAttributeEntries,
        ),
      );
      handledImportCols.add(pair.valueColumn);
    }
  }

  for (var i = 0; i < importHeaders.length; i++) {
    if (handledImportCols.contains(i)) continue;

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
