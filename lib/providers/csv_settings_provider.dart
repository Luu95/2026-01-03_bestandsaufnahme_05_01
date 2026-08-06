// lib/providers/csv_settings_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/csv_hierarchy_level.dart';
import '../utils/app_log.dart';

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
  /// Manuelle Attribut-Range (0-basiert): erste Spalte der ersten Dreiergruppe.
  /// Wenn gesetzt zusammen mit [attributeCount], hat das Vorrang vor Header-Erkennung.
  final int? attributeStartColumn;
  /// Anzahl Attribute (= Anzahl Dreiergruppen Name/Typ/Wert).
  final int? attributeCount;
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
  /// Param-Key für Anzeige/Vorlagen (Legacy; Listen-Titel nutzt [listTitleInputFieldIndex]).
  final String displayNameParamKey;
  /// Optional: Spalte aus Anlagen-CSV-Import (nur wenn importHeaderRow gesetzt ist).
  final int? displayNameSpalte;
  /// Welches Eingabefeld (1-basiert, Dialogreihenfolge) als Listen-Titel dient.
  final int listTitleInputFieldIndex;
  /// Welches Eingabefeld (1-basiert) als Listen-Untertitel dient. 0 = keiner.
  final int listSubtitleInputFieldIndex;

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
    this.attributeStartColumn,
    this.attributeCount,
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
    this.listTitleInputFieldIndex = 1,
    this.listSubtitleInputFieldIndex = 0,
  });

  /// True, wenn mindestens einmal ein Anlagen-CSV-Import durchgeführt wurde.
  bool get hasAnlagenCsvImport => importHeaderRow.isNotEmpty;

  /// Manuelle Attribut-Range ist konfiguriert (Erste Spalte + Anzahl).
  bool get hasManualAttributeRange =>
      attributeStartColumn != null &&
      attributeStartColumn! >= 0 &&
      attributeCount != null &&
      attributeCount! > 0;

  /// Letzte Spalte der manuellen Range (0-basiert), sonst null.
  int? get attributeLastColumn {
    if (!hasManualAttributeRange) return null;
    return attributeStartColumn! + attributeCount! * 3 - 1;
  }

  /// Erzeugt [count] Dreiergruppen ab [startColumn] (0-basiert): Name, Typ, Wert.
  static List<AttributeTripletColumn> tripletsFromStartAndCount({
    required int startColumn,
    required int count,
  }) {
    if (startColumn < 0 || count <= 0) return const [];
    final groups = <AttributeTripletColumn>[];
    for (var i = 0; i < count; i++) {
      final base = startColumn + i * 3;
      groups.add(AttributeTripletColumn(
        nameColumn: base,
        typeColumn: base + 1,
        artColumn: base + 2,
      ));
    }
    return groups;
  }

  /// Erzeugt Dreiergruppen aus 1-basiertem Spaltenbereich (inkl. Ende).
  /// Wirft [ArgumentError], wenn der Bereich nicht durch 3 teilbar ist.
  static List<AttributeTripletColumn> tripletsFromInclusiveRange1Based({
    required int firstColumn1Based,
    required int lastColumn1Based,
  }) {
    if (firstColumn1Based < 1 || lastColumn1Based < firstColumn1Based) {
      throw ArgumentError('Ungültiger Spaltenbereich (Erste ≤ Letzte, ab 1).');
    }
    final columnCount = lastColumn1Based - firstColumn1Based + 1;
    if (columnCount % 3 != 0) {
      throw ArgumentError(
        'Anzahl Spalten ($columnCount) muss durch 3 teilbar sein.',
      );
    }
    return tripletsFromStartAndCount(
      startColumn: firstColumn1Based - 1,
      count: columnCount ~/ 3,
    );
  }

  /// Alle aktiven Ebenen in Reihenfolge (1 → 2 → 3).
  List<HierarchyLevelConfig> get enabledLevelsOrdered {
    final levels = <HierarchyLevelConfig>[];
    if (level1.enabled) levels.add(level1);
    if (level2.enabled) levels.add(level2);
    if (level3.enabled) levels.add(level3);
    return levels;
  }

  /// Unterste aktive Ebene = konfiguriertes Blatt (ein CSV-Datensatz pro Zeile).
  /// Pro Zeile kann das effektive Blatt tiefer liegen, wenn untere Ebenen leer sind
  /// – siehe [resolveEffectiveLeafLevelNumber].
  HierarchyLevelConfig? get leafLevel {
    final levels = enabledLevelsOrdered;
    return levels.isEmpty ? null : levels.last;
  }

  /// Tiefste aktive Ebene mit nicht-leerem Wert (Level-Nummer 1–3), sonst null.
  int? resolveEffectiveLeafLevelNumber(Map<int, String> levelValues) {
    final levels = enabledLevelsOrdered;
    for (var i = levels.length - 1; i >= 0; i--) {
      final levelNum = levelNumberAtEnabledIndex(i);
      final v = levelValues[levelNum]?.trim() ?? '';
      if (v.isNotEmpty) return levelNum;
    }
    return null;
  }

  /// Spaltenindizes aller drei Ebenen-Konfigs (auch deaktiviert) – typisch 0/1/2.
  List<int> allConfiguredHierarchyNameColumns() => [
        level1.nameColumn,
        level2.nameColumn,
        level3.nameColumn,
      ];

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
  /// Hierarchie-Spalten (Ebene1–3) sind immer reserviert, auch wenn deaktiviert.
  Set<int> reservedImportColumnIndices() {
    final indices = <int>{};
    for (final col in allConfiguredHierarchyNameColumns()) {
      if (col >= 0) indices.add(col);
    }
    for (final level in [level1, level2, level3]) {
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

  /// Aktive Hierarchie-Ebene [level] (1–3), sonst null.
  HierarchyLevelConfig? hierarchyLevelConfig(int level) =>
      _hierarchyLevelConfig(level);

  /// Hierarchie-Ebene-Config auch wenn deaktiviert (für Spaltenindex 0/1/2).
  HierarchyLevelConfig hierarchyLevelConfigAlways(int level) {
    switch (level) {
      case 1:
        return level1;
      case 2:
        return level2;
      case 3:
        return level3;
      default:
        return level1;
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

  /// True, wenn [value] nur ein Platzhalter/Ebenen-Label ist (kein echter Anzeigename).
  bool isPlaceholderDisplayValue(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return true;
    if (t == 'Eintrag') return true;
    if (t == labelGewerk || t == labelAnlage || t == labelBauteil) return true;
    final leafLabel = resolveLeafLevelLabel().trim();
    if (leafLabel.isNotEmpty && t == leafLabel) return true;
    final underRoLabel = resolveDatensatzUnderRevisionsobjektLabel().trim();
    if (underRoLabel.isNotEmpty && t == underRoLabel) return true;
    for (var level = 1; level <= 3; level++) {
      final headerLabel = hierarchyLevelHeaderLabel(level).trim();
      if (headerLabel.isNotEmpty && t == headerLabel) return true;
    }
    return false;
  }

  /// True, wenn [value] kein eigenständiger Anzeigename ist (Platzhalter oder
  /// identisch mit Hierarchie-/Schema-Wert, z. B. Revisionsobjekt).
  bool isNonDistinctDisplayValue(
    String? value,
    Map<String, dynamic> params,
  ) {
    final t = value?.trim() ?? '';
    if (isPlaceholderDisplayValue(t)) return true;

    final schemaValue = schemaItemValueFromParams(params)?.trim() ?? '';
    if (schemaValue.isNotEmpty &&
        t.toLowerCase() == schemaValue.toLowerCase()) {
      return true;
    }
    final roValue = revisionsobjektValueFromParams(params)?.trim() ?? '';
    if (roValue.isNotEmpty && t.toLowerCase() == roValue.toLowerCase()) {
      return true;
    }

    final enabled = enabledLevelsOrdered;
    final leafNum = enabled.isEmpty
        ? null
        : levelNumberAtEnabledIndex(enabled.length - 1);
    for (var level = 1; level <= 3; level++) {
      // Blatt-Hierarchie-Wert nicht als „Duplikat“ werten (Import-Name).
      if (leafNum != null && level == leafNum) continue;
      final hv = hierarchyLevelValueFromParams(params, level)?.trim() ?? '';
      if (hv.isNotEmpty && t.toLowerCase() == hv.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  /// Markiert Anlagen, die ohne echten Titel gespeichert wurden.
  static const String listNamePlaceholderParamKey = '__listNamePlaceholder';

  /// Beim Speichern gesetzter Listen-Titel (Wert von Eingabefeld N).
  static const String listTitleParamKey = '__listTitle';

  bool hasListNamePlaceholder(Map<String, dynamic> params) {
    final v = params[listNamePlaceholderParamKey];
    return v == true || v?.toString() == 'true';
  }

  /// Param-Key für die Titelzeile in der Anlagenliste.
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

  /// Spalten-Header/Param-Keys aus Anlagen-CSV (ATT1, ATT1_wert, ATT1_TYPE, …) – keine Dialog-Felder.
  static bool isAnlagenCsvColumnParamKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return false;
    final lower = k.toLowerCase();
    if (RegExp(r'^att\d+$').hasMatch(lower)) return true;
    if (RegExp(r'^att\d+_wert$').hasMatch(lower)) return true;
    if (RegExp(r'^att_wert\d+$').hasMatch(lower)) return true;
    if (RegExp(r'^att\d+_art$').hasMatch(lower)) return true;
    if (RegExp(r'^att_art\d+$').hasMatch(lower)) return true;
    if (RegExp(r'^att\d+_type$').hasMatch(lower)) return true;
    if (RegExp(r'^att_type\d+$').hasMatch(lower)) return true;
    if (RegExp(r'^att\d+_options$').hasMatch(lower)) return true;
    if (RegExp(r'^att_options\d+$').hasMatch(lower)) return true;
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
    } else if (lowerType == 'date' || lowerType == 'datum') {
      entry['type'] = 'date';
    } else if (lowerType == 'multiline' || lowerType == 'bemerkung') {
      entry['type'] = 'multiline';
    } else if (lowerType == 'dropdown' ||
        lowerType == 'select' ||
        lowerType == 'option') {
      entry['type'] = 'dropdown';
      final legacy = parseGewerkeOptionsList(legacyOptionsStr);
      if (legacy.isNotEmpty) entry['options'] = legacy;
    } else {
      // Unbekannte TYPE-Zellen (z. B. versehentlich eingetragene Werte) → Freitext
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

  /// Gespeicherte Dreiergruppen passen zum Header (Wertspalte ≠ TYPE/OPTIONS).
  static bool quadrupletsMatchHeader(
    List<AttributeTripletColumn> quadruplets,
    List<String> headers,
  ) {
    if (quadruplets.isEmpty || headers.isEmpty) return false;
    for (final g in quadruplets) {
      if (g.nameColumn < 0 || g.nameColumn >= headers.length) return false;
      if (g.typeColumn < 0 || g.typeColumn >= headers.length) return false;
      final typeToken = normalizeAttHeaderToken(headers[g.typeColumn]);
      if (!typeToken.contains('_TYPE')) return false;
      // Wertspalte muss ART/WERT sein – nie TYPE (sonst landen Typdefinitionen als Werte).
      if (g.artColumn < 0 || g.artColumn >= headers.length) return false;
      if (g.artColumn == g.typeColumn) return false;
      if (isGewerkeTypeDefinitionHeader(headers[g.artColumn])) return false;
      final artToken = normalizeAttHeaderToken(headers[g.artColumn]);
      if (!artToken.contains('_ART') && !artToken.contains('_WERT')) {
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
    ImportAttributeMapping manualOrSettings() {
      if (settings.hasManualAttributeRange) {
        final manual = settings.attributeTripletColumns.isNotEmpty
            ? settings.attributeTripletColumns
            : tripletsFromStartAndCount(
                startColumn: settings.attributeStartColumn!,
                count: settings.attributeCount!,
              );
        return ImportAttributeMapping(pairs: const [], quadruplets: manual);
      }
      return ImportAttributeMapping(
        pairs: settings.attributeColumnPairs,
        quadruplets: settings.attributeTripletColumns,
      );
    }

    if (headerRow.isEmpty) {
      return manualOrSettings();
    }

    // Bekannte ATT-Formate: Header-Erkennung hat Vorrang vor manueller Range
    // (sonst bleibt _schema bei Gewerkevorlagen leer und Neuaufnahme ohne Felder).
    if (headerLooksLikeAnlagenWertFormat(headerRow)) {
      final detected = detectAnlagenAttributePairsFromHeader(headerRow);
      if (detected.isNotEmpty) {
        return ImportAttributeMapping(
          pairs: detected,
          quadruplets: const [],
        );
      }
      return manualOrSettings();
    }

    if (headerLooksLikeGewerkeQuadrupletFormat(headerRow)) {
      final detected = detectQuadrupletsFromHeader(headerRow);
      if (detected.isNotEmpty) {
        return ImportAttributeMapping(pairs: const [], quadruplets: detected);
      }
      if (quadrupletsMatchHeader(settings.attributeTripletColumns, headerRow)) {
        return ImportAttributeMapping(
          pairs: const [],
          quadruplets: settings.attributeTripletColumns,
        );
      }
      return manualOrSettings();
    }

    if (quadrupletsMatchHeader(settings.attributeTripletColumns, headerRow)) {
      return ImportAttributeMapping(
        pairs: const [],
        quadruplets: settings.attributeTripletColumns,
      );
    }

    // Kein ATT-Header: manuelle Range nutzen (z. B. freie Spalten als Dreiergruppen).
    return manualOrSettings();
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

  /// Dialog-Schema aus ATT-Namen in gespeicherten CSV-Zellen (auch ohne Wert).
  static List<Map<String, dynamic>> schemaFieldsFromCsvAttRowCells(
    Map<String, dynamic> params, {
    required List<String> importHeaders,
  }) {
    if (importHeaders.isEmpty) return const [];
    final raw = params[csvRowCellsParamKey];
    if (raw is! Map) return const [];
    final cells = <String, String>{};
    for (final e in raw.entries) {
      final k = e.key.toString().trim();
      if (k.isEmpty) continue;
      cells[k] = e.value?.toString() ?? '';
    }
    if (cells.isEmpty) return const [];

    final triplets = detectQuadrupletsFromHeader(importHeaders);
    if (triplets.isEmpty) {
      // Zweier-Format: Name-Spalte enthält Feldlabel
      final pairs = detectAnlagenAttributePairsFromHeader(importHeaders);
      final fields = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (var i = 0; i < pairs.length; i++) {
        final pair = pairs[i];
        if (pair.nameColumn < 0 || pair.nameColumn >= importHeaders.length) {
          continue;
        }
        final nameHeader = importHeaders[pair.nameColumn].trim();
        final name = (cells[nameHeader] ?? '').trim();
        if (name.isEmpty || isAnlagenCsvColumnParamKey(name)) continue;
        if (looksLikeTypeOrOptionsDefinition(name)) continue;
        if (seen.contains(name.toLowerCase())) continue;
        seen.add(name.toLowerCase());
        fields.add({
          'key': name,
          'label': normalizeFieldLabelForDisplay(name),
          'type': 'text',
          'attSlot': attSlotForPair(pair, i),
        });
      }
      return fields;
    }

    final fields = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (var i = 0; i < triplets.length; i++) {
      final t = triplets[i];
      if (t.nameColumn < 0 || t.nameColumn >= importHeaders.length) continue;
      final nameHeader = importHeaders[t.nameColumn].trim();
      final name = (cells[nameHeader] ?? '').trim();
      if (name.isEmpty || isAnlagenCsvColumnParamKey(name)) continue;
      if (looksLikeTypeOrOptionsDefinition(name)) continue;
      if (seen.contains(name.toLowerCase())) continue;
      seen.add(name.toLowerCase());

      var typeStr = '';
      if (t.typeColumn >= 0 && t.typeColumn < importHeaders.length) {
        typeStr = (cells[importHeaders[t.typeColumn].trim()] ?? '').trim();
      }
      final entry = schemaFieldFromGewerkeTypeCell(name, typeStr);
      entry['attSlot'] = attNumberFromHeaderLabel(nameHeader) ?? (i + 1);
      entry.remove('art');
      fields.add(entry);
    }
    return fields;
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
      if (looksLikeTypeOrOptionsDefinition(key)) continue;
      final value = entry.value;
      if (value == null || value.toString().trim().isEmpty) continue;
      if (looksLikeTypeOrOptionsDefinition(value.toString())) continue;
      fields.add({
        'key': key,
        'label': normalizeFieldLabelForDisplay(key),
        'type': 'text',
      });
    }
    return fields;
  }

  /// Nummer aus Param-Key ATT7, ATT7_wert, ATT_WERT7, ATT7_TYPE (sonst null).
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
    final t1 = RegExp(r'^ATT(\d+)_TYPE$').firstMatch(upper);
    if (t1 != null) return int.parse(t1.group(1)!);
    final t2 = RegExp(r'^ATT_TYPE(\d+)$').firstMatch(upper);
    if (t2 != null) return int.parse(t2.group(1)!);
    final o1 = RegExp(r'^ATT(\d+)_OPTIONS$').firstMatch(upper);
    if (o1 != null) return int.parse(o1.group(1)!);
    final o2 = RegExp(r'^ATT_OPTIONS(\d+)$').firstMatch(upper);
    if (o2 != null) return int.parse(o2.group(1)!);
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
          if (isAnlagenCsvColumnParamKey(key) ||
              isAnlagenCsvColumnParamKey(label)) {
            return false;
          }
          // Options-/TYPE-Strings nie als eigenes Eingabefeld (gehören in dropdown options).
          if (looksLikeTypeOrOptionsDefinition(key) ||
              looksLikeTypeOrOptionsDefinition(label)) {
            return false;
          }
          return true;
        })
        .map((f) => Map<String, dynamic>.from(f))
        .toList();
  }

  /// true bei reinen Typ-Tokens oder Pipe-Optionslisten (ATT_TYPE-Inhalt).
  static bool looksLikeTypeOrOptionsDefinition(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return false;
    final lower = v.toLowerCase();
    const tokens = {
      'text',
      'freitext',
      'number',
      'int',
      'date',
      'datum',
      'multiline',
      'bemerkung',
      'dropdown',
      'select',
      'option',
    };
    if (tokens.contains(lower)) return true;
    if (!v.contains('|')) return false;
    final parts = v
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.length >= 2;
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
      // TYPE/OPTIONS sind Metadaten, niemals Feldwerte.
      if (upper.contains('_TYPE') || upper.contains('_OPTIONS')) {
        continue;
      }
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

  /// Korrigiert bereits importierte Params, bei denen fälschlich ATT*_TYPE als Wert landete.
  /// Nutzt gespeicherte Rohzellen (__csvRowCells), falls vorhanden.
  static void repairParamsMistakenlyFilledFromTypeColumns({
    required Map<String, dynamic> params,
    required List<String> importHeaders,
    List<Map<String, dynamic>> schemaFields = const [],
  }) {
    if (importHeaders.isEmpty) return;
    final rawCells = params[csvRowCellsParamKey];
    if (rawCells is! Map) return;
    final cells = <String, String>{};
    for (final e in rawCells.entries) {
      final k = e.key.toString().trim();
      if (k.isEmpty) continue;
      cells[k] = e.value?.toString() ?? '';
    }
    if (cells.isEmpty) return;

    final triplets = detectQuadrupletsFromHeader(importHeaders);
    if (triplets.isEmpty) return;

    final nonGlobal =
        schemaFields.where((f) => f['isGlobal'] != true).toList();

    final typeValsInRow = <String>{};
    for (final t in triplets) {
      if (t.typeColumn < 0 || t.typeColumn >= importHeaders.length) continue;
      final typeHeader = importHeaders[t.typeColumn].trim();
      if (typeHeader.isEmpty) continue;
      final typeVal = (cells[typeHeader] ?? '').trim();
      if (typeVal.isNotEmpty) typeValsInRow.add(typeVal);
    }

    for (var i = 0; i < triplets.length; i++) {
      final t = triplets[i];
      if (t.typeColumn < 0 || t.typeColumn >= importHeaders.length) continue;
      final typeHeader = importHeaders[t.typeColumn].trim();
      if (typeHeader.isEmpty) continue;
      final typeVal = (cells[typeHeader] ?? '').trim();

      final artVal = (t.artColumn >= 0 && t.artColumn < importHeaders.length)
          ? (cells[importHeaders[t.artColumn].trim()] ?? '').trim()
          : '';

      final nameHeader = t.nameColumn >= 0 && t.nameColumn < importHeaders.length
          ? importHeaders[t.nameColumn].trim()
          : '';
      final attSlot = attNumberFromHeaderLabel(nameHeader) ?? (i + 1);
      final nameCell =
          (nameHeader.isNotEmpty ? cells[nameHeader] : null)?.trim() ?? '';

      var schemaKey = '';
      final field = schemaFieldAtAttSlot(attSlot, nonGlobal);
      if (field != null) {
        schemaKey = (field['key'] ?? '').toString().trim();
      }
      if (schemaKey.isEmpty) {
        for (final candidate in [nameCell, nameHeader]) {
          if (candidate.isEmpty) continue;
          for (final f in nonGlobal) {
            final key = (f['key'] ?? '').toString();
            final label = (f['label'] ?? '').toString();
            if (paramKeysMatch(key, candidate) ||
                paramKeysMatch(label, candidate)) {
              schemaKey = key;
              break;
            }
          }
          if (schemaKey.isNotEmpty) break;
        }
      }
      if (schemaKey.isEmpty && nameCell.isNotEmpty) {
        schemaKey = nameCell;
      }
      if (schemaKey.isEmpty) continue;

      final current = params[schemaKey]?.toString().trim() ?? '';
      // Bei Gewerke-Tripletts (ATT + TYPE + ART) ist ART nur Gruppierungs-Metadatum
      // im Schema – niemals Anlagen-Feldwert (sonst landet z. B. „Allgemein“ in allen Feldern).
      if (current.isEmpty) {
        continue;
      }

      // Wert entspricht der TYPE-Zelle dieses Slots → Typdefinition entfernen.
      if (typeVal.isNotEmpty && current == typeVal) {
        params.remove(schemaKey);
        continue;
      }

      // Wert ist irgendeine TYPE-Zelle dieser Zeile → Typdefinition entfernen.
      if (typeValsInRow.contains(current)) {
        params.remove(schemaKey);
        continue;
      }

      // Wert ist nur der ART-Gruppenname dieses Feldes → ebenfalls entfernen.
      if (artVal.isNotEmpty && current == artVal) {
        params.remove(schemaKey);
      }
    }

    // Schema-art als Gruppenlabel: falls Params bereits damit befüllt wurden, leeren.
    clearParamsThatAreSchemaArtGroups(
      params: params,
      schemaFields: schemaFields,
    );

    // Übrig gebliebene ATT*_TYPE / ATT*_OPTIONS Keys entfernen.
    final drop = params.keys
        .where((k) => isAnlagenCsvColumnParamKey(k.toString()))
        .map((k) => k.toString())
        .toList();
    for (final k in drop) {
      params.remove(k);
    }
  }

  /// Entfernt Param-Werte, die nur dem Schema-`art`-Gruppentitel entsprechen
  /// (z. B. „Allgemein“) – ART ist Layout-Metadatum, kein Eingabewert.
  static void clearParamsThatAreSchemaArtGroups({
    required Map<String, dynamic> params,
    List<Map<String, dynamic>> schemaFields = const [],
  }) {
    if (schemaFields.isEmpty) return;
    for (final field in schemaFields) {
      if (field['isGlobal'] == true) continue;
      final art = effectiveSchemaArtGroup(field);
      if (art == null || art.isEmpty) continue;
      final key = (field['key'] ?? '').toString().trim();
      final label = (field['label'] ?? '').toString().trim();
      for (final pk in params.keys.toList()) {
        final pks = pk.toString();
        if (pks.startsWith('__')) continue;
        final matchesField = (key.isNotEmpty && paramKeysMatch(pks, key)) ||
            (label.isNotEmpty && paramKeysMatch(pks, label));
        if (!matchesField) continue;
        final current = params[pk]?.toString().trim() ?? '';
        if (current.isNotEmpty && paramKeysMatch(current, art)) {
          params[pk] = '';
        }
      }
    }
  }

  /// Entfernt Param-Werte, die wie TYPE-Definitionen aussehen (text/NUMBER/Opt|Opt).
  /// Greift auch ohne __csvRowCells – gegen „doppelte“ Felder mit Typ als Inhalt.
  static void clearParamsThatLookLikeTypeDefinitions({
    required Map<String, dynamic> params,
    List<Map<String, dynamic>> schemaFields = const [],
  }) {
    final nonGlobal =
        schemaFields.where((f) => f['isGlobal'] != true).toList();

    bool looksLikeBareTypeToken(String value) {
      return looksLikeTypeOrOptionsDefinition(value);
    }

    final keys = params.keys.map((k) => k.toString()).toList();
    for (final key in keys) {
      if (key.startsWith('__') || isAttSlotParamKey(key)) continue;
      if (isAnlagenCsvColumnParamKey(key)) {
        params.remove(key);
        continue;
      }
      // Options-Listen als Param-Key (falsch aus TYPE) entfernen.
      if (looksLikeTypeOrOptionsDefinition(key)) {
        params.remove(key);
        continue;
      }
      final current = params[key]?.toString().trim() ?? '';
      if (current.isEmpty) continue;

      Map<String, dynamic>? field;
      for (final f in nonGlobal) {
        final fk = (f['key'] ?? '').toString();
        final fl = (f['label'] ?? '').toString();
        if (paramKeysMatch(fk, key) || paramKeysMatch(fl, key)) {
          field = f;
          break;
        }
      }

      if (field != null) {
        final typeCell = () {
          final type = (field!['type'] ?? '').toString().trim().toLowerCase();
          final options = field['options'];
          if (options is List && options.isNotEmpty) {
            return options
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .join('|');
          }
          if (type == 'dropdown' || type == 'select') return '';
          if (type.isEmpty) return 'text';
          return type;
        }();
        if (typeCell.isNotEmpty && current == typeCell) {
          params.remove(key);
          continue;
        }
      }

      if (looksLikeBareTypeToken(current)) {
        // Nur leeren, wenn kein sinnvoller Nutzerwert vermutet wird:
        // reine Typ-Tokens / Options-Pipes ohne echten Freitext.
        params.remove(key);
      }
    }
  }

  /// art nur als echte Gruppen-Kategorie – nicht Label/Typ-Definition.
  static String? effectiveSchemaArtGroup(Map<String, dynamic> fieldDef) {
    final art = normalizeFieldLabelForDisplay(
      (fieldDef['art'] ?? '').toString(),
    );
    if (art.isEmpty) return null;
    final label = normalizeFieldLabelForDisplay(
      (fieldDef['label'] ?? fieldDef['key'] ?? '').toString(),
    );
    if (label.isNotEmpty && paramKeysMatch(art, label)) return null;
    final lower = art.toLowerCase();
    if (lower == 'text' ||
        lower == 'number' ||
        lower == 'freitext' ||
        art.contains('|')) {
      return null;
    }
    return art;
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

  /// Listen-Titel, wenn das gewählte Eingabefeld leer ist.
  static const String unknownAnlageListLabel = 'Unbekannte Anlage';

  /// Eingabefelder in Dialogreihenfolge (ohne Hierarchie-/Blatt-Spalten).
  List<Map<String, dynamic>> listInputFieldsFromSchema(
    List<Map<String, dynamic>> schemaFields,
  ) {
    final filtered = filterSchemaFieldsForDialog(schemaFields);
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    final leaf = leafNameParamKey?.trim() ?? '';
    for (final field in filtered) {
      final key = (field['key'] ?? '').toString().trim();
      if (key.isEmpty) continue;
      if (isAnlagenCsvColumnParamKey(key)) continue;
      if (isEbeneHierarchyHeader(key)) continue;
      if (isUpperHierarchyParamKey(key)) continue;
      if (isHierarchyParamKey(key)) continue;
      // CSV-Blattspalte ausblenden (wie im Dialog), Anzeige-Param „Name“ bleibt.
      if (leaf.isNotEmpty && paramKeysMatch(key, leaf)) continue;
      final norm = key.toLowerCase();
      if (seen.contains(norm)) continue;
      seen.add(norm);
      result.add(Map<String, dynamic>.from(field));
    }
    return result;
  }

  /// Wert des n-ten Eingabefelds (1-basiert). Null wenn leer/fehlend.
  ///
  /// Reihenfolge: zuerst ATT-Slot == Index, sonst Positionsindex in [schemaFields]
  /// (nach Filter wie im Anlagendialog).
  String? valueAtListInputFieldIndex(
    Map<String, dynamic> params, {
    required int fieldIndex1Based,
    List<Map<String, dynamic>> schemaFields = const [],
  }) {
    if (fieldIndex1Based < 1) return null;

    String? readKey(String key) {
      final v = paramValueForKey(params, key)?.trim() ?? '';
      return v.isEmpty ? null : v;
    }

    final fields = listInputFieldsFromSchema(schemaFields);
    if (fields.isNotEmpty) {
      // 1) Expliziter ATT-Slot (Eingabefeld 1 ≈ ATT1)
      for (final field in fields) {
        final slot = attSlotFromSchemaField(field);
        if (slot != fieldIndex1Based) continue;
        final key = (field['key'] ?? '').toString().trim();
        if (key.isEmpty) continue;
        final v = readKey(key);
        if (v != null) return v;
      }
      // 2) Positionsindex wie im Dialog
      if (fieldIndex1Based <= fields.length) {
        final key = (fields[fieldIndex1Based - 1]['key'] ?? '').toString();
        final v = readKey(key);
        if (v != null) return v;
      }
    }

    // 3) Über _att_slot_* in Params
    for (final entry in params.entries) {
      final k = entry.key.toString();
      if (!isAttSlotParamKey(k)) continue;
      final slot = int.tryParse(entry.value?.toString() ?? '');
      if (slot != fieldIndex1Based) continue;
      final paramKey = k.substring(attSlotParamKeyPrefix.length);
      final v = readKey(paramKey);
      if (v != null) return v;
    }

    // 4) Ohne Schema: nicht-reservierte Params (Insertion-Order, nicht alphabetisch)
    if (fields.isEmpty) {
      final leaf = leafNameParamKey?.trim() ?? '';
      final keys = <String>[];
      for (final entry in params.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty || key.startsWith('_')) continue;
        if (matchesReservedDialogParamKey(key)) continue;
        if (isAnlagenCsvColumnParamKey(key)) continue;
        if (isEbeneHierarchyHeader(key)) continue;
        if (isUpperHierarchyParamKey(key)) continue;
        if (isHierarchyParamKey(key)) continue;
        if (leaf.isNotEmpty && paramKeysMatch(key, leaf)) continue;
        keys.add(key);
      }
      if (fieldIndex1Based <= keys.length) {
        return readKey(keys[fieldIndex1Based - 1]);
      }
    }
    return null;
  }

  /// Listen-Titel: gespeicherter Wert vom letzten Speichern, sonst Eingabefeld-Index.
  String listTitleValueFromParams(
    Map<String, dynamic> params, {
    List<Map<String, dynamic>> schemaFields = const [],
  }) {
    final stored = params[listTitleParamKey]?.toString().trim() ?? '';
    if (stored.isNotEmpty && stored != unknownAnlageListLabel) {
      return stored;
    }

    final v = valueAtListInputFieldIndex(
      params,
      fieldIndex1Based:
          listTitleInputFieldIndex < 1 ? 1 : listTitleInputFieldIndex,
      schemaFields: schemaFields,
    );
    if (v != null && v.isNotEmpty) return v;
    return unknownAnlageListLabel;
  }

  /// Listen-Untertitel aus dem konfigurierten Eingabefeld (null wenn Index 0/leer).
  String? listSubtitleValueFromParams(
    Map<String, dynamic> params, {
    List<Map<String, dynamic>> schemaFields = const [],
  }) {
    if (listSubtitleInputFieldIndex < 1) return null;
    return valueAtListInputFieldIndex(
      params,
      fieldIndex1Based: listSubtitleInputFieldIndex,
      schemaFields: schemaFields,
    );
  }

  /// Titelzeile nur aus dem Legacy-Param-Key (Vorlagen / Anzeigename-Schreiben).
  String? displayNameValueFromParams(
    Map<String, dynamic> params, {
    List<Map<String, dynamic>> schemaFields = const [],
  }) {
    bool usable(String? v) =>
        v != null &&
        v.isNotEmpty &&
        !isNonDistinctDisplayValue(v, params);

    final keys = <String>{};
    final explicit = displayNameParamKey.trim();
    if (explicit.isNotEmpty && !mustNotReceiveDisplayName(explicit)) {
      keys.add(explicit);
    }
    final configured = resolveDisplayNameParamKey()?.trim() ?? '';
    if (configured.isNotEmpty &&
        !isUpperHierarchyParamKey(configured) &&
        !mustNotReceiveDisplayName(configured)) {
      keys.add(configured);
    }

    for (final key in keys) {
      final direct = paramValueForKey(params, key);
      if (usable(direct)) return direct;
      for (final field in schemaFields) {
        final fieldKey = (field['key'] ?? '').toString();
        final fieldLabel = (field['label'] ?? fieldKey).toString();
        if (fieldKey.isEmpty) continue;
        if (!paramKeysMatch(fieldKey, key) &&
            !paramKeysMatch(fieldLabel, key)) {
          continue;
        }
        final fromField = paramValueForKey(params, fieldKey);
        if (usable(fromField)) return fromField;
      }
    }
    return null;
  }

  void writeDisplayNameToParams(Map<String, dynamic> params, String value) {
    final v = value.trim();
    if (v.isEmpty || isNonDistinctDisplayValue(v, params)) return;

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

  /// Entfernt versehentlich gespeicherte Ebenen-/Schema-Platzhalter aus dem Titel-Param.
  void clearPlaceholderDisplayNameFromParams(Map<String, dynamic> params) {
    final key = resolveDisplayNameParamKey()?.trim();
    if (key == null || key.isEmpty) return;
    for (final entry in params.entries.toList()) {
      final paramKey = entry.key.toString();
      if (!paramKeysMatch(paramKey, key) && paramKey != key) continue;
      if (isNonDistinctDisplayValue(entry.value?.toString(), params)) {
        params[paramKey] = '';
      }
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
      listNamePlaceholderParamKey,
      listTitleParamKey,
      labelBauteil,
    };
    for (final h in importHeaderRow) {
      final trimmed = h.trim();
      if (trimmed.isEmpty) continue;
      if (isAnlagenCsvColumnParamKey(trimmed)) keys.add(trimmed);
      if (isEbeneHierarchyHeader(trimmed)) keys.add(trimmed);
    }
    for (var level = 1; level <= 3; level++) {
      keys.addAll(allParamKeysForHierarchyLevel(level));
      keys.addAll(configuredHierarchyParamKeys(level));
    }
    final schemaKey = resolveSchemaItemParamKey();
    if (schemaKey != null && schemaKey.isNotEmpty) keys.add(schemaKey);
    final leafKey = leafNameParamKey;
    if (leafKey != null && leafKey.isNotEmpty) keys.add(leafKey);
    final leafLabel = resolveLeafLevelLabel().trim();
    if (leafLabel.isNotEmpty) keys.add(leafLabel);
    final rfKey = resolveListGroupingParamKeyForLevel(1);
    if (rfKey != null && rfKey.isNotEmpty) keys.add(rfKey);
    return keys;
  }

  factory CsvSettings.defaults() {
    // Erste drei Spalten = Ebene1 / Ebene2 / Ebene3 (Anlagen- & Vorlagen-CSV).
    return const CsvSettings(
      level1: HierarchyLevelConfig(enabled: true, nameColumn: 0),
      level2: HierarchyLevelConfig(enabled: true, nameColumn: 1),
      level3: HierarchyLevelConfig(
        enabled: true,
        nameColumn: 2,
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
    int? attributeStartColumn,
    int? attributeCount,
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
    int? listTitleInputFieldIndex,
    int? listSubtitleInputFieldIndex,
    bool clearAnlageBauteilSpalte = false,
    bool clearDisplayNameSpalte = false,
    bool clearAttributeRange = false,
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
      attributeStartColumn: clearAttributeRange
          ? null
          : (attributeStartColumn ?? this.attributeStartColumn),
      attributeCount:
          clearAttributeRange ? null : (attributeCount ?? this.attributeCount),
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
      listTitleInputFieldIndex:
          listTitleInputFieldIndex ?? this.listTitleInputFieldIndex,
      listSubtitleInputFieldIndex:
          listSubtitleInputFieldIndex ?? this.listSubtitleInputFieldIndex,
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
      'attributeStartColumn': attributeStartColumn,
      'attributeCount': attributeCount,
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
      'listTitleInputFieldIndex': listTitleInputFieldIndex,
      'listSubtitleInputFieldIndex': listSubtitleInputFieldIndex,
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
      attributeStartColumn: json['attributeStartColumn'] as int?,
      attributeCount: json['attributeCount'] as int?,
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
      listTitleInputFieldIndex: json['listTitleInputFieldIndex'] as int? ?? 1,
      listSubtitleInputFieldIndex: json['listSubtitleInputFieldIndex'] as int? ??
          ((json['listSubtitleParamKey'] as String?)?.trim().isNotEmpty == true
              ? 2
              : 0),
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
    } catch (e) {
      appLog('CsvSettings.loadForProject fehlgeschlagen', error: e);
    }
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
    } catch (e) {
      appLog('Legacy CSV-Settings Migration fehlgeschlagen', error: e);
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
    } catch (e) {
      appLog('CsvSettingsNotifier.load fehlgeschlagen', error: e);
    }
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

