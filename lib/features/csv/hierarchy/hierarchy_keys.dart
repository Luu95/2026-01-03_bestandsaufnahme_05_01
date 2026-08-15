/// Hierarchie-Keys, Ebenen-Labels und reservierte Import-/Export-Spalten.
///
/// Extension auf [CsvSettings] (`part of` derselben Library). Statische API
/// bleibt auf der Klasse; private Helfer sind library-privat.

part of '../csv_settings.dart';

// --- Abschnitt: Hierarchie ---

/// Lesen/Schreiben von Hierarchie-Ebenen und zugehörigen Param-Keys.
extension CsvSettingsHierarchy on CsvSettings {
  /// Aktive Ebenen in Reihenfolge Ebene 1 → 2 → 3.
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
      if (CsvSettings.paramKeysMatch(existing, c)) return;
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
        for (final legacy in CsvSettings.legacySchemaItemParamKeys) {
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
        ? [...legacyKeys, ...CsvSettings.legacySchemaItemParamKeys]
        : legacyKeys;
    return readParamValue(params, key, legacyKeys: legacy);
  }
  /// Schreibt [value] auf alle Param-Keys der Hierarchie-Ebene [level].
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
        if (CsvSettings.paramKeysMatch(k, hk)) return true;
      }
    }
    final schemaKey = resolveSchemaItemParamKey()?.trim();
    if (schemaKey != null &&
        schemaKey.isNotEmpty &&
        CsvSettings.paramKeysMatch(k, schemaKey)) {
      return true;
    }
    return false;
  }
  /// Reservierter Param-Key für den Dialog (case-insensitive + Prefix-Aliase).
  bool matchesReservedDialogParamKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return true;
    for (final reserved in reservedParamKeysForDialog()) {
      if (CsvSettings.paramKeysMatch(k, reserved)) return true;
    }
    return false;
  }
  /// Spaltenindex für [label] in [headers] (exakter Header-Abgleich), sonst -1.
  int columnIndexForLabel(List<String> headers, String? label) {
    final t = label?.trim() ?? '';
    if (t.isEmpty) return -1;
    for (var i = 0; i < headers.length; i++) {
      if (CsvSettings.paramKeysMatch(headers[i], t)) return i;
    }
    return -1;
  }
  /// True, wenn eine QR-Code-Spalte für den Export konfiguriert ist.
  bool get hasQrCodeExportColumn =>
      (qrCodeNummerSpalteLabel?.trim().isNotEmpty ?? false);
  /// Param-Keys, die nicht als Attribut-Spalten exportiert werden.
  Set<String> reservedParamKeysForExport() {
    return {
      ...reservedParamKeysForDialog(),
      'lfdNummer',
      'photoPaths',
      CsvSettings.qrCodeNummerParamKey,
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
        if (CsvSettings.paramKeysMatch(headers[i], label)) return i;
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
  /// Synthetische Laufnummer für Importzeilen ohne ID-Spalte.
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
  /// Platzhalter-Laufnummer beim Export (vierstellig, z. B. `ID_0001`).
  String exportPlaceholderLfd(int sequentialNumber) =>
      '${syntheticIdPrefix()}_${sequentialNumber.toString().padLeft(4, '0')}';
  /// Ob Ebene 1 bereits als Gewerk/Disziplin-Tab genutzt wird (keine Listen-Gruppierung nötig).
  bool get level1IsDiscipline => level1.enabled && useDisciplineGrouping;
  /// Param-Key für die Gewerk-/Disziplin-Gruppierung (Override oder Header/Label).
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
  /// Header-Label der Blatt-Namensspalte (unterste aktive Ebene).
  String? resolveNameParamKey() {
    final leaf = leafLevel;
    if (leaf == null) return null;
    return _headerLabelAt(leaf.nameColumn);
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
        if (CsvSettings.paramKeysMatch(k, hk)) return true;
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
      if (headerLabel.isNotEmpty && CsvSettings.paramKeysMatch(k, headerLabel)) {
        return true;
      }
      for (final hk in allParamKeysForHierarchyLevel(level)) {
        if (CsvSettings.paramKeysMatch(k, hk)) return true;
      }
    }
    final schemaKey = resolveSchemaItemParamKey()?.trim();
    if (schemaKey != null &&
        schemaKey.isNotEmpty &&
        CsvSettings.paramKeysMatch(k, schemaKey)) {
      return true;
    }
    return false;
  }
}
