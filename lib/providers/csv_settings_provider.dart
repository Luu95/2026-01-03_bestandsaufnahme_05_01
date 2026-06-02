// lib/providers/csv_settings_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/csv_hierarchy_level.dart';

/// Ein explizites Paar: eine Spalte für den Attributnamen, eine für den Attributwert.
class AttributeColumnPair {
  final int nameColumn;
  final int valueColumn;

  const AttributeColumnPair({
    required this.nameColumn,
    required this.valueColumn,
  });

  Map<String, dynamic> toJson() => {
        'nameColumn': nameColumn,
        'valueColumn': valueColumn,
      };

  factory AttributeColumnPair.fromJson(Map<String, dynamic> json) {
    return AttributeColumnPair(
      nameColumn: json['nameColumn'] as int? ?? 0,
      valueColumn: json['valueColumn'] as int? ?? 0,
    );
  }
}

/// Dreiergruppe für Gewerkevorlagen: Attributname, Typ und Optionen.
class AttributeTripletColumn {
  final int nameColumn;
  final int typeColumn;
  final int optionsColumn;

  const AttributeTripletColumn({
    required this.nameColumn,
    required this.typeColumn,
    required this.optionsColumn,
  });

  Map<String, dynamic> toJson() => {
        'nameColumn': nameColumn,
        'typeColumn': typeColumn,
        'optionsColumn': optionsColumn,
      };

  factory AttributeTripletColumn.fromJson(Map<String, dynamic> json) {
    return AttributeTripletColumn(
      nameColumn: json['nameColumn'] as int? ?? 0,
      typeColumn: json['typeColumn'] as int? ?? 0,
      optionsColumn: json['optionsColumn'] as int? ?? 0,
    );
  }
}

class CsvSettings {
  final HierarchyLevelConfig level1;
  final HierarchyLevelConfig level2;
  final HierarchyLevelConfig level3;
  final int? etageSpalte;
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
  final String? foto1SpalteLabel;
  final String? foto2SpalteLabel;
  final String? foto3SpalteLabel;
  final String? foto4SpalteLabel;
  final List<String> importHeaderRow;
  final String exportDelimiter;
  final String groupingEtageParamKey;
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
    this.etageSpalte,
    this.anlageBauteilSpalte,
    required this.delimiterMode,
    required this.anlageKuerzel,
    required this.bauteilKuerzel,
    required this.useDisciplineGrouping,
    required this.labelGewerk,
    required this.labelAnlage,
    required this.labelBauteil,
    this.attributeColumnPairs = const [],
    this.foto1SpalteLabel,
    this.foto2SpalteLabel,
    this.foto3SpalteLabel,
    this.foto4SpalteLabel,
    this.importHeaderRow = const [],
    this.exportDelimiter = ';',
    this.groupingEtageParamKey = '',
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

  String resolveEtageGroupingParamKey() {
    final override = groupingEtageParamKey.trim();
    if (override.isNotEmpty) return override;
    return _headerLabelAt(etageSpalte) ?? 'Etage';
  }

  /// Ob Ebene 1 bereits als Gewerk/Disziplin-Tab genutzt wird (keine Listen-Gruppierung nötig).
  bool get level1IsDiscipline => level1.enabled && useDisciplineGrouping;

  String resolveGewerkGroupingParamKey() {
    final override = groupingGewerkParamKey.trim();
    if (override.isNotEmpty) return override;
    if (level1.enabled) return _headerLabelAt(level1.nameColumn) ?? labelGewerk;
    return labelGewerk;
  }

  /// Gruppierungs-Key für den Listen-Header „Revisionsfeld“.
  /// Null, wenn Ebene 1 bereits die Disziplin ist (sonst doppeltes Gewerk/Revisionsobjekt).
  String? resolveRevisionsfeldListGroupingParamKey() {
    if (level1IsDiscipline) return null;
    return resolveGewerkGroupingParamKey();
  }

