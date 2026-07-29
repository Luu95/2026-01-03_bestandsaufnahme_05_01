// lib/providers/csv_settings_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/csv_hierarchy_level.dart';

/// Ein explizites Paar: eine Spalte für den Attributnamen, eine für den Attributwert.
class AttributeColumnPair {
  final int nameColumn;
  final int valueColumn;
  /// Feste ATT-Nummer (1 = ATT1, 2 = ATT2, …), aus CSV-Header erkannt.
  final int? attNumber;

  const AttributeColumnPair({
    required this.nameColumn,
    required this.valueColumn,
    this.attNumber,
  });

  Map<String, dynamic> toJson() => {
        'nameColumn': nameColumn,
        'valueColumn': valueColumn,
        if (attNumber != null) 'attNumber': attNumber,
      };

  factory AttributeColumnPair.fromJson(Map<String, dynamic> json) {
    return AttributeColumnPair(
      nameColumn: json['nameColumn'] as int? ?? 0,
      valueColumn: json['valueColumn'] as int? ?? 0,
      attNumber: json['attNumber'] as int?,
    );
  }
}

/// Dreiergruppe pro Attribut: Name, Typ (Freitext/number/Opt1|Opt2), Wert/Art.
/// [optionsColumn] nur für Legacy-Vierer-CSV (separate OPTIONS-Spalte), sonst -1.
class AttributeTripletColumn {
  final int nameColumn;
  final int typeColumn;
  final int optionsColumn;
  final int artColumn;

  const AttributeTripletColumn({
    required this.nameColumn,
    required this.typeColumn,
    this.optionsColumn = -1,
    required this.artColumn,
  });

  Map<String, dynamic> toJson() => {
        'nameColumn': nameColumn,
        'typeColumn': typeColumn,
        if (optionsColumn >= 0) 'optionsColumn': optionsColumn,
        'artColumn': artColumn,
      };

  factory AttributeTripletColumn.fromJson(Map<String, dynamic> json) {
    final name = json['nameColumn'] as int? ?? 0;
    final type = json['typeColumn'] as int? ?? 0;
    final options = json['optionsColumn'] as int? ?? -1;
    final art = json['artColumn'] as int? ??
        (options >= 0 ? options + 1 : type + 1);
    return AttributeTripletColumn(
      nameColumn: name,
      typeColumn: type,
      optionsColumn: options,
      artColumn: art,
    );
  }

  /// Spaltenindizes dieser Gruppe (ohne ungenutzte Legacy-Spalten).
  List<int> get columnIndices {
    final cols = <int>[nameColumn, typeColumn];
    if (optionsColumn >= 0 && optionsColumn != typeColumn) {
      cols.add(optionsColumn);
    }
    if (artColumn >= 0) cols.add(artColumn);
    return cols;
  }

  /// Wert-Spalte für Anlagen-Export (Art/WERT).
  int get valueColumn => artColumn;
}

/// Ergebnis der Header-Analyse: Zweier- oder Vierer-Mapping für einen Import.
class ImportAttributeMapping {
  final List<AttributeColumnPair> pairs;
  final List<AttributeTripletColumn> quadruplets;

  const ImportAttributeMapping({
    this.pairs = const [],
    this.quadruplets = const [],
  });
}

class CsvSettings {
  /// Interner Param-Key für die QR-Code-Nummer in Anlagen-Params.
  static const qrCodeNummerParamKey = 'qrCodeNummer';

  /// Rohe CSV-Zellen pro Header-Label (Import → Export 1:1).
  static const csvRowCellsParamKey = '__csvRowCells';

  /// Import-Reihenfolge (0-basiert, keine Sortierung beim Export).
  static const csvRowIndexParamKey = '__csvRowIndex';

  /// Merkt sich den ATT-Slot (Spaltenposition) je Attribut-Param-Key.
  static const attSlotParamKeyPrefix = '_att_slot_';

  static String attSlotParamKey(String paramKey) =>
      '$attSlotParamKeyPrefix$paramKey';

  static bool isAttSlotParamKey(String key) =>
      key.startsWith(attSlotParamKeyPrefix);

  static int? attSlotForParam(Map<String, dynamic> params, String paramKey) {
    final raw = params[attSlotParamKey(paramKey)];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  static void writeAttSlotForParam(
    Map<String, dynamic> params,
    String paramKey,
    int attSlot,
  ) {
    params[attSlotParamKey(paramKey)] = attSlot;
  }

  final HierarchyLevelConfig level1;
  final HierarchyLevelConfig level2;
  final HierarchyLevelConfig level3;
  /// Legacy: A/B-Spalte für alte CSV-Formate (optional).
  final int? anlageBauteilSpalte;
  final String delimiterMode;
  final String anlageKuerzel;
  final String bauteilKuerzel;
  final bool useDisciplineGrouping;
  final String labelGewerk;
  final String labelAnlage;
  final String labelBauteil;
  final List<AttributeColumnPair> attributeColumnPairs;
  /// Attribut-Dreiergruppen: Name, Typ, Wert/Art (wird aus Header erkannt, falls leer).
  final List<AttributeTripletColumn> attributeTripletColumns;
  final String? foto1SpalteLabel;
  final String? foto2SpalteLabel;
  final String? foto3SpalteLabel;
  final String? foto4SpalteLabel;
  /// Spalten-Label für QR-Code-Nummer beim CSV-Export. Leer = Spalte nicht verwenden.
  final String? qrCodeNummerSpalteLabel;
  final List<String> importHeaderRow;
  final String exportDelimiter;
  final String groupingGewerkParamKey;
  final String groupingAnlageParamKey;
  /// Expliziter Param-Key für Anzeige Ebene 3 (Gewerkevorlagen / Neuaufnahme), z. B. „Name“.
  final String displayNameParamKey;
  /// Optional: Spalte aus Anlagen-CSV-Import (nur wenn importHeaderRow gesetzt ist).
  final int? displayNameSpalte;

  const CsvSettings({
    required this.level1,
    required this.level2,
    required this.level3,
    this.anlageBauteilSpalte,
    required this.delimiterMode,
    required this.anlageKuerzel,
    required this.bauteilKuerzel,
    required this.useDisciplineGrouping,
    required this.labelGewerk,
    required this.labelAnlage,
    required this.labelBauteil,
    this.attributeColumnPairs = const [],
    this.attributeTripletColumns = const [],
    this.foto1SpalteLabel,
    this.foto2SpalteLabel,
    this.foto3SpalteLabel,
    this.foto4SpalteLabel,
    this.qrCodeNummerSpalteLabel,
    this.importHeaderRow = const [],
    this.exportDelimiter = ';',
    this.groupingGewerkParamKey = '',
    this.groupingAnlageParamKey = '',
    this.displayNameParamKey = 'Name',
    this.displayNameSpalte,
  });

  /// True, wenn mindestens einmal ein Anlagen-CSV-Import durchgeführt wurde.
  bool get hasAnlagenCsvImport => importHeaderRow.isNotEmpty;

  /// Alle aktiven Ebenen in Reihenfolge (1 → 2 → 3).
  List<HierarchyLevelConfig> get enabledLevelsOrdered {
    final levels = <HierarchyLevelConfig>[];
    if (level1.enabled) levels.add(level1);
    if (level2.enabled) levels.add(level2);
    if (level3.enabled) levels.add(level3);
    return levels;
  }

  /// Unterste aktive Ebene = Blatt (ein CSV-Datensatz pro Zeile).
  HierarchyLevelConfig? get leafLevel {
    final levels = enabledLevelsOrdered;
    return levels.isEmpty ? null : levels.last;
  }

  String? _headerLabelAt(int? columnIndex) {
    if (columnIndex == null || columnIndex < 0 || columnIndex >= importHeaderRow.length) {
      return null;
    }
    final label = importHeaderRow[columnIndex].trim();
    return label.isEmpty ? null : label;
  }

  /// Konfiguriertes Header-/Anzeige-Label für Hierarchie-Ebene [level] (1–3).
  String hierarchyLevelHeaderLabel(int level) {
    final config = _hierarchyLevelConfig(level);
    if (config == null) return '';
    final fromHeader = _headerLabelAt(config.nameColumn);
    if (fromHeader != null && fromHeader.isNotEmpty) return fromHeader;
    switch (level) {
      case 1:
        return labelGewerk;
      case 2:
        return labelAnlage;
      case 3:
        return labelBauteil;
      default:
        return '';
    }
  }

  /// 1-basierte Level-Nummer für den Index in [enabledLevelsOrdered].
  int levelNumberAtEnabledIndex(int enabledIndex) {
    var seen = 0;
    for (var level = 1; level <= 3; level++) {
      if (_hierarchyLevelConfig(level) == null) continue;
      if (seen == enabledIndex) return level;
      seen++;
    }
    return enabledIndex + 1;
  }

  /// 1-basierte Level-Nummer für eine [HierarchyLevelConfig].
  int levelNumberForConfig(HierarchyLevelConfig config) {
    for (var level = 1; level <= 3; level++) {
      final c = _hierarchyLevelConfig(level);
      if (c != null && c.nameColumn == config.nameColumn) return level;
    }
    return 1;
  }

  /// Spaltenindizes der Namens-Spalten aller aktiven Hierarchie-Ebenen.
  List<int> hierarchyNameColumnIndices() =>
      enabledLevelsOrdered.map((l) => l.nameColumn).toList();

  void _addDistinctParamKey(Set<String> keys, String candidate) {
    final c = candidate.trim();
    if (c.isEmpty) return;
    for (final existing in keys) {
      if (paramKeysMatch(existing, c)) return;
    }
    keys.add(c);
  }

  /// Param-Keys für Import/Export – nur aus Einstellungen, nicht aus CSV-Überschriften.
  List<String> configuredHierarchyParamKeys(int level) {
    final keys = <String>{};
    switch (level) {
      case 1:
        _addDistinctParamKey(keys, groupingGewerkParamKey);
        _addDistinctParamKey(keys, labelGewerk);
        break;
      case 2:
        _addDistinctParamKey(keys, groupingAnlageParamKey);
        _addDistinctParamKey(keys, labelAnlage);
        for (final legacy in legacySchemaItemParamKeys) {
          _addDistinctParamKey(keys, legacy);
        }
        break;
      case 3:
        _addDistinctParamKey(keys, displayNameParamKey);
        _addDistinctParamKey(keys, labelBauteil);
        break;
    }
    return keys.toList();
  }

  /// Param-Key für Hierarchie-Ebene [level] (1–3), nur aus Einstellungen.
  String? resolveHierarchyLevelParamKey(int level) {
    final keys = configuredHierarchyParamKeys(level);
    return keys.isEmpty ? null : keys.first;
  }

  /// Liest den Wert einer Hierarchie-Ebene aus Params.
  String? hierarchyLevelValueFromParams(
    Map<String, dynamic> params,
    int level, {
    List<String> legacyKeys = const [],
  }) {
    final key = resolveHierarchyLevelParamKey(level);
    if (key == null || key.isEmpty) return null;
    final legacy = level == schemaItemLevelNumber
        ? [...legacyKeys, ...legacySchemaItemParamKeys]
        : legacyKeys;
    return readParamValue(params, key, legacyKeys: legacy);
  }

  void writeHierarchyLevelToParams(
    Map<String, dynamic> params,
    int level,
    String value,
  ) {
    final v = value.trim();
    if (v.isEmpty) return;
    final paramKey = resolveHierarchyLevelParamKey(level);
    if (paramKey != null && isLeafNameParamKey(paramKey)) return;
    for (final key in allParamKeysForHierarchyLevel(level)) {
      params[key] = v;
    }
  }

  /// Param-Keys einer Hierarchie-Ebene ohne Leaf-/Anzeigename-Filter.
  ///
  /// Wichtig: darf nicht [isLeafNameParamKey] / [resolveDisplayNameParamKey]
  /// aufrufen – sonst Endlosrekursion mit [isUpperHierarchyParamKey].
  Set<String> _rawParamKeysForHierarchyLevel(int level) {
    final keys = <String>{...configuredHierarchyParamKeys(level)};
    final headerLabel = hierarchyLevelHeaderLabel(level);
    if (headerLabel.isNotEmpty) {
      _addDistinctParamKey(keys, headerLabel);
    }
    if (level == 1 && !level1IsDiscipline) {
      final listKey = resolveListGroupingParamKeyForLevel(1);
      if (listKey != null && listKey.isNotEmpty) keys.add(listKey);
    }
    return keys;
  }

  /// Alle Param-Keys einer Hierarchie-Ebene (konfigurierte Labels + Legacy).
  List<String> allParamKeysForHierarchyLevel(int level) {
    final keys = _rawParamKeysForHierarchyLevel(level);
    keys.removeWhere(isLeafNameParamKey);
    return keys.toList();
  }

  /// Ob [key] ein Hierarchie- oder Schema-Ebenen-Key ist (niemals Anzeigename überschreiben).
  bool mustNotReceiveDisplayName(String key) {
    final k = key.trim();
    if (k.isEmpty) return false;
    if (CsvSettings.isEbeneHierarchyHeader(k)) return true;
    if (isUpperHierarchyParamKey(k)) return true;
    final schemaLevel = schemaItemLevelNumber;
    if (schemaLevel != null) {
      for (final hk in allParamKeysForHierarchyLevel(schemaLevel)) {
        if (paramKeysMatch(k, hk)) return true;
      }
    }
    final schemaKey = resolveSchemaItemParamKey()?.trim();
    if (schemaKey != null &&
        schemaKey.isNotEmpty &&
        paramKeysMatch(k, schemaKey)) {
      return true;
    }
    return false;
  }

  /// Reservierter Param-Key für den Dialog (case-insensitive + Prefix-Aliase).
  bool matchesReservedDialogParamKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return true;
    for (final reserved in reservedParamKeysForDialog()) {
      if (paramKeysMatch(k, reserved)) return true;
    }
    return false;
  }

