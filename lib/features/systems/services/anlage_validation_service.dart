/// Validierung und Feld-Bestätigungsstatus von Anlagen (Listen-Haken, Dialog-Meta).
/// Entscheidet anhand Schema und `_field_*_validated` / `_field_*_missing`-Flags.

import 'package:bestandsaufnahme_01/features/systems/models/anlage.dart';
import 'package:bestandsaufnahme_01/features/csv/providers/csv_settings_provider.dart';

/// Service zur Validierung von Anlagen und einzelner Schema-Felder.
class AnlageValidationService {
  /// Prüft, ob eine Anlage vollständig ausgefüllt und validiert ist.
  ///
  /// Entspricht dem Anlagendialog: jedes sichtbare Feld muss entweder
  /// einen grünen Haken (`_field_*_validated`) oder den grauen „fehlt“-Status
  /// (`_field_*_missing`) haben.
  ///
  /// Frisch importierte Anlagen ohne diese Meta-Flags gelten nie als fertig –
  /// auch dann nicht, wenn Werte aus der CSV schon befüllt sind (grauer Haken
  /// im Dialog = noch nicht bestätigt).
  static bool isAnlageValidated(
    Anlage anlage, {
    CsvSettings? csvSettings,
  }) {
    if (anlage.name.trim().isEmpty) {
      return false;
    }

    // Ohne jede Nutzer-Bestätigung kein Listen-Haken (Import-Fall).
    if (!hasAnyFieldConfirmationMeta(anlage)) {
      return false;
    }

    final schema = schemaFieldsForValidation(anlage, csvSettings: csvSettings);
    if (schema.isEmpty) {
      return false;
    }

    var examined = 0;
    for (final fieldDef in schema) {
      final key = fieldDef['key']?.toString();
      if (key == null || key.isEmpty) continue;
      examined++;

      if (isFieldMarkedAsMissing(anlage, key)) {
        continue;
      }

      final label = fieldDef['label']?.toString();
      final value = _fieldValue(anlage, key, label, csvSettings);

      if (value == null ||
          value.toString().trim().isEmpty ||
          value.toString().trim() == 'null') {
        return false;
      }

      // Grauer Haken im Dialog = Wert da, aber nicht bestätigt → nicht fertig
      if (!isFieldValidated(anlage, key)) {
        return false;
      }
    }

    // Schema-Einträge ohne Keys dürfen keinen Haken erzeugen
    return examined > 0;
  }

  /// True, wenn mindestens ein Feld explizit bestätigt oder als fehlend markiert wurde.
  static bool hasAnyFieldConfirmationMeta(Anlage anlage) {
    for (final entry in anlage.params.entries) {
      final k = entry.key.toString();
      if (!k.startsWith('_field_')) continue;
      if (!k.endsWith('_validated') && !k.endsWith('_missing')) continue;
      if (entry.value == true) return true;
    }
    return false;
  }

  /// Entfernt alle Feld-Validierungs-/Missing-Flags (z. B. nach CSV-Import).
  static void stripFieldConfirmationMeta(Map<String, dynamic> params) {
    final keys = params.keys
        .map((k) => k.toString())
        .where(
          (k) =>
              k.startsWith('_field_') &&
              (k.endsWith('_validated') || k.endsWith('_missing')),
        )
        .toList();
    for (final k in keys) {
      params.remove(k);
    }
    params.remove('_validated');
    params.remove('_validatedAt');
  }

