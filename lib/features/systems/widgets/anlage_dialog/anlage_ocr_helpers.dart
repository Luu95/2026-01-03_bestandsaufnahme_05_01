/// OCR-Helfer für den Anlagen-Dialog (Normalisieren, Feld-Match, Werte).
///
/// Reine Logik; UI und setState bleiben in [GenericAnlageDialog].

import 'package:bestandsaufnahme_01/features/systems/models/anlage.dart';
import 'package:bestandsaufnahme_01/features/systems/services/anlage_validation_service.dart';

/// Normalisiert einen String für OCR-Vergleiche:
/// Kleinbuchstaben + alle Leerzeichen entfernen.
String normalizeOcrCompareKey(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'\s+'), '');

/// Prüft, ob OCR-Ergebnisse sinnvoll für ein Typenschild aussehen.
///
/// Gleicher Check wie früher in `_performOcr`: leer oder weder Hersteller noch Baujahr.
bool ocrResultsLookUseful(Map<String, String> results) {
  if (results.isEmpty) return false;
  if (results['hersteller'] == null && results['baujahr'] == null) {
    return false;
  }
  return true;
}

/// Sucht im Schema das Feld, das zu einem OCR-Key passt.
///
/// Reihenfolge:
/// 1. Exakter Key-Match
/// 2. Label gleich (normalisiert)
/// 3. Schema-Key beginnt mit `ocrKey_` (z.B. UUID-Endung)
/// 4. Schema-Key enthält den OCR-Key
Map<String, dynamic>? findSchemaFieldForOcrKey(
  List<Map<String, dynamic>> schema,
  String ocrKey,
) {
  // 1. Exakter Key
  for (final f in schema) {
    if (f['key'] == ocrKey) return f;
  }

  final normalizedOcrKey = normalizeOcrCompareKey(ocrKey);

  // 2–4. Label / Präfix / enthält
  for (final f in schema) {
    final schemaKey = (f['key'] ?? '').toString();
    final schemaLabel = (f['label'] ?? '').toString();
    final normalizedSchemaLabel = normalizeOcrCompareKey(schemaLabel);
    final normalizedSchemaKey = normalizeOcrCompareKey(schemaKey);

    if (normalizedSchemaLabel == normalizedOcrKey) return f;
    if (normalizedSchemaKey.startsWith('${normalizedOcrKey}_')) return f;
    if (normalizedSchemaKey.contains(normalizedOcrKey)) return f;
  }

  return null;
}

/// Anzeige-Label für einen OCR-Key (Schema-Label oder der Key selbst).
String labelForOcrKey(List<Map<String, dynamic>> schema, String ocrKey) {
  final field = findSchemaFieldForOcrKey(schema, ocrKey);
  final label = field?['label']?.toString();
  if (label != null && label.isNotEmpty) return label;
  return ocrKey;
}

/// Ein OCR-Treffer, der auf ein Schema-Feld gemappt wurde.
class OcrMatchedField {
  /// Tatsächlicher Schema-Key (kann UUID-Suffix haben).
  final String schemaKey;

  /// Feldtyp laut Schema (`string`, `int`, …).
  final String type;

  /// Roher OCR-Text.
  final String ocrValue;

  /// Wert für `_params` (bei int ggf. als Zahl).
  final dynamic paramValue;

  /// Text für den [TextEditingController].
  final String displayValue;

  const OcrMatchedField({
    required this.schemaKey,
    required this.type,
    required this.ocrValue,
    required this.paramValue,
    required this.displayValue,
  });
}

/// Mappt OCR-Ergebnisse auf Schema-Felder und bereitet Param-/Controller-Werte vor.
List<OcrMatchedField> matchOcrResultsToSchema({
  required Map<String, String> ocrResults,
  required List<Map<String, dynamic>> schema,
}) {
  final matched = <OcrMatchedField>[];

  ocrResults.forEach((ocrKey, ocrValue) {
    final fieldDef = findSchemaFieldForOcrKey(schema, ocrKey);
    if (fieldDef == null || fieldDef.isEmpty) return;

    final realKey = fieldDef['key']?.toString();
    if (realKey == null || realKey.isEmpty) return;

    final type = (fieldDef['type'] ?? 'string').toString();
    dynamic paramValue = ocrValue;
    var displayValue = ocrValue;

    if (type == 'int') {
      final num = int.tryParse(ocrValue) ?? double.tryParse(ocrValue)?.toInt();
      if (num != null) {
        paramValue = num;
        displayValue = num.toString();
      }
    }

    matched.add(
      OcrMatchedField(
        schemaKey: realKey,
        type: type,
        ocrValue: ocrValue,
        paramValue: paramValue,
        displayValue: displayValue,
      ),
    );
  });

  return matched;
}

/// Markiert alle gematchten OCR-Felder als „nicht fehlend“ und „validiert“.
Anlage markOcrFieldsValidated(Anlage anlage, Iterable<String> schemaKeys) {
  var updated = anlage;
  for (final key in schemaKeys) {
    updated = AnlageValidationService.setFieldAsMissing(updated, key, false);
    updated = AnlageValidationService.setFieldValidated(updated, key, true);
  }
  return updated;
}
