/// Schema-Item-Labels, Legacy-Migration und reservierte Dialog-Param-Keys.
///
/// Extension auf [CsvSettings] (`part of` derselben Library). Statische API
/// bleibt auf der Klasse; private Helfer sind library-privat.

part of '../csv_settings.dart';

// --- Abschnitt: Schema-Item ---

/// Labels und Param-Keys rund um Schema-Ebene, Blatt und Legacy-Keys.
extension CsvSettingsSchemaItemLabels on CsvSettings {
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
  /// Anzeige-Label der Disziplin-Ebene (Gewerk).
  String get schemaDisciplineLevelLabel => labelGewerk;

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
  /// Wert der Schema-Ebene aus Params (inkl. Legacy-Keys).
  String? schemaItemValueFromParams(Map<String, dynamic> params) {
    final key = resolveSchemaItemParamKey();
    if (key != null && key.trim().isNotEmpty) {
      final value = readParamValue(
        params,
        key,
        legacyKeys: CsvSettings.legacySchemaItemParamKeys,
      );
      if (value != null) return value;
    }
    for (final legacyKey in CsvSettings.legacySchemaItemParamKeys) {
      final value = params[legacyKey]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  /// Kopiert Legacy-Keys (Revisionsobjekt/Anlagentyp/…) auf den konfigurierten
  /// Schema-Item-Key und entfernt die Legacy-Einträge. Idempotent.
  ///
  /// Aufruf: Dialog öffnen / Import-Cleanup – danach reichen Level-Keys.
  void migrateLegacySchemaItemKeys(Map<String, dynamic> params) {
    final target = resolveSchemaItemParamKey()?.trim() ?? '';
    if (target.isEmpty) return;

    final existing = params[target]?.toString().trim() ?? '';
    String? legacyValue;
    for (final legacyKey in CsvSettings.legacySchemaItemParamKeys) {
      if (CsvSettings.paramKeysMatch(legacyKey, target)) continue;
      final v = params[legacyKey]?.toString().trim() ?? '';
      if (v.isEmpty) continue;
      legacyValue ??= v;
    }
    if (existing.isEmpty && legacyValue != null && legacyValue.isNotEmpty) {
      if (!isLeafNameParamKey(target)) {
        params[target] = legacyValue;
      }
    }
    for (final legacyKey in CsvSettings.legacySchemaItemParamKeys) {
      if (CsvSettings.paramKeysMatch(legacyKey, target)) continue;
      params.remove(legacyKey);
    }
  }

  /// Schreibt den Schema-Item-Wert; überspringt Blatt-Namens-Keys.
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

  /// True, wenn [key] der Blatt-/Anzeigename-Key ist (kein Hierarchie-Key).
  bool isLeafNameParamKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return false;

    // Obere Hierarchie-Keys sind nie Blatt-/Anzeigename (raw, ohne Rekursion).
    if (CsvSettings.isEbeneHierarchyHeader(k)) return false;
    for (var level = 1; level <= 2; level++) {
      for (final hk in _rawParamKeysForHierarchyLevel(level)) {
        if (CsvSettings.paramKeysMatch(k, hk)) return false;
      }
    }

    // Kein resolveDisplayNameParamKey hier: das prüft mustNotReceiveDisplayName /
    // isUpperHierarchyParamKey und würde über allParamKeysForHierarchyLevel
    // wieder isLeafNameParamKey aufrufen (StackOverflow).
    final explicit = displayNameParamKey.trim();
    if (explicit.isNotEmpty && CsvSettings.paramKeysMatch(k, explicit)) {
      return true;
    }

    final fromDisplayColumn = _headerLabelAt(displayNameSpalte)?.trim();
    if (fromDisplayColumn != null &&
        fromDisplayColumn.isNotEmpty &&
        !CsvSettings.isEbeneHierarchyHeader(fromDisplayColumn) &&
        CsvSettings.paramKeysMatch(k, fromDisplayColumn)) {
      return true;
    }

    final leaf = leafNameParamKey?.trim();
    if (leaf != null &&
        leaf.isNotEmpty &&
        !CsvSettings.isEbeneHierarchyHeader(leaf) &&
        CsvSettings.paramKeysMatch(k, leaf)) {
      return true;
    }

    final hasConfiguredName = explicit.isNotEmpty ||
        (fromDisplayColumn != null && fromDisplayColumn.isNotEmpty) ||
        (leaf != null && leaf.isNotEmpty);
    if (!hasConfiguredName && CsvSettings.paramKeysMatch(k, 'Bezeichnung')) {
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
      CsvSettings.qrCodeNummerParamKey,
      '__etageName',
      CsvSettings.listNamePlaceholderParamKey,
      CsvSettings.listTitleParamKey,
      labelBauteil,
    };
    for (final h in importHeaderRow) {
      final trimmed = h.trim();
      if (trimmed.isEmpty) continue;
      if (CsvSettings.isAnlagenCsvColumnParamKey(trimmed)) keys.add(trimmed);
      if (CsvSettings.isEbeneHierarchyHeader(trimmed)) keys.add(trimmed);
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
}