  /// Param-Key für Untergruppierung (mittlere Ebene), wenn mindestens 2 Ebenen aktiv.
  String? resolveAnlageGroupingParamKey() {
    final override = groupingAnlageParamKey.trim();
    if (override.isNotEmpty) return override;
    final levels = enabledLevelsOrdered;
    if (levels.length < 2) return null;
    // 3 Ebenen: mittlere Ebene (2); 2 Ebenen: untere Ebene (2) = Schema-/Listen-Untergruppe
    if (level2.enabled && levels.length >= 2) {
      return _headerLabelAt(level2.nameColumn);
    }
    if (levels.length == 2 && level1.enabled && level3.enabled) {
      if (level1IsDiscipline) return null;
      return _headerLabelAt(level1.nameColumn);
    }
    return null;
  }

  String? resolveNameParamKey() {
    final leaf = leafLevel;
    if (leaf == null) return null;
    return _headerLabelAt(leaf.nameColumn);
  }

  /// Param-Key, der in der Anlagenübersicht als Beschriftung der Ebene 3 genutzt wird.
  /// Priorität: expliziter Param-Key (Gewerkevorlage) → Anlagen-CSV-Spalte → Blatt-Spalte.
  String? resolveDisplayNameParamKey() {
    final explicit = displayNameParamKey.trim();
    if (explicit.isNotEmpty) return explicit;
    final fromDisplayColumn = _headerLabelAt(displayNameSpalte);
    if (fromDisplayColumn != null && fromDisplayColumn.isNotEmpty) {
      return fromDisplayColumn;
    }
    return resolveNameParamKey();
  }