  /// Spaltenindex für [label] in [headers] (exakter Header-Abgleich), sonst -1.
  int columnIndexForLabel(List<String> headers, String? label) {
    final t = label?.trim() ?? '';
    if (t.isEmpty) return -1;
    for (var i = 0; i < headers.length; i++) {
      if (paramKeysMatch(headers[i], t)) return i;
    }
    return -1;
  }

  bool get hasQrCodeExportColumn =>
      (qrCodeNummerSpalteLabel?.trim().isNotEmpty ?? false);

  /// Param-Keys, die nicht als Attribut-Spalten exportiert werden.
  Set<String> reservedParamKeysForExport() {
    return {
      ...reservedParamKeysForDialog(),
      'lfdNummer',
      'photoPaths',
      qrCodeNummerParamKey,
      '__parentLfdNummer',
      '__syntheticParent',
      '__etageName',
    };
  }

  /// Schreibt mehrere Hierarchie-Ebenen in Params (Level-Nummer → Wert).
  void writeHierarchyPathToParams(
    Map<String, dynamic> params, {
    required Map<int, String> levelValues,
  }) {
    for (final entry in levelValues.entries) {
      final v = entry.value.trim();
      if (v.isEmpty) continue;
      writeHierarchyLevelToParams(params, entry.key, v);
    }
  }

  /// Gruppierungs-Key für Listen-Header einer Ebene (null wenn Ebene 1 = Disziplin-Tab).
  String? resolveListGroupingParamKeyForLevel(int level) {
    if (level == 1 && level1IsDiscipline) return null;
    return resolveHierarchyLevelParamKey(level);
  }

  /// Spaltenindizes, die beim Import nicht als EAV-Attribute behandelt werden.
  Set<int> reservedImportColumnIndices() {
    final indices = <int>{};
    for (final level in enabledLevelsOrdered) {
      indices.add(level.nameColumn);
      if (level.useIdColumn && level.idColumn != null) {
        indices.add(level.idColumn!);
      }
    }
    for (final pair in attributeColumnPairs) {
      indices.add(pair.nameColumn);
      indices.add(pair.valueColumn);
    }
    for (final group in attributeTripletColumns) {
      indices.addAll(group.columnIndices);
    }
    return indices;
  }

  HierarchyLevelConfig? _hierarchyLevelConfig(int level) {
    switch (level) {
      case 1:
        return level1.enabled ? level1 : null;
      case 2:
        return level2.enabled ? level2 : null;
      case 3:
        return level3.enabled ? level3 : null;
      default:
        return null;
    }
  }

  /// Spaltenindex in [headers] für Hierarchie-Ebene [level] (exakter Header-Abgleich), sonst -1.
  int findHierarchyColumnInHeaders(List<String> headers, int level) {
    final label = hierarchyLevelHeaderLabel(level).trim();
    if (label.isNotEmpty) {
      for (var i = 0; i < headers.length; i++) {
        if (paramKeysMatch(headers[i], label)) return i;
      }
    }
    final config = _hierarchyLevelConfig(level);
    if (config != null &&
        config.nameColumn >= 0 &&
        config.nameColumn < headers.length) {
      return config.nameColumn;
    }
    return -1;
  }

  /// Präfix für automatisch vergebene Laufnummern (Import/Export ohne ID-Spalte).
  String syntheticIdPrefix() => 'ID';

  String syntheticLfdForImportRow({
    required int rowIndex,
    String? contextLabel,
  }) {
    final base = syntheticIdPrefix();
    final ctx = contextLabel?.trim() ?? '';
    if (ctx.isEmpty) return '${base}_${rowIndex + 1}';
    final safe = ctx.replaceAll(RegExp(r'[^\w\-äöüÄÖÜß]'), '_');
    return '${base}_${safe}_${rowIndex + 1}';
  }

  String exportPlaceholderLfd(int sequentialNumber) =>
      '${syntheticIdPrefix()}_${sequentialNumber.toString().padLeft(4, '0')}';

  /// Ob Ebene 1 bereits als Gewerk/Disziplin-Tab genutzt wird (keine Listen-Gruppierung nötig).
  bool get level1IsDiscipline => level1.enabled && useDisciplineGrouping;

  String resolveGewerkGroupingParamKey() {
    final override = groupingGewerkParamKey.trim();
    if (override.isNotEmpty) return override;
    if (level1.enabled) return _headerLabelAt(level1.nameColumn) ?? labelGewerk;
    return labelGewerk;
  }

