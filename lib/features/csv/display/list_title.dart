/// Listen-Titel und -Untertitel aus Eingabefeld-Index bzw. gespeicherten Params.
///
/// Extension auf [CsvSettings] (`part of` derselben Library). Statische API
/// bleibt auf der Klasse; private Helfer sind library-privat.

part of '../csv_settings.dart';

// --- Abschnitt: Listen-Titel ---

/// Ableitung und Schreiben von Listen-Titel, Untertitel und Legacy-Anzeigename.
extension CsvSettingsListTitle on CsvSettings {
  /// Liest einen Param-Wert inkl. case-insensitive Key und Schema-Key mit UUID-Suffix.
  String? paramValueForKey(Map<String, dynamic> params, String desiredKey) {
    final trimmed = desiredKey.trim();
    if (trimmed.isEmpty) return null;

    final direct = readParamValue(params, trimmed);
    if (direct != null && direct.isNotEmpty) return direct;

    for (final entry in params.entries) {
      final key = entry.key.toString().trim();
      if (!CsvSettings.paramKeysMatch(key, trimmed)) continue;
      final value = entry.value?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  /// Eingabefelder in Dialogreihenfolge (ohne Hierarchie-/Blatt-Spalten).
  List<Map<String, dynamic>> listInputFieldsFromSchema(
    List<Map<String, dynamic>> schemaFields,
  ) {
    final filtered = CsvSettings.filterSchemaFieldsForDialog(schemaFields);
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    final leaf = leafNameParamKey?.trim() ?? '';
    for (final field in filtered) {
      final key = (field['key'] ?? '').toString().trim();
      if (key.isEmpty) continue;
      if (CsvSettings.isAnlagenCsvColumnParamKey(key)) continue;
      if (CsvSettings.isEbeneHierarchyHeader(key)) continue;
      if (isUpperHierarchyParamKey(key)) continue;
      if (isHierarchyParamKey(key)) continue;
      // CSV-Blattspalte ausblenden (wie im Dialog), Anzeige-Param „Name“ bleibt.
      if (leaf.isNotEmpty && CsvSettings.paramKeysMatch(key, leaf)) continue;
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
        final slot = CsvSettings.attSlotFromSchemaField(field);
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
      if (!CsvSettings.isAttSlotParamKey(k)) continue;
      final slot = int.tryParse(entry.value?.toString() ?? '');
      if (slot != fieldIndex1Based) continue;
      final paramKey = k.substring(CsvSettings.attSlotParamKeyPrefix.length);
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
        if (CsvSettings.isAnlagenCsvColumnParamKey(key)) continue;
        if (CsvSettings.isEbeneHierarchyHeader(key)) continue;
        if (isUpperHierarchyParamKey(key)) continue;
        if (isHierarchyParamKey(key)) continue;
        if (leaf.isNotEmpty && CsvSettings.paramKeysMatch(key, leaf)) continue;
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
    final stored = params[CsvSettings.listTitleParamKey]?.toString().trim() ?? '';
    if (stored.isNotEmpty && stored != CsvSettings.unknownAnlageListLabel) {
      return stored;
    }

    final v = valueAtListInputFieldIndex(
      params,
      fieldIndex1Based:
          listTitleInputFieldIndex < 1 ? 1 : listTitleInputFieldIndex,
      schemaFields: schemaFields,
    );
    if (v != null && v.isNotEmpty) return v;
    return CsvSettings.unknownAnlageListLabel;
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
        if (!CsvSettings.paramKeysMatch(fieldKey, key) &&
            !CsvSettings.paramKeysMatch(fieldLabel, key)) {
          continue;
        }
        final fromField = paramValueForKey(params, fieldKey);
        if (usable(fromField)) return fromField;
      }
    }
    return null;
  }

  /// Schreibt den Anzeigenamen auf den aufgelösten Param-Key (inkl. Aliase).
  void writeDisplayNameToParams(Map<String, dynamic> params, String value) {
    final v = value.trim();
    if (v.isEmpty || isNonDistinctDisplayValue(v, params)) return;

    final key = resolveDisplayNameParamKey()?.trim();
    if (key == null || key.isEmpty) return;
    if (mustNotReceiveDisplayName(key)) return;

    params[key] = v;
    for (final entry in params.entries.toList()) {
      final paramKey = entry.key.toString();
      if (!CsvSettings.paramKeysMatch(paramKey, key)) continue;
      if (mustNotReceiveDisplayName(paramKey)) continue;
      params[paramKey] = v;
    }
  }

  /// Entfernt nur echte Platzhalter-Labels (z. B. „Eintrag“, Ebenen-Label)
  /// aus dem Legacy-Titel-Param – nicht Nutzerwerte, die zufällig dem
  /// Revisionsobjekt gleichen (sonst wird Eingabefeld 1 beim Speichern geleert).
  void clearPlaceholderDisplayNameFromParams(Map<String, dynamic> params) {
    final key = resolveDisplayNameParamKey()?.trim();
    if (key == null || key.isEmpty) return;
    for (final entry in params.entries.toList()) {
      final paramKey = entry.key.toString();
      if (!CsvSettings.paramKeysMatch(paramKey, key) && paramKey != key) continue;
      if (isPlaceholderDisplayValue(entry.value?.toString())) {
        params[paramKey] = '';
      }
    }
  }

  /// Schreibt [CsvSettings.listTitleParamKey] zurück in Eingabefeld N, falls dieses leer ist.
  /// Repariert Daten, bei denen der Listen-Titel gespeichert, das Feld aber geleert wurde.
  void restoreListTitleIntoInputField(
    Map<String, dynamic> params, {
    List<Map<String, dynamic>> schemaFields = const [],
  }) {
    final stored = params[CsvSettings.listTitleParamKey]?.toString().trim() ?? '';
    if (stored.isEmpty || stored == CsvSettings.unknownAnlageListLabel) return;

    final index =
        listTitleInputFieldIndex < 1 ? 1 : listTitleInputFieldIndex;
    final current = valueAtListInputFieldIndex(
      params,
      fieldIndex1Based: index,
      schemaFields: schemaFields,
    );
    if (current != null && current.isNotEmpty) return;

    String? targetKey;
    final fields = listInputFieldsFromSchema(schemaFields);
    if (fields.isNotEmpty) {
      for (final field in fields) {
        final slot = CsvSettings.attSlotFromSchemaField(field);
        if (slot != index) continue;
        final key = (field['key'] ?? '').toString().trim();
        if (key.isNotEmpty) {
          targetKey = key;
          break;
        }
      }
      if ((targetKey == null || targetKey.isEmpty) &&
          index <= fields.length) {
        final key = (fields[index - 1]['key'] ?? '').toString().trim();
        if (key.isNotEmpty) targetKey = key;
      }
    }
    if (targetKey == null || targetKey.isEmpty) {
      for (final entry in params.entries) {
        final k = entry.key.toString();
        if (!CsvSettings.isAttSlotParamKey(k)) continue;
        final slot = int.tryParse(entry.value?.toString() ?? '');
        if (slot != index) continue;
        targetKey = k.substring(CsvSettings.attSlotParamKeyPrefix.length);
        break;
      }
    }
    if (targetKey == null || targetKey.isEmpty) return;
    params[targetKey] = stored;
  }
}