  static bool paramKeysMatch(String a, String b) {
    final x = a.trim().toLowerCase();
    final y = b.trim().toLowerCase();
    if (x.isEmpty || y.isEmpty) return false;
    if (x == y) return true;
    return x.startsWith('${y}_') || y.startsWith('${x}_');
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
  String? displayNameValueFromParams(Map<String, dynamic> params) {
    final configured = resolveDisplayNameParamKey();
    if (configured != null && configured.isNotEmpty) {
      final fromConfigured = paramValueForKey(params, configured);
      if (fromConfigured != null && fromConfigured.isNotEmpty) {
        return fromConfigured;
      }
    }

    for (final candidate in const [
      'Name',
      'Anlagenbezeichnung',
      'Bezeichnung',
      'name',
    ]) {
      final v = paramValueForKey(params, candidate);
      if (v != null && v.isNotEmpty) return v;
    }

    final leafKey = resolveNameParamKey();
    if (leafKey != null && leafKey.isNotEmpty) {
      final fromLeaf = paramValueForKey(params, leafKey);
      if (fromLeaf != null && fromLeaf.isNotEmpty) return fromLeaf;
    }
    return null;
  }

  void writeDisplayNameToParams(Map<String, dynamic> params, String value) {
    final v = value.trim();
    if (v.isEmpty) return;

    final key = resolveDisplayNameParamKey()?.trim();
    if (key == null || key.isEmpty) return;

    params[key] = v;
    for (final entry in params.entries.toList()) {
      if (paramKeysMatch(entry.key.toString(), key)) {
        params[entry.key] = v;
      }
    }
  }

  /// Param-Key der Ebene, deren Wert das Attribut-Schema bestimmt (Unterebene des Gewerks).
  String? resolveSchemaItemParamKey() {
    final override = groupingAnlageParamKey.trim();
    if (override.isNotEmpty) return override;
    // Gewerk = Tab (Ebene 1): Schema kommt immer von Ebene 2 (Revisionsobjekt)
    if (level1IsDiscipline && level2.enabled) {
      return _headerLabelAt(level2.nameColumn) ?? labelAnlage;
    }
    // Schema liegt auf Revisionsobjekt (Ebene 2), nicht auf historischer Bauteil-Ebene 3.
    final fromRevisionsobjekt = resolveRevisionsobjektGroupingParamKey();
    if (fromRevisionsobjekt != null && fromRevisionsobjekt.isNotEmpty) {
      return fromRevisionsobjekt;
    }
    final fromGrouping = resolveAnlageGroupingParamKey();
    if (fromGrouping != null && fromGrouping.isNotEmpty) return fromGrouping;
    if (level2.enabled && enabledLevelsOrdered.length >= 2) {
      return _headerLabelAt(level2.nameColumn) ?? labelAnlage;
    }
    if (level3.enabled && level1.enabled && !level1IsDiscipline) {
      return _headerLabelAt(level3.nameColumn) ?? labelBauteil;
    }
    return _headerLabelAt(leafLevel?.nameColumn);
  }

  /// Param-Key für Untergruppierung (Revisionsobjekt-Gruppen in der Liste).
  String? resolveRevisionsobjektGroupingParamKey() {
    if (level1IsDiscipline && level2.enabled) {
      final override = groupingAnlageParamKey.trim();
      if (override.isNotEmpty) return override;
      return _headerLabelAt(level2.nameColumn) ?? labelAnlage;
    }
    return resolveAnlageGroupingParamKey();
  }

  /// Anzeige-Label der Schema-Unterebene (CSV-Mapping Ebene 2 oder 3).
  String resolveSchemaItemLevelLabel() {
    if (level2.enabled && enabledLevelsOrdered.length >= 2) {
      return _headerLabelAt(level2.nameColumn) ?? labelAnlage;
    }
    if (level3.enabled) {
      return _headerLabelAt(level3.nameColumn) ?? labelBauteil;
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

  /// Label für neue Datensätze unter einem Revisionsobjekt (Long-Press Ebene 2 → Plus).
  /// Nicht die Schema-Ebene (Ebene 2), sondern die darunter liegende Blatt-Ebene.
  String resolveDatensatzUnderRevisionsobjektLabel() {
    if (level3.enabled && enabledLevelsOrdered.length >= 3) {
      return _headerLabelAt(level3.nameColumn) ?? labelBauteil;
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

  /// Untergeordnete Zeilen mit parentId (historisch Ebene 3 / labelBauteil).
  bool get allowsParentChildRows =>
      level3.enabled && enabledLevelsOrdered.length >= 3;

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

  static const List<String> legacyEtageParamKeys = ['Etage'];

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

  String? etageValueFromParams(Map<String, dynamic> params) {
    final key = resolveEtageGroupingParamKey();
    final value = readParamValue(
      params,
      key,
      legacyKeys: [...legacyEtageParamKeys, '__etageName'],
    );
    return value;
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

  void writeEtageToParams(Map<String, dynamic> params, String value) {
    if (value.trim().isEmpty) return;
    params[resolveEtageGroupingParamKey()] = value;
    params['__etageName'] = value;
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

  /// Liest Revisionsfeld (Ebene 1) aus gespeicherten Parametern.
  String? revisionsfeldValueFromParams(Map<String, dynamic> params) {
    final key = resolveRevisionsfeldListGroupingParamKey();
    if (key == null || key.isEmpty) return null;
    return readParamValue(params, key);
  }

  /// Liest Revisionsobjekt (Ebene 2) aus gespeicherten Parametern.
  String? revisionsobjektValueFromParams(Map<String, dynamic> params) {
    final key = resolveRevisionsobjektParamKey();
    if (key == null || key.isEmpty) return null;
    return readParamValue(
      params,
      key,
      legacyKeys: legacySchemaItemParamKeys,
    );
  }

  /// Param-Key der Blatt-Ebene (Anlagenbezeichnung aus CSV) – darf nie mit RO überschrieben werden.
  String? get leafNameParamKey => resolveNameParamKey();

  bool isLeafNameParamKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return false;

    final display = resolveDisplayNameParamKey()?.trim();
    if (display != null && display.isNotEmpty && paramKeysMatch(k, display)) {
      return true;
    }

    final leaf = leafNameParamKey?.trim();
    if (leaf == null || leaf.isEmpty) return false;
    return paramKeysMatch(k, leaf);
  }

  /// Alle Param-Keys für Revisionsobjekt (Ebene 2), ohne Blatt-Namen-Spalte.
  List<String> allRevisionsobjektParamKeys() {
    final keys = <String>{};
    for (final k in <String?>[
      resolveRevisionsobjektParamKey(),
      resolveRevisionsobjektGroupingParamKey(),
      resolveSchemaItemParamKey(),
      resolveAnlageGroupingParamKey(),
    ]) {
      final t = k?.trim() ?? '';
      if (t.isNotEmpty && !isLeafNameParamKey(t)) keys.add(t);
    }
    for (final legacy in legacySchemaItemParamKeys) {
      if (!isLeafNameParamKey(legacy)) keys.add(legacy);
    }
    return keys.toList();
  }

  /// Alle Param-Keys für Revisionsfeld (nur wenn nicht schon Gewerk-Tab).
  List<String> allRevisionsfeldParamKeys() {
    final keys = <String>{};
    final listKey = resolveRevisionsfeldListGroupingParamKey();
    if (listKey != null && listKey.trim().isNotEmpty) {
      keys.add(listKey.trim());
    }
    return keys.toList();
  }

  /// Schreibt Listen-Hierarchie Ebene 1+2 in die Parameter eines Blatt-Datensatzes.
  /// Aktualisiert alle bekannten Alias-Keys (CSV-Header + Legacy), damit Eingabefelder
  /// und Listen-Gruppierung dieselben Werte zeigen.
  void writeHierarchyLocationToParams(
    Map<String, dynamic> params, {
    String? revisionsfeld,
    required String revisionsobjekt,
  }) {
    final ro = revisionsobjekt.trim();
    if (ro.isEmpty) return;

    for (final key in allRevisionsobjektParamKeys()) {
      params[key] = ro;
    }

    final rf = revisionsfeld?.trim() ?? '';
    if (rf.isNotEmpty) {
      for (final key in allRevisionsfeldParamKeys()) {
        params[key] = rf;
      }
    }

    // Explizite Ebene-Labels als feste, lesbare Parameter mitschreiben
    // (z. B. "Gewerk", "Anlage"), damit diese im Dialog als read-only angezeigt werden können.
    final level1Key = labelGewerk.trim();
    final level2Key = labelAnlage.trim();
    if (level2Key.isNotEmpty && !isLeafNameParamKey(level2Key)) {
      params[level2Key] = ro;
    }
    if (rf.isNotEmpty &&
        level1Key.isNotEmpty &&
        !isLeafNameParamKey(level1Key)) {
      params[level1Key] = rf;
    }
  }

  /// Neue Param-Werte für Verortung (z. B. beim Verschieben in andere Liste).
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
      ...legacyAnlageBauteilParamKeys,
    };
    keys.add(resolveEtageGroupingParamKey());
    final abKey = resolveAnlageBauteilParamKey();
    if (abKey != null && abKey.isNotEmpty) keys.add(abKey);
    final schemaKey = resolveSchemaItemParamKey();
    if (schemaKey != null && schemaKey.isNotEmpty) keys.add(schemaKey);
    final leafKey = leafNameParamKey;
    if (leafKey != null && leafKey.isNotEmpty) keys.add(leafKey);
    final rfKey = resolveRevisionsfeldListGroupingParamKey();
    if (rfKey != null && rfKey.isNotEmpty) keys.add(rfKey);
    return keys;
  }

  /// Erstes Token aus anlageKuerzel (z. B. „A“ aus „A,Anlage“).
  String defaultAnlageKuerzelToken() {
    final tokens = anlageKuerzel
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    return tokens.isNotEmpty ? tokens.first : 'A';
  }

  /// Erstes Token aus bauteilKuerzel (z. B. „B“ aus „B,Bauteil“).
  String defaultBauteilKuerzelToken() {
    final tokens = bauteilKuerzel
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    return tokens.isNotEmpty ? tokens.first : 'B';
  }

  // --- Legacy-Getter ---
  int get gewerkSpalte => level1.nameColumn;
  int get nameSpalte => leafLevel?.nameColumn ?? 1;
  int get lfdNummerSpalte => leafLevel?.idColumn ?? 0;
  int? get anlageEbeneSpalte =>
      level2.enabled && enabledLevelsOrdered.length >= 2 ? level2.nameColumn : null;

  factory CsvSettings.defaults() {
    return const CsvSettings(
      level1: HierarchyLevelConfig(enabled: true, nameColumn: 2),
      level2: HierarchyLevelConfig(enabled: false, nameColumn: 1),
      level3: HierarchyLevelConfig(
        enabled: true,
        nameColumn: 1,
        useIdColumn: false,
      ),
      etageSpalte: null,
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
    int? etageSpalte,
    int? anlageBauteilSpalte,
    String? delimiterMode,
    String? anlageKuerzel,
    String? bauteilKuerzel,
    bool? useDisciplineGrouping,
    String? labelGewerk,
    String? labelAnlage,
    String? labelBauteil,
    List<AttributeColumnPair>? attributeColumnPairs,
    String? foto1SpalteLabel,
    String? foto2SpalteLabel,
    String? foto3SpalteLabel,
    String? foto4SpalteLabel,
    List<String>? importHeaderRow,
    String? exportDelimiter,
    String? groupingEtageParamKey,
    String? groupingGewerkParamKey,
    String? groupingAnlageParamKey,
    String? displayNameParamKey,
    int? displayNameSpalte,
    bool clearEtageSpalte = false,
    bool clearAnlageBauteilSpalte = false,
    bool clearDisplayNameSpalte = false,
  }) {
    return CsvSettings(
      level1: level1 ?? this.level1,
      level2: level2 ?? this.level2,
      level3: level3 ?? this.level3,
      etageSpalte: clearEtageSpalte ? null : (etageSpalte ?? this.etageSpalte),
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
      foto1SpalteLabel: foto1SpalteLabel ?? this.foto1SpalteLabel,
      foto2SpalteLabel: foto2SpalteLabel ?? this.foto2SpalteLabel,
      foto3SpalteLabel: foto3SpalteLabel ?? this.foto3SpalteLabel,
      foto4SpalteLabel: foto4SpalteLabel ?? this.foto4SpalteLabel,
      importHeaderRow: importHeaderRow ?? this.importHeaderRow,
      exportDelimiter: exportDelimiter ?? this.exportDelimiter,
      groupingEtageParamKey: groupingEtageParamKey ?? this.groupingEtageParamKey,
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
      'etageSpalte': etageSpalte,
      'anlageBauteilSpalte': anlageBauteilSpalte,
      'delimiterMode': delimiterMode,
      'anlageKuerzel': anlageKuerzel,
      'bauteilKuerzel': bauteilKuerzel,
      'useDisciplineGrouping': useDisciplineGrouping,
      'labelGewerk': labelGewerk,
      'labelAnlage': labelAnlage,
      'labelBauteil': labelBauteil,
      'attributeColumnPairs': attributeColumnPairs.map((p) => p.toJson()).toList(),
      'foto1SpalteLabel': foto1SpalteLabel,
      'foto2SpalteLabel': foto2SpalteLabel,
      'foto3SpalteLabel': foto3SpalteLabel,
      'foto4SpalteLabel': foto4SpalteLabel,
      'importHeaderRow': importHeaderRow,
      'exportDelimiter': exportDelimiter,
      'groupingEtageParamKey': groupingEtageParamKey,
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
      etageSpalte: json['etageSpalte'] as int?,
      anlageBauteilSpalte: json['anlageBauteilSpalte'] as int?,
      delimiterMode: json['delimiterMode'] as String? ?? 'auto',
      anlageKuerzel: json['anlageKuerzel'] as String? ?? 'A,Anlage',
      bauteilKuerzel: json['bauteilKuerzel'] as String? ?? 'B,Bauteil',
      useDisciplineGrouping: json['useDisciplineGrouping'] as bool? ?? true,
      labelGewerk: json['labelGewerk'] as String? ?? 'Gewerk',
      labelAnlage: json['labelAnlage'] as String? ?? 'Anlage',
      labelBauteil: json['labelBauteil'] as String? ?? 'Bauteil',
      attributeColumnPairs: pairs,
      foto1SpalteLabel: json['foto1SpalteLabel'] as String?,
      foto2SpalteLabel: json['foto2SpalteLabel'] as String?,
      foto3SpalteLabel: json['foto3SpalteLabel'] as String?,
      foto4SpalteLabel: json['foto4SpalteLabel'] as String?,
      importHeaderRow: _parseStringList(json['importHeaderRow']),
      exportDelimiter: json['exportDelimiter'] as String? ?? ';',
      groupingEtageParamKey: json['groupingEtageParamKey'] as String? ?? '',
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
      if (raw != null && raw.trim().isNotEmpty) {
        return CsvSettings.fromJson(
          Map<String, dynamic>.from(json.decode(raw) as Map),
        );
      }
    } catch (_) {}
    return CsvSettings.defaults();
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
      ),
    );
  }
}

final csvSettingsProvider =
    StateNotifierProviderFamily<CsvSettingsNotifier, CsvSettings, String>(
  (ref, projectId) => CsvSettingsNotifier(projectId),
);