  /// Gruppierungs-Key für Ebene 1 in der Liste (null wenn Ebene 1 = Disziplin-Tab).
  String? resolveRevisionsfeldListGroupingParamKey() =>
      resolveListGroupingParamKeyForLevel(1);

  /// Param-Key für Untergruppierung (mittlere Ebene), wenn mindestens 2 Ebenen aktiv.
  String? resolveAnlageGroupingParamKey() {
    final override = groupingAnlageParamKey.trim();
    if (override.isNotEmpty) return override;
    final levels = enabledLevelsOrdered;
    if (levels.length < 2) return null;
    if (level2.enabled && levels.length >= 2) {
      return resolveHierarchyLevelParamKey(2);
    }
    if (levels.length == 2 && level1.enabled && level3.enabled) {
      if (level1IsDiscipline) return null;
      return resolveHierarchyLevelParamKey(1);
    }
    return null;
  }

  String? resolveNameParamKey() {
    final leaf = leafLevel;
    if (leaf == null) return null;
    return _headerLabelAt(leaf.nameColumn);
  }

  /// Ob Header/Key eine generische Ebenen-Spalte ist (Ebene1, Ebene 2, …).
  static bool isEbeneHierarchyHeader(String key) {
    final t = key.trim().replaceAll(RegExp(r'\s+'), '');
    if (t.isEmpty) return false;
    return RegExp(r'^Ebene[1-3]$', caseSensitive: false).hasMatch(t);
  }