  /// Schema-Felder wie im Anlagendialog (RO-effektiv, gefiltert).
  static List<Map<String, dynamic>> schemaFieldsForValidation(
    Anlage anlage, {
    CsvSettings? csvSettings,
  }) {
    final ro = _resolveRevisionsobjekt(anlage, csvSettings);
    final discipline = anlage.discipline;

    List<Map<String, dynamic>> fields;
    if (ro != null && ro.isNotEmpty) {
      fields = discipline.effectiveSchemaFor(revisionsobjekt: ro);
      final nonGlobal = fields.where((f) => f['isGlobal'] != true).toList();
      if (nonGlobal.isEmpty) {
        final legacy = discipline.legacyIndividualSchemaFields;
        if (legacy.isNotEmpty) {
          fields = [...discipline.globalSchemaFields, ...legacy];
        }
      }
    } else {
      fields = List<Map<String, dynamic>>.from(discipline.schema);
    }

    fields = CsvSettings.filterSchemaFieldsForDialog(fields);

    if (csvSettings != null) {
      fields = fields.where((f) {
        final key = (f['key'] ?? '').toString();
        if (key.isEmpty) return true;
        return !csvSettings.isHierarchyParamKey(key) &&
            !csvSettings.isLeafNameParamKey(key);
      }).toList();
    }

    // Import: Felder nur in Params, noch nicht im Disziplin-Schema
    if (fields.where((f) => f['isGlobal'] != true).isEmpty) {
      final fromParams = CsvSettings.schemaFieldsFromParams(
        anlage.params,
        settings: csvSettings,
      );
      if (fromParams.isNotEmpty) {
        fields = CsvSettings.filterSchemaFieldsForDialog([
          ...discipline.globalSchemaFields,
          ...fromParams,
        ]);
        if (csvSettings != null) {
          fields = fields.where((f) {
            final key = (f['key'] ?? '').toString();
            if (key.isEmpty) return true;
            return !csvSettings.isHierarchyParamKey(key) &&
                !csvSettings.isLeafNameParamKey(key);
          }).toList();
        }
      }
    }

    return fields;
  }