  /// Ob [key] ein Param-Key der oberen Hierarchie (Ebene 1–2) ist – nicht für Ebene-3-Anzeige.
  bool isUpperHierarchyParamKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return false;
    if (CsvSettings.isEbeneHierarchyHeader(k)) {
      final n = int.tryParse(k.replaceAll(RegExp(r'[^0-9]'), ''));
      if (n != null && n <= 2) return true;
    }
    for (var level = 1; level <= 2; level++) {
      for (final hk in _rawParamKeysForHierarchyLevel(level)) {
        if (paramKeysMatch(k, hk)) return true;
      }
    }
    return false;
  }

  /// Ob [key] zu einer Hierarchie-Ebene (1–3 inkl. Schema-Item) gehört.
  bool isHierarchyParamKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return false;
    if (CsvSettings.isEbeneHierarchyHeader(k)) return true;
    if (isUpperHierarchyParamKey(k)) return true;
    for (var level = 1; level <= 3; level++) {
      final headerLabel = hierarchyLevelHeaderLabel(level).trim();
      if (headerLabel.isNotEmpty && paramKeysMatch(k, headerLabel)) {
        return true;
      }
      for (final hk in allParamKeysForHierarchyLevel(level)) {
        if (paramKeysMatch(k, hk)) return true;
      }
    }
    final schemaKey = resolveSchemaItemParamKey()?.trim();
    if (schemaKey != null &&
        schemaKey.isNotEmpty &&
        paramKeysMatch(k, schemaKey)) {
      return true;
    }
    return false;
  }

  /// Param-Key, der in der Anlagenübersicht als Beschriftung der Ebene 3 genutzt wird.
  /// Priorität: expliziter Param-Key → Anzeige-Spalte → Blatt-Spalte → „Bezeichnung“.
  /// Niemals Hierarchie-/Ebene-Keys (sonst landet der Anzeigename in Ebene2).
  String? resolveDisplayNameParamKey() {
    final explicit = displayNameParamKey.trim();
    if (explicit.isNotEmpty) {
      return mustNotReceiveDisplayName(explicit) ? null : explicit;
    }
    final fromDisplayColumn = _headerLabelAt(displayNameSpalte);
    if (fromDisplayColumn != null &&
        fromDisplayColumn.isNotEmpty &&
        !mustNotReceiveDisplayName(fromDisplayColumn) &&
        !CsvSettings.isEbeneHierarchyHeader(fromDisplayColumn)) {
      return fromDisplayColumn;
    }
    final leafKey = resolveNameParamKey();
    if (leafKey != null &&
        leafKey.isNotEmpty &&
        !mustNotReceiveDisplayName(leafKey) &&
        !CsvSettings.isEbeneHierarchyHeader(leafKey) &&
        !isUpperHierarchyParamKey(leafKey)) {
      return leafKey;
    }
    return 'Bezeichnung';
  }

  static bool paramKeysMatch(String a, String b) {
    final x = a.trim().toLowerCase();
    final y = b.trim().toLowerCase();
    if (x.isEmpty || y.isEmpty) return false;
    if (x == y) return true;
    return x.startsWith('${y}_') || y.startsWith('${x}_');
  }

  /// Spalten-Header/Param-Keys aus Anlagen-CSV (ATT1, ATT1_wert, ATT_WERT12) – keine Dialog-Felder.
  static bool isAnlagenCsvColumnParamKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return false;
    final lower = k.toLowerCase();
    if (RegExp(r'^att\d+$').hasMatch(lower)) return true;
    if (RegExp(r'^att\d+_wert$').hasMatch(lower)) return true;
    if (RegExp(r'^att_wert\d+$').hasMatch(lower)) return true;
    if (RegExp(r'^att\d+_art$').hasMatch(lower)) return true;
    if (RegExp(r'^att_art\d+$').hasMatch(lower)) return true;
    return false;
  }

  /// Normalisiert CSV-Header für ATT-Erkennung (Leerzeichen → Unterstrich).
  static String normalizeAttHeaderToken(String header) {
    return header.trim().replaceAll(RegExp(r'\s+'), '_').toUpperCase();
  }

  /// Entfernt Zeilenumbrüche aus Feldbezeichnungen (CSV → Dialog-Anzeige).
  static String normalizeFieldLabelForDisplay(String? raw) {
    if (raw == null) return '';
    return raw
        .replaceAll(RegExp(r'[\r\n\u2028\u2029]+'), ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  /// Anlagen-Import: Header mit ATTn + ATTn_wert (Zweier-Format).
  static bool headerLooksLikeAnlagenWertFormat(List<String> headers) {
    for (final h in headers) {
      final u = normalizeAttHeaderToken(h);
      if (RegExp(r'^ATT\d+_WERT$').hasMatch(u)) return true;
      if (RegExp(r'^ATT_WERT\d+$').hasMatch(u)) return true;
    }
    return false;
  }

  /// Gewerkevorlagen: Header mit TYPE je Attribut (Dreier- oder Legacy-Vierer-Format).
  static bool headerLooksLikeGewerkeQuadrupletFormat(List<String> headers) {
    for (final h in headers) {
      final u = normalizeAttHeaderToken(h);
      if (u.contains('_TYPE') ||
          u.contains('_OPTIONS') ||
          u.endsWith('_ART') ||
          u.endsWith('_WERT')) {
        return true;
      }
    }
    return false;
  }

  /// True, wenn der Header eine reine Typ-Definitions-Spalte ist (nicht exportieren).
  static bool isGewerkeTypeDefinitionHeader(String header) {
    final u = normalizeAttHeaderToken(header);
    return u.contains('_TYPE') || u.contains('_OPTIONS');
  }

  /// Header für Anlagen-Export: ohne TYPE/OPTIONS-Spalten, ART → WERT.
  static List<String> headersForAnlagenExport(List<String> importHeaders) {
    final result = <String>[];
    for (final raw in importHeaders) {
      if (isGewerkeTypeDefinitionHeader(raw)) continue;
      var h = raw.trim();
      final u = normalizeAttHeaderToken(h);
      if (u.endsWith('_ART')) {
        h = '${h.substring(0, h.length - 4)}_WERT';
      }
      result.add(h);
    }
    return result;
  }

  /// Parst TYPE-Zelle aus Gewerkevorlagen: Freitext, number oder Opt1|Opt2 → dropdown.
  static Map<String, dynamic> schemaFieldFromGewerkeTypeCell(
    String name,
    String typeStr, {
    String? legacyOptionsStr,
    String? artStr,
  }) {
    final entry = <String, dynamic>{
      'key': name,
      'label': normalizeFieldLabelForDisplay(name),
    };

    final trimmedType = typeStr.trim();
    final lowerType = trimmedType.toLowerCase();

    if (trimmedType.contains('|')) {
      entry['type'] = 'dropdown';
      entry['options'] = trimmedType
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (lowerType == 'freitext' || lowerType == 'text') {
      entry['type'] = 'text';
    } else if (lowerType == 'number' || lowerType == 'int') {
      entry['type'] = 'number';
    } else if (lowerType == 'dropdown' ||
        lowerType == 'select' ||
        lowerType == 'option') {
      entry['type'] = 'dropdown';
      final legacy = parseGewerkeOptionsList(legacyOptionsStr);
      if (legacy.isNotEmpty) entry['options'] = legacy;
    } else if (trimmedType.isNotEmpty) {
      entry['type'] = lowerType;
    } else {
      entry['type'] = 'text';
    }

    final art = normalizeFieldLabelForDisplay(artStr ?? '');
    if (art.isNotEmpty) entry['art'] = art;
    return entry;
  }

  static List<String> parseGewerkeOptionsList(String? optionsStr) {
    if (optionsStr == null || optionsStr.trim().isEmpty) return [];
    final s = optionsStr.trim();
    final split = s.contains('|')
        ? s.split('|')
        : (s.contains(';') ? s.split(';') : s.split(','));
    return split.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// Dreiergruppen aus Gewerke-Header (ATTn, ATTn_TYPE, ATTn_WERT/ART).
  static List<AttributeTripletColumn> detectQuadrupletsFromHeader(
    List<String> headers,
  ) {
    final groups = <AttributeTripletColumn>[];
    for (var i = 0; i < headers.length; i++) {
      final h = normalizeAttHeaderToken(headers[i]);
      final m = RegExp(r'^ATT(\d+)$').firstMatch(h);
      if (m == null) continue;
      final n = int.parse(m.group(1)!);
      int indexWhere(String suffix) {
        return headers.indexWhere(
          (x) => normalizeAttHeaderToken(x) == 'ATT${n}$suffix',
        );
      }

      final typeIdx = indexWhere('_TYPE');
      if (typeIdx < 0) continue;

      final optIdx = indexWhere('_OPTIONS');
      var valueIdx = indexWhere('_WERT');
      if (valueIdx < 0) valueIdx = indexWhere('_ART');

      groups.add(AttributeTripletColumn(
        nameColumn: i,
        typeColumn: typeIdx,
        optionsColumn: optIdx >= 0 ? optIdx : -1,
        artColumn: valueIdx >= 0 ? valueIdx : -1,
      ));
    }
    return groups;
  }

  /// Gespeicherte Dreiergruppen passen zum Header (kein ATT/ATT_wert-Zweier-Mix).
  static bool quadrupletsMatchHeader(
    List<AttributeTripletColumn> quadruplets,
    List<String> headers,
  ) {
    if (quadruplets.isEmpty || headers.isEmpty) return false;
    for (final g in quadruplets) {
      if (g.nameColumn < 0 || g.nameColumn >= headers.length) return false;
      if (g.typeColumn < 0 || g.typeColumn >= headers.length) return false;
      final typeToken = normalizeAttHeaderToken(headers[g.typeColumn]);
      if (typeToken.contains('WERT') && !typeToken.contains('_TYPE')) {
        return false;
      }
    }
    return true;
  }

  /// Wählt Zweier- oder Vierer-Mapping passend zum Import-Header.
  static ImportAttributeMapping resolveImportAttributeMapping({
    required List<String> headerRow,
    required CsvSettings settings,
  }) {
    if (headerRow.isEmpty) {
      return ImportAttributeMapping(
        pairs: settings.attributeColumnPairs,
        quadruplets: settings.attributeTripletColumns,
      );
    }

    if (headerLooksLikeAnlagenWertFormat(headerRow)) {
      final detected = detectAnlagenAttributePairsFromHeader(headerRow);
      return ImportAttributeMapping(
        pairs: detected.isNotEmpty ? detected : settings.attributeColumnPairs,
        quadruplets: const [],
      );
    }

    if (headerLooksLikeGewerkeQuadrupletFormat(headerRow)) {
      final detected = detectQuadrupletsFromHeader(headerRow);
      if (quadrupletsMatchHeader(settings.attributeTripletColumns, headerRow)) {
        return ImportAttributeMapping(
          pairs: const [],
          quadruplets: settings.attributeTripletColumns,
        );
      }
      if (detected.isNotEmpty) {
        return ImportAttributeMapping(pairs: const [], quadruplets: detected);
      }
    } else if (quadrupletsMatchHeader(settings.attributeTripletColumns, headerRow)) {
      return ImportAttributeMapping(
        pairs: const [],
        quadruplets: settings.attributeTripletColumns,
      );
    }

    return ImportAttributeMapping(
      pairs: settings.attributeColumnPairs,
      quadruplets: settings.attributeTripletColumns,
    );
  }

  /// Erkennt ATT/ATT_wert-Spaltenpaare aus der Import-Headerzeile (0-basierte Indizes).
  /// Erkennt auch ATT(n)_ART / ATT_ART(n) als Wertspalte (Gewerke-/Anlagen-Layout).
  static List<AttributeColumnPair> detectAnlagenAttributePairsFromHeader(
    List<String> headers,
  ) {
    final nameColByN = <int, int>{};
    final valueColByN = <int, int>{};

    for (var i = 0; i < headers.length; i++) {
      final raw = headers[i].trim();
      if (raw.isEmpty) continue;
      final upper = normalizeAttHeaderToken(raw);

      final attOnly = RegExp(r'^ATT(\d+)$').firstMatch(upper);
      if (attOnly != null) {
        nameColByN[int.parse(attOnly.group(1)!)] = i;
        continue;
      }
      final attWert = RegExp(r'^ATT(\d+)_WERT$').firstMatch(upper);
      if (attWert != null) {
        valueColByN[int.parse(attWert.group(1)!)] = i;
        continue;
      }
      final attWertAlt = RegExp(r'^ATT_WERT(\d+)$').firstMatch(upper);
      if (attWertAlt != null) {
        valueColByN[int.parse(attWertAlt.group(1)!)] = i;
        continue;
      }
      // ART nur als Wertspalte, wenn noch kein WERT für diesen Slot existiert.
      final attArt = RegExp(r'^ATT(\d+)_ART$').firstMatch(upper);
      if (attArt != null) {
        final n = int.parse(attArt.group(1)!);
        valueColByN.putIfAbsent(n, () => i);
        continue;
      }
      final attArtAlt = RegExp(r'^ATT_ART(\d+)$').firstMatch(upper);
      if (attArtAlt != null) {
        final n = int.parse(attArtAlt.group(1)!);
        valueColByN.putIfAbsent(n, () => i);
      }
    }

    final nums = {...nameColByN.keys, ...valueColByN.keys}.toList()..sort();
    final pairs = <AttributeColumnPair>[];
    for (final n in nums) {
      final valueCol = valueColByN[n];
      if (valueCol == null) continue;
      final nameCol = nameColByN[n] ?? valueCol;
      pairs.add(AttributeColumnPair(
        nameColumn: nameCol,
        valueColumn: valueCol,
        attNumber: n,
      ));
    }
    return pairs;
  }

  /// ATT-Nummer aus Header-Label (ATT7 / ATT7_WERT / ATT7_TYPE → 7).
  static int? attNumberFromHeaderLabel(String header) {
    final upper = normalizeAttHeaderToken(header);
    final m =
        RegExp(r'^ATT(\d+)(?:_(?:WERT|ART|TYPE|OPTIONS))?$').firstMatch(upper);
    if (m != null) return int.tryParse(m.group(1)!);
    final alt =
        RegExp(r'^ATT_(?:WERT|ART|TYPE|OPTIONS)(\d+)$').firstMatch(upper);
    if (alt != null) return int.tryParse(alt.group(1)!);
    return null;
  }

  /// ATT-Nummer aus Schema-Feld (1 = ATT1). Null bei Legacy-Daten ohne Slot.
  static int? attSlotFromSchemaField(Map<String, dynamic> field) {
    final raw = field['attSlot'] ?? field['attNumber'];
    if (raw is int && raw > 0) return raw;
    if (raw is String) {
      final parsed = int.tryParse(raw.trim());
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  /// Schema-Feld für festen ATT-Slot.
  /// Legacy: Listenindex nur wenn kein Feld attSlot gespeichert hat.
  static Map<String, dynamic>? schemaFieldAtAttSlot(
    int attSlot,
    List<Map<String, dynamic>> fields,
  ) {
    if (attSlot <= 0) return null;
    for (final f in fields) {
      if (attSlotFromSchemaField(f) == attSlot) return f;
    }
    final usesAttSlots = fields.any((f) => attSlotFromSchemaField(f) != null);
    if (usesAttSlots) return null;
    final idx = attSlot - 1;
    if (idx >= 0 && idx < fields.length) return fields[idx];
    return null;
  }

  /// ATT-Nummer für Spaltenpaar (Header-Nummer oder Listenposition).
  static int attSlotForPair(AttributeColumnPair pair, int pairIndex) =>
      pair.attNumber ?? (pairIndex + 1);

  /// Param-Keys, die nicht als Dialog-Felder angezeigt werden sollen.
  static bool isReservedDialogParamKey(String key, CsvSettings? settings) {
    final k = key.trim();
    if (k.isEmpty || k.startsWith('_')) return true;
    if (k == 'lfdNummer' ||
        k == 'photoPaths' ||
        k == '__parentLfdNummer' ||
        k == '__syntheticParent' ||
        k == csvRowCellsParamKey ||
        k == csvRowIndexParamKey) {
      return true;
    }
    if (isAnlagenCsvColumnParamKey(k)) return true;
    if (settings != null) {
      if (settings.matchesReservedDialogParamKey(k)) return true;
    }
    return false;
  }

  /// Dialog-Schema aus vorhandenen Parametern (Fallback ohne Gewerkevorlage).
  static List<Map<String, dynamic>> schemaFieldsFromParams(
    Map<String, dynamic> params, {
    CsvSettings? settings,
  }) {
    final fields = <Map<String, dynamic>>[];
    for (final entry in params.entries) {
      final key = entry.key.toString();
      if (isReservedDialogParamKey(key, settings)) continue;
      final value = entry.value;
      if (value == null || value.toString().trim().isEmpty) continue;
      fields.add({
        'key': key,
        'label': normalizeFieldLabelForDisplay(key),
        'type': 'text',
      });
    }
    return fields;
  }

  /// Nummer aus Param-Key ATT7, ATT7_wert, ATT_WERT7 (sonst null).
  static int? anlagenColumnIndexFromParamKey(String key) {
    final raw = key.trim();
    if (raw.isEmpty) return null;
    final att = RegExp(r'^ATT(\d+)$', caseSensitive: false).firstMatch(raw);
    if (att != null) return int.parse(att.group(1)!);
    final upper = raw.toUpperCase();
    final w1 = RegExp(r'^ATT(\d+)_WERT$').firstMatch(upper);
    if (w1 != null) return int.parse(w1.group(1)!);
    final w2 = RegExp(r'^ATT_WERT(\d+)$').firstMatch(upper);
    if (w2 != null) return int.parse(w2.group(1)!);
    final a1 = RegExp(r'^ATT(\d+)_ART$').firstMatch(upper);
    if (a1 != null) return int.parse(a1.group(1)!);
    final a2 = RegExp(r'^ATT_ART(\d+)$').firstMatch(upper);
    if (a2 != null) return int.parse(a2.group(1)!);
    return null;
  }

  /// Entfernt CSV-Spalten-Keys (ATT/ATT_wert) aus Schema-Listen für den Dialog.
  static List<Map<String, dynamic>> filterSchemaFieldsForDialog(
    List<Map<String, dynamic>> fields,
  ) {
    return fields
        .where((f) {
          final key = (f['key'] ?? '').toString();
          final label = (f['label'] ?? '').toString();
          return !isAnlagenCsvColumnParamKey(key) &&
              !isAnlagenCsvColumnParamKey(label);
        })
        .map((f) => Map<String, dynamic>.from(f))
        .toList();
  }

  /// Verschiebt Werte von ATT/ATT_wert-Param-Keys auf Schema-Felder und löscht Spalten-Keys.
  static void migrateParamsFromAnlagenColumnKeys({
    required Map<String, dynamic> params,
    List<Map<String, dynamic>> schemaFields = const [],
  }) {
    final nonGlobal = schemaFields
        .where((f) => f['isGlobal'] != true)
        .toList();

    final wertBySlot = <int, String>{};
    final nameBySlot = <int, String>{};
    final keysToRemove = <String>[];

    for (final entry in params.entries) {
      final k = entry.key.toString();
      if (!isAnlagenCsvColumnParamKey(k)) continue;
      keysToRemove.add(k);
      final slot = anlagenColumnIndexFromParamKey(k);
      if (slot == null) continue;
      final v = entry.value?.toString().trim() ?? '';
      if (v.isEmpty) continue;
      final upper = k.toUpperCase();
      if (upper.contains('_WERT') ||
          upper.contains('_ART') ||
          upper.startsWith('ATT_WERT') ||
          upper.startsWith('ATT_ART')) {
        wertBySlot[slot] = v;
      } else {
        nameBySlot[slot] = v;
      }
    }

    for (final slot in {...wertBySlot.keys, ...nameBySlot.keys}) {
      final field = schemaFieldAtAttSlot(slot, nonGlobal);
      var schemaKey = '';
      if (field != null) {
        schemaKey = (field['key'] ?? '').toString();
      } else {
        final idx = slot - 1;
        if (idx >= 0 && idx < nonGlobal.length) {
          schemaKey = (nonGlobal[idx]['key'] ?? '').toString();
        }
      }
      if (schemaKey.isEmpty || isAnlagenCsvColumnParamKey(schemaKey)) continue;
      final existing = params[schemaKey]?.toString().trim() ?? '';
      if (existing.isNotEmpty) {
        writeAttSlotForParam(params, schemaKey, slot);
        continue;
      }
      // Nur ART/WERT als Wert – leere Wertspalte bleibt leer (kein Fallback auf Feldname).
      final preferred = wertBySlot[slot];
      if (preferred != null && preferred.isNotEmpty) {
        params[schemaKey] = preferred;
        writeAttSlotForParam(params, schemaKey, slot);
      } else if (nameBySlot.containsKey(slot)) {
        // Slot bekannt, aber ohne Wert: nur ATT-Zuordnung merken.
        writeAttSlotForParam(params, schemaKey, slot);
      }
    }

    for (final k in keysToRemove) {
      params.remove(k);
    }
  }

  /// Schreibt ATT-Slot-Metadaten für Schema-Felder (Export-Zuordnung Schema-Key → Spalte).
  static void writeAttSlotsFromSchemaFields(
    Map<String, dynamic> params,
    List<Map<String, dynamic>> schemaFields,
  ) {
    for (final field in schemaFields) {
      if (field['isGlobal'] == true) continue;
      final key = (field['key'] ?? '').toString().trim();
      if (key.isEmpty || isAnlagenCsvColumnParamKey(key)) continue;
      final slot = attSlotFromSchemaField(field);
      if (slot == null || slot <= 0) continue;
      writeAttSlotForParam(params, key, slot);
    }
  }

  /// Ergänzt fehlende ATT-Slots aus Import-Header-Paaren/Tripletts.
  static void writeAttSlotsFromImportHeader({
    required Map<String, dynamic> params,
    required List<String> importHeaders,
    required List<Map<String, dynamic>> schemaFields,
  }) {
    if (importHeaders.isEmpty || schemaFields.isEmpty) return;
    final nonGlobal =
        schemaFields.where((f) => f['isGlobal'] != true).toList();

    final pairs = detectAnlagenAttributePairsFromHeader(importHeaders);
    for (var i = 0; i < pairs.length; i++) {
      final slot = attSlotForPair(pairs[i], i);
      final field = schemaFieldAtAttSlot(slot, nonGlobal);
      final key = (field?['key'] ?? '').toString().trim();
      if (key.isEmpty) continue;
      if (attSlotForParam(params, key) == null) {
        writeAttSlotForParam(params, key, slot);
      }
    }

    if (pairs.isNotEmpty) return;

    final triplets = detectQuadrupletsFromHeader(importHeaders);
    for (var i = 0; i < triplets.length; i++) {
      final nameCol = triplets[i].nameColumn;
      final slot = (nameCol >= 0 && nameCol < importHeaders.length)
          ? (attNumberFromHeaderLabel(importHeaders[nameCol]) ?? (i + 1))
          : (i + 1);
      final field = schemaFieldAtAttSlot(slot, nonGlobal);
      final key = (field?['key'] ?? '').toString().trim();
      if (key.isEmpty) continue;
      if (attSlotForParam(params, key) == null) {
        writeAttSlotForParam(params, key, slot);
      }
    }
  }

  /// Liest einen Param-Wert inkl. case-insensitive Key und Schema-Key mit UUID-Suffix.
  String? paramValueForKey(Map<String, dynamic> params, String desiredKey) {
    final trimmed = desiredKey.trim();
    if (trimmed.isEmpty) return null;

    final direct = readParamValue(params, trimmed);
    if (direct != null && direct.isNotEmpty) return direct;

    for (final entry in params.entries) {
      final key = entry.key.toString().trim();
      if (!paramKeysMatch(key, trimmed)) continue;
      final value = entry.value?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  /// Anzeigename für Ebene 3 aus Params (Neuaufnahme / Gewerkevorlagen).
  String? displayNameValueFromParams(
    Map<String, dynamic> params, {
    List<Map<String, dynamic>> schemaFields = const [],
  }) {
    final explicit = displayNameParamKey.trim();
    if (explicit.isNotEmpty) {
      final fromExplicit = paramValueForKey(params, explicit);
      if (fromExplicit != null && fromExplicit.isNotEmpty) {
        return fromExplicit;
      }
      for (final field in schemaFields) {
        final fieldKey = (field['key'] ?? '').toString();
        final fieldLabel = (field['label'] ?? fieldKey).toString();
        if (fieldKey.isEmpty) continue;
        if (!paramKeysMatch(fieldKey, explicit) &&
            !paramKeysMatch(fieldLabel, explicit)) {
          continue;
        }
        final fromField = paramValueForKey(params, fieldKey);
        if (fromField != null && fromField.isNotEmpty) return fromField;
      }
    }

    final configured = resolveDisplayNameParamKey();
    if (configured != null &&
        configured.isNotEmpty &&
        !isUpperHierarchyParamKey(configured)) {
      final fromConfigured = paramValueForKey(params, configured);
      if (fromConfigured != null && fromConfigured.isNotEmpty) {
        return fromConfigured;
      }
    }

    final schemaValue = schemaItemValueFromParams(params)?.trim();
    bool isSchemaDuplicate(String value) =>
        schemaValue != null &&
        schemaValue.isNotEmpty &&
        schemaValue.toLowerCase() == value.trim().toLowerCase();

    for (final candidate in const [
      'Name',
      'Anlagenbezeichnung',
      'Bezeichnung',
      'name',
    ]) {
      final v = paramValueForKey(params, candidate);
      if (v != null && v.isNotEmpty && !isSchemaDuplicate(v)) return v;
    }

    for (final field in schemaFields) {
      final fieldKey = (field['key'] ?? '').toString();
      if (fieldKey.isEmpty) continue;
      if (isUpperHierarchyParamKey(fieldKey)) continue;
      if (isLeafNameParamKey(fieldKey)) {
        final fromLeafField = paramValueForKey(params, fieldKey);
        if (fromLeafField != null &&
            fromLeafField.isNotEmpty &&
            !isSchemaDuplicate(fromLeafField)) {
          return fromLeafField;
        }
        continue;
      }
    }

    final leafKey = resolveNameParamKey();
    if (leafKey != null &&
        leafKey.isNotEmpty &&
        !isUpperHierarchyParamKey(leafKey)) {
      final fromLeaf = paramValueForKey(params, leafKey);
      if (fromLeaf != null && fromLeaf.isNotEmpty && !isSchemaDuplicate(fromLeaf)) {
        return fromLeaf;
      }
    }
    return null;
  }

  void writeDisplayNameToParams(Map<String, dynamic> params, String value) {
    final v = value.trim();
    if (v.isEmpty) return;

    final key = resolveDisplayNameParamKey()?.trim();
    if (key == null || key.isEmpty) return;
    if (mustNotReceiveDisplayName(key)) return;

    params[key] = v;
    for (final entry in params.entries.toList()) {
      final paramKey = entry.key.toString();
      if (!paramKeysMatch(paramKey, key)) continue;
      if (mustNotReceiveDisplayName(paramKey)) continue;
      params[paramKey] = v;
    }
  }

  /// Param-Key der Ebene, deren Wert das Attribut-Schema bestimmt.
  String? resolveSchemaItemParamKey() {
    final override = groupingAnlageParamKey.trim();
    if (override.isNotEmpty) return override;
    final schemaLevel = schemaItemLevelNumber;
    if (schemaLevel != null) {
      return resolveHierarchyLevelParamKey(schemaLevel);
    }
    return resolveHierarchyLevelParamKey(
      enabledLevelsOrdered.length >= 2 ? 2 : 1,
    );
  }

  /// Param-Key für Untergruppierung in der Liste (typisch Ebene 2).
  String? resolveRevisionsobjektGroupingParamKey() {
    if (level1IsDiscipline && level2.enabled) {
      final override = groupingAnlageParamKey.trim();
      if (override.isNotEmpty) return override;
      return resolveHierarchyLevelParamKey(2);
    }
    return resolveAnlageGroupingParamKey();
  }

  /// Anzeige-Label der Schema-Unterebene.
  String resolveSchemaItemLevelLabel() {
    final schemaLevel = schemaItemLevelNumber;
    if (schemaLevel != null) {
      return hierarchyLevelHeaderLabel(schemaLevel);
    }
    return labelAnlage;
  }

  /// Anzeige-Label der untersten aktiven Ebene (= ein Datensatz in der App).
  String resolveLeafLevelLabel() {
    final leaf = leafLevel;
    if (leaf != null) {
      final fromHeader = _headerLabelAt(leaf.nameColumn);
      if (fromHeader != null && fromHeader.isNotEmpty) return fromHeader;
    }
    final n = enabledLevelsOrdered.length;
    if (n <= 1) return labelGewerk;
    if (n == 2) return labelAnlage;
    return labelBauteil;
  }

  /// Label für neue Blatt-Datensätze unter der Schema-Ebene (Long-Press → Plus).
  String resolveDatensatzUnderRevisionsobjektLabel() {
    if (level3.enabled && enabledLevelsOrdered.length >= 3) {
      return hierarchyLevelHeaderLabel(3);
    }
    final nameKey = resolveNameParamKey();
    if (nameKey != null && nameKey.trim().isNotEmpty) {
      return nameKey.trim();
    }
    return resolveLeafLevelLabel();
  }

  /// Ob aus der Listen-Gruppe mit diesem Param-Key ein neuer Blatt-Datensatz angelegt werden darf.
  bool isCreateLeafFromGroupKey(String groupingParamKey) {
    final gk = groupingParamKey.trim();
    if (gk.isEmpty) return false;
    final schemaKey = resolveSchemaItemParamKey()?.trim() ?? '';
    if (schemaKey.isNotEmpty &&
        gk.toLowerCase() == schemaKey.toLowerCase()) {
      return true;
    }
    final levels = enabledLevelsOrdered;
    if (levels.length == 2 && level2.enabled) {
      final l2 = _headerLabelAt(level2.nameColumn)?.trim() ?? labelAnlage;
      if (gk.toLowerCase() == l2.toLowerCase()) return true;
    }
    return false;
  }

  /// Untergeordnete Zeilen werden über parentId abgebildet (≥ 2 Hierarchie-Ebenen).
  bool get allowsParentChildRows => enabledLevelsOrdered.length >= 2;

  /// Nummer (1–3) der Ebene, unter der pro Eintrag ein Attribut-Schema liegt.
  int? get schemaItemLevelNumber {
    if (level2.enabled && enabledLevelsOrdered.length >= 2) return 2;
    if (level3.enabled) return 3;
    return null;
  }

  String get schemaDisciplineLevelLabel => labelGewerk;

  /// Legacy-Param-Keys – nur zum Lesen älterer importierter Daten.
  static const List<String> legacySchemaItemParamKeys = [
    'Revisionsobjekt',
    'Anlagentyp',
    'Anlage',
  ];

  static const List<String> legacyAnlageBauteilParamKeys = [
    'Anlage/Bauteil',
    'Anlage/Bautel',
  ];

  /// Param-Key der optionalen A/B-Spalte (Legacy-Hierarchie).
  String? resolveAnlageBauteilParamKey() {
    if (anlageBauteilSpalte == null) return null;
    return _headerLabelAt(anlageBauteilSpalte) ??
        legacyAnlageBauteilParamKeys.first;
  }

  /// Liest einen Param-Wert: primärer Key, dann Legacy-Aliase.
  String? readParamValue(
    Map<String, dynamic> params,
    String primaryKey, {
    List<String> legacyKeys = const [],
  }) {
    final primary = params[primaryKey]?.toString().trim();
    if (primary != null && primary.isNotEmpty) return primary;
    for (final key in legacyKeys) {
      final value = params[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String? schemaItemValueFromParams(Map<String, dynamic> params) {
    final key = resolveSchemaItemParamKey();
    if (key != null && key.trim().isNotEmpty) {
      final value = readParamValue(
        params,
        key,
        legacyKeys: legacySchemaItemParamKeys,
      );
      if (value != null) return value;
    }
    for (final legacyKey in legacySchemaItemParamKeys) {
      final value = params[legacyKey]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String? anlageBauteilValueFromParams(Map<String, dynamic> params) {
    final key = resolveAnlageBauteilParamKey();
    if (key == null || key.isEmpty) return null;
    return readParamValue(
      params,
      key,
      legacyKeys: legacyAnlageBauteilParamKeys,
    );
  }

  void writeAnlageBauteilToParams(Map<String, dynamic> params, String value) {
    final key = resolveAnlageBauteilParamKey();
    if (key == null || key.isEmpty || value.trim().isEmpty) return;
    params[key] = value;
  }

  void writeSchemaItemToParams(Map<String, dynamic> params, String value) {
    final key = resolveSchemaItemParamKey();
    if (key == null || key.trim().isEmpty || value.trim().isEmpty) return;
    final trimmedKey = key.trim();
    if (isLeafNameParamKey(trimmedKey)) return;
    params[trimmedKey] = value.trim();
  }

  /// Liest Hierarchie-Ebene 1 aus gespeicherten Parametern.
  String? revisionsfeldValueFromParams(Map<String, dynamic> params) =>
      hierarchyLevelValueFromParams(params, 1);

  /// Liest Hierarchie-Ebene 2 (Schema-Ebene) aus gespeicherten Parametern.
  String? revisionsobjektValueFromParams(Map<String, dynamic> params) {
    final schemaLevel = schemaItemLevelNumber ?? 2;
    return hierarchyLevelValueFromParams(params, schemaLevel);
  }

  /// Param-Key der Blatt-Ebene (Anlagenbezeichnung aus CSV) – darf nie mit RO überschrieben werden.
  String? get leafNameParamKey => resolveNameParamKey();

  bool isLeafNameParamKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return false;

    // Obere Hierarchie-Keys sind nie Blatt-/Anzeigename (raw, ohne Rekursion).
    if (CsvSettings.isEbeneHierarchyHeader(k)) return false;
    for (var level = 1; level <= 2; level++) {
      for (final hk in _rawParamKeysForHierarchyLevel(level)) {
        if (paramKeysMatch(k, hk)) return false;
      }
    }

    // Kein resolveDisplayNameParamKey hier: das prüft mustNotReceiveDisplayName /
    // isUpperHierarchyParamKey und würde über allParamKeysForHierarchyLevel
    // wieder isLeafNameParamKey aufrufen (StackOverflow).
    final explicit = displayNameParamKey.trim();
    if (explicit.isNotEmpty && paramKeysMatch(k, explicit)) {
      return true;
    }

    final fromDisplayColumn = _headerLabelAt(displayNameSpalte)?.trim();
    if (fromDisplayColumn != null &&
        fromDisplayColumn.isNotEmpty &&
        !CsvSettings.isEbeneHierarchyHeader(fromDisplayColumn) &&
        paramKeysMatch(k, fromDisplayColumn)) {
      return true;
    }

    final leaf = leafNameParamKey?.trim();
    if (leaf != null &&
        leaf.isNotEmpty &&
        !CsvSettings.isEbeneHierarchyHeader(leaf) &&
        paramKeysMatch(k, leaf)) {
      return true;
    }

    final hasConfiguredName = explicit.isNotEmpty ||
        (fromDisplayColumn != null && fromDisplayColumn.isNotEmpty) ||
        (leaf != null && leaf.isNotEmpty);
    if (!hasConfiguredName && paramKeysMatch(k, 'Bezeichnung')) {
      return true;
    }
    return false;
  }

  /// Alle Param-Keys für Schema-Ebene, ohne Blatt-Namen-Spalte.
  List<String> allRevisionsobjektParamKeys() {
    final schemaLevel = schemaItemLevelNumber;
    if (schemaLevel == null) return const [];
    return allParamKeysForHierarchyLevel(schemaLevel);
  }

  /// Alle Param-Keys für Listen-Ebene 1 (nur wenn nicht Disziplin-Tab).
  List<String> allRevisionsfeldParamKeys() {
    final keys = <String>{};
    final listKey = resolveListGroupingParamKeyForLevel(1);
    if (listKey != null && listKey.trim().isNotEmpty) {
      keys.add(listKey.trim());
    }
    keys.addAll(allParamKeysForHierarchyLevel(1));
    return keys.toList();
  }

  /// Schreibt Hierarchie-Pfad in Params eines Blatt-Datensatzes.
  void writeHierarchyLocationToParams(
    Map<String, dynamic> params, {
    String? revisionsfeld,
    required String revisionsobjekt,
  }) {
    final levelValues = <int, String>{};
    final schemaLevel = schemaItemLevelNumber ?? 2;
    if (revisionsobjekt.trim().isNotEmpty) {
      levelValues[schemaLevel] = revisionsobjekt;
    }
    final rf = revisionsfeld?.trim() ?? '';
    if (rf.isNotEmpty && !level1IsDiscipline) {
      levelValues[1] = rf;
    }
    writeHierarchyPathToParams(params, levelValues: levelValues);
  }

  /// Neue Param-Werte für Hierarchie-Pfad (z. B. beim Verschieben in andere Liste).
  Map<String, dynamic> buildHierarchyLocationParams({
    String? revisionsfeld,
    required String revisionsobjekt,
  }) {
    final params = <String, dynamic>{};
    writeHierarchyLocationToParams(
      params,
      revisionsfeld: revisionsfeld,
      revisionsobjekt: revisionsobjekt,
    );
    return params;
  }

  /// Param-Key Revisionsobjekt (Listen-Ebene 2 unter Revisionsfeld).
  String? resolveRevisionsobjektParamKey() =>
      resolveRevisionsobjektGroupingParamKey() ?? resolveSchemaItemParamKey();

  /// Sammel-Disziplin, wenn Gewerk-Gruppierung deaktiviert ist.
  String resolveDefaultDisciplineLabel() =>
      useDisciplineGrouping ? labelGewerk : 'Allgemein';

  /// Anzeige-Label für mehrere Blatt-Datensätze (einfache Pluralbildung).
  String pluralLeafLevelLabel(int count) {
    final label = resolveLeafLevelLabel();
    if (count == 1) return label;
    if (label.endsWith('e')) return '${label}n';
    return '${label}en';
  }

  /// Plural für Ebene-1-Label (z. B. Gewerk → Gewerke).
  String pluralDisciplineLabel(int count) {
    final label = labelGewerk;
    if (count == 1) return label;
    if (label.endsWith('e')) return '${label}n';
    return '${label}e';
  }

  /// Reservierte Param-Keys, die nicht als Extra-Felder im Dialog erscheinen.
  Set<String> reservedParamKeysForDialog() {
    final keys = <String>{
      'lfdNummer',
      'photoPaths',
      qrCodeNummerParamKey,
      '__etageName',
    };
    for (final h in importHeaderRow) {
      if (isAnlagenCsvColumnParamKey(h)) keys.add(h.trim());
    }
    for (var level = 1; level <= 3; level++) {
      keys.addAll(allParamKeysForHierarchyLevel(level));
    }
    final schemaKey = resolveSchemaItemParamKey();
    if (schemaKey != null && schemaKey.isNotEmpty) keys.add(schemaKey);
    final leafKey = leafNameParamKey;
    if (leafKey != null && leafKey.isNotEmpty) keys.add(leafKey);
    final rfKey = resolveListGroupingParamKeyForLevel(1);
    if (rfKey != null && rfKey.isNotEmpty) keys.add(rfKey);
    return keys;
  }

  factory CsvSettings.defaults() {
    return const CsvSettings(
      level1: HierarchyLevelConfig(enabled: true, nameColumn: 2),
      level2: HierarchyLevelConfig(enabled: false, nameColumn: 1),
      level3: HierarchyLevelConfig(
        enabled: true,
        nameColumn: 1,
        useIdColumn: false,
      ),
      anlageBauteilSpalte: null,
      delimiterMode: 'auto',
      anlageKuerzel: 'A,Anlage',
      bauteilKuerzel: 'B,Bauteil',
      useDisciplineGrouping: true,
      labelGewerk: 'Gewerk',
      labelAnlage: 'Anlage',
      labelBauteil: 'Bauteil',
      attributeColumnPairs: [],
      importHeaderRow: [],
      exportDelimiter: ';',
    );
  }

  CsvSettings copyWith({
    HierarchyLevelConfig? level1,
    HierarchyLevelConfig? level2,
    HierarchyLevelConfig? level3,
    int? anlageBauteilSpalte,
    String? delimiterMode,
    String? anlageKuerzel,
    String? bauteilKuerzel,
    bool? useDisciplineGrouping,
    String? labelGewerk,
    String? labelAnlage,
    String? labelBauteil,
    List<AttributeColumnPair>? attributeColumnPairs,
    List<AttributeTripletColumn>? attributeTripletColumns,
    String? foto1SpalteLabel,
    String? foto2SpalteLabel,
    String? foto3SpalteLabel,
    String? foto4SpalteLabel,
    String? qrCodeNummerSpalteLabel,
    List<String>? importHeaderRow,
    String? exportDelimiter,
    String? groupingGewerkParamKey,
    String? groupingAnlageParamKey,
    String? displayNameParamKey,
    int? displayNameSpalte,
    bool clearAnlageBauteilSpalte = false,
    bool clearDisplayNameSpalte = false,
  }) {
    return CsvSettings(
      level1: level1 ?? this.level1,
      level2: level2 ?? this.level2,
      level3: level3 ?? this.level3,
      anlageBauteilSpalte: clearAnlageBauteilSpalte
          ? null
          : (anlageBauteilSpalte ?? this.anlageBauteilSpalte),
      delimiterMode: delimiterMode ?? this.delimiterMode,
      anlageKuerzel: anlageKuerzel ?? this.anlageKuerzel,
      bauteilKuerzel: bauteilKuerzel ?? this.bauteilKuerzel,
      useDisciplineGrouping: useDisciplineGrouping ?? this.useDisciplineGrouping,
      labelGewerk: labelGewerk ?? this.labelGewerk,
      labelAnlage: labelAnlage ?? this.labelAnlage,
      labelBauteil: labelBauteil ?? this.labelBauteil,
      attributeColumnPairs: attributeColumnPairs ?? this.attributeColumnPairs,
      attributeTripletColumns:
          attributeTripletColumns ?? this.attributeTripletColumns,
      foto1SpalteLabel: foto1SpalteLabel ?? this.foto1SpalteLabel,
      foto2SpalteLabel: foto2SpalteLabel ?? this.foto2SpalteLabel,
      foto3SpalteLabel: foto3SpalteLabel ?? this.foto3SpalteLabel,
      foto4SpalteLabel: foto4SpalteLabel ?? this.foto4SpalteLabel,
      qrCodeNummerSpalteLabel:
          qrCodeNummerSpalteLabel ?? this.qrCodeNummerSpalteLabel,
      importHeaderRow: importHeaderRow ?? this.importHeaderRow,
      exportDelimiter: exportDelimiter ?? this.exportDelimiter,
      groupingGewerkParamKey: groupingGewerkParamKey ?? this.groupingGewerkParamKey,
      groupingAnlageParamKey: groupingAnlageParamKey ?? this.groupingAnlageParamKey,
      displayNameParamKey: displayNameParamKey ?? this.displayNameParamKey,
      displayNameSpalte: clearDisplayNameSpalte
          ? null
          : (displayNameSpalte ?? this.displayNameSpalte),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level1': level1.toJson(),
      'level2': level2.toJson(),
      'level3': level3.toJson(),
      'anlageBauteilSpalte': anlageBauteilSpalte,
      'delimiterMode': delimiterMode,
      'anlageKuerzel': anlageKuerzel,
      'bauteilKuerzel': bauteilKuerzel,
      'useDisciplineGrouping': useDisciplineGrouping,
      'labelGewerk': labelGewerk,
      'labelAnlage': labelAnlage,
      'labelBauteil': labelBauteil,
      'attributeColumnPairs': attributeColumnPairs.map((p) => p.toJson()).toList(),
      'attributeTripletColumns':
          attributeTripletColumns.map((t) => t.toJson()).toList(),
      'foto1SpalteLabel': foto1SpalteLabel,
      'foto2SpalteLabel': foto2SpalteLabel,
      'foto3SpalteLabel': foto3SpalteLabel,
      'foto4SpalteLabel': foto4SpalteLabel,
      'qrCodeNummerSpalteLabel': qrCodeNummerSpalteLabel,
      'importHeaderRow': importHeaderRow,
      'exportDelimiter': exportDelimiter,
      'groupingGewerkParamKey': groupingGewerkParamKey,
      'groupingAnlageParamKey': groupingAnlageParamKey,
      'displayNameParamKey': displayNameParamKey,
      'displayNameSpalte': displayNameSpalte,
    };
  }

  factory CsvSettings.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('level1')) {
      return _fromNewJson(json);
    }
    return _migrateFromLegacyJson(json);
  }

  static CsvSettings _fromNewJson(Map<String, dynamic> json) {
    final pairsRaw = json['attributeColumnPairs'];
    final List<AttributeColumnPair> pairs = [];
    if (pairsRaw is List) {
      for (final e in pairsRaw) {
        if (e is Map<String, dynamic>) {
          pairs.add(AttributeColumnPair.fromJson(e));
        } else if (e is Map) {
          pairs.add(AttributeColumnPair.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    final tripletsRaw = json['attributeTripletColumns'];
    final List<AttributeTripletColumn> triplets = [];
    if (tripletsRaw is List) {
      for (final e in tripletsRaw) {
        if (e is Map<String, dynamic>) {
          triplets.add(AttributeTripletColumn.fromJson(e));
        } else if (e is Map) {
          triplets.add(AttributeTripletColumn.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return CsvSettings(
      level1: HierarchyLevelConfig.fromJson(
        json['level1'] is Map ? Map<String, dynamic>.from(json['level1'] as Map) : null,
      ),
      level2: HierarchyLevelConfig.fromJson(
        json['level2'] is Map ? Map<String, dynamic>.from(json['level2'] as Map) : null,
      ),
      level3: HierarchyLevelConfig.fromJson(
        json['level3'] is Map ? Map<String, dynamic>.from(json['level3'] as Map) : null,
      ),
      anlageBauteilSpalte: json['anlageBauteilSpalte'] as int?,
      delimiterMode: json['delimiterMode'] as String? ?? 'auto',
      anlageKuerzel: json['anlageKuerzel'] as String? ?? 'A,Anlage',
      bauteilKuerzel: json['bauteilKuerzel'] as String? ?? 'B,Bauteil',
      useDisciplineGrouping: json['useDisciplineGrouping'] as bool? ?? true,
      labelGewerk: json['labelGewerk'] as String? ?? 'Gewerk',
      labelAnlage: json['labelAnlage'] as String? ?? 'Anlage',
      labelBauteil: json['labelBauteil'] as String? ?? 'Bauteil',
      attributeColumnPairs: pairs,
      attributeTripletColumns: triplets,
      foto1SpalteLabel: json['foto1SpalteLabel'] as String?,
      foto2SpalteLabel: json['foto2SpalteLabel'] as String?,
      foto3SpalteLabel: json['foto3SpalteLabel'] as String?,
      foto4SpalteLabel: json['foto4SpalteLabel'] as String?,
      qrCodeNummerSpalteLabel: json['qrCodeNummerSpalteLabel'] as String?,
      importHeaderRow: _parseStringList(json['importHeaderRow']),
      exportDelimiter: json['exportDelimiter'] as String? ?? ';',
      groupingGewerkParamKey: json['groupingGewerkParamKey'] as String? ?? '',
      groupingAnlageParamKey: json['groupingAnlageParamKey'] as String? ?? '',
      displayNameParamKey: json['displayNameParamKey'] as String? ?? 'Name',
      displayNameSpalte: json['displayNameSpalte'] as int?,
    );
  }

  static CsvSettings _migrateFromLegacyJson(Map<String, dynamic> json) {
    final gewerk = json['gewerkSpalte'] as int? ?? 2;
    final name = json['nameSpalte'] as int? ?? 1;
    final lfd = json['lfdNummerSpalte'] as int? ?? 0;
    final anlageEbene = json['anlageEbeneSpalte'] as int?;
    final useDiscipline = json['useDisciplineGrouping'] as bool? ?? true;

    final HierarchyLevelConfig l1;
    final HierarchyLevelConfig l2;
    final HierarchyLevelConfig l3;

    if (anlageEbene != null && anlageEbene != name) {
      l1 = HierarchyLevelConfig(enabled: useDiscipline, nameColumn: gewerk);
      l2 = HierarchyLevelConfig(enabled: true, nameColumn: anlageEbene);
      l3 = HierarchyLevelConfig(
        enabled: true,
        nameColumn: name,
        useIdColumn: true,
        idColumn: lfd,
      );
    } else {
      l1 = HierarchyLevelConfig(enabled: useDiscipline, nameColumn: gewerk);
      l2 = const HierarchyLevelConfig(enabled: false, nameColumn: 1);
      l3 = HierarchyLevelConfig(
        enabled: true,
        nameColumn: name,
        useIdColumn: true,
        idColumn: lfd,
      );
    }

    return _fromNewJson({
      ...json,
      'level1': l1.toJson(),
      'level2': l2.toJson(),
      'level3': l3.toJson(),
    });
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e.toString()).toList();
  }

  /// Lädt projektbezogene CSV-Einstellungen (SharedPreferences → Defaults).
  static Future<CsvSettings> loadForProject(String projectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('csv_settings_$projectId');
      CsvSettings settings;
      if (raw != null && raw.trim().isNotEmpty) {
        settings = CsvSettings.fromJson(
          Map<String, dynamic>.from(json.decode(raw) as Map),
        );
      } else {
        settings = CsvSettings.defaults();
      }
      return _migrateLegacyTemplateCsvSettings(prefs, projectId, settings);
    } catch (_) {}
    return CsvSettings.defaults();
  }

  /// Speichert die Import-Headerzeile (Anlagen- und Gewerkevorlagen-CSV).
  static Future<void> saveImportHeaderRowForProject(
    String projectId,
    List<String> headerRow,
  ) async {
    final current = await loadForProject(projectId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'csv_settings_$projectId',
      json.encode(current.copyWith(importHeaderRow: headerRow).toJson()),
    );
  }

  static Future<CsvSettings> _migrateLegacyTemplateCsvSettings(
    SharedPreferences prefs,
    String projectId,
    CsvSettings settings,
  ) async {
    final legacyKey = 'template_csv_settings_$projectId';
    final legacyRaw = prefs.getString(legacyKey);
    if (legacyRaw == null || legacyRaw.trim().isEmpty) return settings;

    try {
      final legacy = Map<String, dynamic>.from(json.decode(legacyRaw) as Map);
      var updated = settings;

      final legacyHeader = _parseStringList(legacy['importHeaderRow']);
      if (legacyHeader.isNotEmpty && settings.importHeaderRow.isEmpty) {
        updated = updated.copyWith(importHeaderRow: legacyHeader);
      }

      if (settings.attributeTripletColumns.isEmpty) {
        final tripletsRaw = legacy['attributeTripletColumns'];
        if (tripletsRaw is List && tripletsRaw.isNotEmpty) {
          final triplets = <AttributeTripletColumn>[];
          for (final e in tripletsRaw) {
            if (e is Map<String, dynamic>) {
              triplets.add(AttributeTripletColumn.fromJson(e));
            } else if (e is Map) {
              triplets.add(
                AttributeTripletColumn.fromJson(Map<String, dynamic>.from(e)),
              );
            }
          }
          if (triplets.isNotEmpty) {
            updated = updated.copyWith(attributeTripletColumns: triplets);
          }
        }
      }

      if (updated != settings) {
        await prefs.setString(
          'csv_settings_$projectId',
          json.encode(updated.toJson()),
        );
      }
      await prefs.remove(legacyKey);
      return updated;
    } catch (_) {
      return settings;
    }
  }
}

class CsvSettingsNotifier extends StateNotifier<CsvSettings> {
  final String projectId;

  CsvSettingsNotifier(this.projectId) : super(CsvSettings.defaults());

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'csv_settings_$projectId';
      final settingsJson = prefs.getString(key);
      if (settingsJson != null) {
        final decoded = json.decode(settingsJson) as Map<String, dynamic>;
        state = CsvSettings.fromJson(decoded);
        return;
      }
    } catch (_) {}
  }

  Future<void> save(CsvSettings settings) async {
    state = settings;
    final prefs = await SharedPreferences.getInstance();
    final key = 'csv_settings_$projectId';
    await prefs.setString(key, json.encode(settings.toJson()));
  }

  /// Entfernt gespeicherte Anlagen-CSV-Import-Struktur (Header, Attribut-Spaltenpaare).
  Future<void> clearAnlagenCsvImportStructure() async {
    await save(
      state.copyWith(
        importHeaderRow: const [],
        attributeColumnPairs: const [],
        attributeTripletColumns: const [],
      ),
    );
  }

  Future<void> saveImportHeaderRow(List<String> headerRow) async {
    await save(state.copyWith(importHeaderRow: headerRow));
  }
}

final csvSettingsProvider =
    StateNotifierProviderFamily<CsvSettingsNotifier, CsvSettings, String>(
  (ref, projectId) => CsvSettingsNotifier(projectId),
);