  /// Ermittelt das Revisionsobjekt aus CSV-Settings, Legacy-Keys oder einzigem RO.
  static String? _resolveRevisionsobjekt(
    Anlage anlage,
    CsvSettings? csvSettings,
  ) {
    if (csvSettings != null) {
      final fromSettings =
          csvSettings.schemaItemValueFromParams(anlage.params)?.trim() ??
              csvSettings.revisionsobjektValueFromParams(anlage.params)?.trim();
      if (fromSettings != null && fromSettings.isNotEmpty) {
        return fromSettings;
      }
    }

    for (final legacyKey in CsvSettings.legacySchemaItemParamKeys) {
      final value = anlage.params[legacyKey]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    final roKeys = anlage.discipline.revisionsobjektSchemas.keys.toList();
    if (roKeys.length == 1) return roKeys.first;

    return null;
  }

  /// Liest den Feldwert über CSV-Key-Aliase bzw. direkten Param-Zugriff.
  static dynamic _fieldValue(
    Anlage anlage,
    String key,
    String? label,
    CsvSettings? csvSettings,
  ) {
    if (csvSettings != null) {
      final fromKey = csvSettings.paramValueForKey(anlage.params, key);
      if (fromKey != null && fromKey.trim().isNotEmpty) return fromKey;
      final labelTrim = label?.trim() ?? '';
      if (labelTrim.isNotEmpty) {
        final fromLabel =
            csvSettings.paramValueForKey(anlage.params, labelTrim);
        if (fromLabel != null && fromLabel.trim().isNotEmpty) return fromLabel;
      }
    }

    if (anlage.params.containsKey(key)) {
      return anlage.params[key];
    }
    return null;
  }

  /// Setzt den Validierungsstatus einer Anlage (aktuell ohne zusätzliche Params).
  static Anlage setValidatedStatus(Anlage anlage, bool validated) {
    final updatedParams = Map<String, dynamic>.from(anlage.params);

    return Anlage(
      id: anlage.id,
      parentId: anlage.parentId,
      name: anlage.name,
      params: updatedParams,
      floorId: anlage.floorId,
      buildingId: anlage.buildingId,
      isMarker: anlage.isMarker,
      markerInfo: anlage.markerInfo,
      markerType: anlage.markerType,
      discipline: anlage.discipline,
    );
  }

  /// Liest den gespeicherten Validierungsstatus (prüft auch automatisch)
  static bool getValidatedStatus(
    Anlage anlage, {
    CsvSettings? csvSettings,
  }) {
    return isAnlageValidated(anlage, csvSettings: csvSettings);
  }

  /// Zählt fehlende / unbestätigte Felder (ignoriert als fehlend markierte Felder)
  static int getMissingFieldsCount(
    Anlage anlage, {
    CsvSettings? csvSettings,
  }) {
    final schema = schemaFieldsForValidation(anlage, csvSettings: csvSettings);

    if (anlage.name.trim().isEmpty) {
      return schema.length + 1;
    }

    int missing = 0;
    for (final fieldDef in schema) {
      final key = fieldDef['key']?.toString();
      if (key == null || key.isEmpty) continue;

      if (isFieldMarkedAsMissing(anlage, key)) {
        continue;
      }

      final label = fieldDef['label']?.toString();
      final value = _fieldValue(anlage, key, label, csvSettings);
      if (value == null ||
          value.toString().trim().isEmpty ||
          value.toString().trim() == 'null') {
        missing++;
      } else if (!isFieldValidated(anlage, key)) {
        missing++;
      }
    }

    return missing;
  }

  /// Prüft, ob ein Feld als validiert markiert ist
  static bool isFieldValidated(Anlage anlage, String fieldKey) {
    return anlage.params['_field_${fieldKey}_validated'] == true;
  }

  /// Prüft, ob ein Feld als fehlend markiert ist
  static bool isFieldMarkedAsMissing(Anlage anlage, String fieldKey) {
    return anlage.params['_field_${fieldKey}_missing'] == true;
  }

  /// Setzt den Validierungsstatus eines einzelnen Feldes
  static Anlage setFieldValidated(Anlage anlage, String fieldKey, bool validated) {
    final updatedParams = Map<String, dynamic>.from(anlage.params);
    updatedParams['_field_${fieldKey}_validated'] = validated;
    if (!validated) {
      updatedParams.remove('_field_${fieldKey}_missing');
    }

    return Anlage(
      id: anlage.id,
      parentId: anlage.parentId,
      name: anlage.name,
      params: updatedParams,
      floorId: anlage.floorId,
      buildingId: anlage.buildingId,
      isMarker: anlage.isMarker,
      markerInfo: anlage.markerInfo,
      markerType: anlage.markerType,
      discipline: anlage.discipline,
    );
  }

  /// Markiert ein Feld als fehlend (fällt aus Bewertung heraus)
  static Anlage setFieldAsMissing(Anlage anlage, String fieldKey, bool missing) {
    final updatedParams = Map<String, dynamic>.from(anlage.params);
    updatedParams['_field_${fieldKey}_missing'] = missing;
    if (missing) {
      updatedParams.remove('_field_${fieldKey}_validated');
    }

    return Anlage(
      id: anlage.id,
      parentId: anlage.parentId,
      name: anlage.name,
      params: updatedParams,
      floorId: anlage.floorId,
      buildingId: anlage.buildingId,
      isMarker: anlage.isMarker,
      markerInfo: anlage.markerInfo,
      markerType: anlage.markerType,
      discipline: anlage.discipline,
    );
  }

  /// Prüft, ob eine Anlage fehlende Parameter hat (Felder die als fehlend markiert sind)
  static bool hasMissingParameters(Anlage anlage, {CsvSettings? csvSettings}) {
    final schema = schemaFieldsForValidation(anlage, csvSettings: csvSettings);
    for (final fieldDef in schema) {
      final key = fieldDef['key']?.toString();
      if (key == null || key.isEmpty) continue;
      if (isFieldMarkedAsMissing(anlage, key)) {
        return true;
      }
    }
    return false;
  }

  /// Zählt die Anzahl der als fehlend markierten Felder
  static int getMissingParametersCount(
    Anlage anlage, {
    CsvSettings? csvSettings,
  }) {
    int count = 0;
    final schema = schemaFieldsForValidation(anlage, csvSettings: csvSettings);
    for (final fieldDef in schema) {
      final key = fieldDef['key']?.toString();
      if (key == null || key.isEmpty) continue;
      if (isFieldMarkedAsMissing(anlage, key)) {
        count++;
      }
    }
    return count;
  }
}
