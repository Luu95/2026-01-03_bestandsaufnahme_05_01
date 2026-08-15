/// Schema-Felder aus einer Anlagen-/Gewerke-CSV-Zeile ableiten.
///
/// - Pair-Format: ATT + ATT_WERT → immer `type: text` (Anlagen)
/// - Triplet Anlagen: ATT + TYPE + WERT → kein Schema-`art` (WERT = Eingabe)
/// - Triplet Gewerke: ATT + TYPE + ART → `art` = Dialog-Gruppe
/// - Genutzt von CsvService (Anlagen) und TemplateService (Vorlagen)

import 'package:bestandsaufnahme_01/features/csv/models/attribute_column_pair.dart';
import 'package:bestandsaufnahme_01/features/csv/models/attribute_triplet_column.dart';
import 'package:bestandsaufnahme_01/features/csv/models/schema_field.dart';
import 'package:bestandsaufnahme_01/features/csv/csv_settings.dart';
import 'package:bestandsaufnahme_01/features/csv/utils/csv_utils.dart';

/// Schema aus Name-Zellen des Paar-Formats (auch ohne Wert).
List<Map<String, dynamic>> schemaFieldsFromAnlagenPairRow({
  required List<dynamic> row,
  required List<AttributeColumnPair> pairs,
}) {
  final fields = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (var i = 0; i < pairs.length; i++) {
    final pair = pairs[i];
    if (pair.nameColumn < 0) continue;
    final nameCell = CsvUtils.safeCellTrimmed(row, pair.nameColumn);
    if (nameCell.isEmpty || CsvSettings.isAnlagenCsvColumnParamKey(nameCell)) {
      continue;
    }
    if (seen.contains(nameCell.toLowerCase())) continue;
    seen.add(nameCell.toLowerCase());
    fields.add(
      SchemaField(
        key: nameCell,
        label: CsvSettings.normalizeFieldLabelForDisplay(nameCell),
        type: 'text',
        attSlot: CsvSettings.attSlotForPair(pair, i),
      ).toMap(),
    );
  }
  return fields;
}

/// Schema aus Triplet-Zeile: Name (+ TYPE), auch wenn ART/WERT leer ist.
///
/// Für **Anlagen-CSV**: dritte Spalte ist Feldwert → kein Schema-`art`.
List<Map<String, dynamic>> schemaFieldsFromAnlagenTripletRow({
  required List<dynamic> row,
  required List<String> headerRow,
  required List<AttributeTripletColumn> triplets,
}) {
  final fields = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (var i = 0; i < triplets.length; i++) {
    final triplet = triplets[i];
    if (triplet.nameColumn < 0) continue;
    final nameCell = CsvUtils.safeCellTrimmed(row, triplet.nameColumn);
    if (nameCell.isEmpty || CsvSettings.isAnlagenCsvColumnParamKey(nameCell)) {
      continue;
    }
    if (CsvSettings.looksLikeTypeOrOptionsDefinition(nameCell)) {
      continue;
    }
    final nameHeader =
        triplet.nameColumn < headerRow.length ? headerRow[triplet.nameColumn] : '';
    final attSlot =
        CsvSettings.attNumberFromHeaderLabel(nameHeader) ?? (i + 1);

    var typeStr = '';
    if (triplet.typeColumn >= 0) {
      typeStr = CsvUtils.safeCellTrimmed(row, triplet.typeColumn);
    }
    final entry = CsvSettings.schemaFieldFromGewerkeTypeCell(
      nameCell,
      typeStr,
    );
    entry['attSlot'] = attSlot;
    // Anlagen: ART/WERT-Zelle = Nutzerwert, nicht Gruppen-Metadatum.
    entry.remove('art');
    final key = (entry['key'] ?? '').toString();
    if (key.isEmpty || seen.contains(key.toLowerCase())) continue;
    seen.add(key.toLowerCase());
    fields.add(entry);
  }
  return fields;
}

/// Schema aus **Gewerkevorlagen**-Triplet: Name + TYPE + ART (Gruppe).
///
/// Dritte Spalte (`ATT*_ART`) ist die Dialog-Gruppierung, kein Eingabewert.
List<Map<String, dynamic>> schemaFieldsFromGewerkeTripletRow({
  required List<dynamic> row,
  required List<String> headerRow,
  required List<AttributeTripletColumn> triplets,
}) {
  final fields = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (var i = 0; i < triplets.length; i++) {
    final triplet = triplets[i];
    if (triplet.nameColumn < 0) continue;
    final nameCell = CsvUtils.safeCellTrimmed(row, triplet.nameColumn);
    if (nameCell.isEmpty || CsvSettings.isAnlagenCsvColumnParamKey(nameCell)) {
      continue;
    }
    if (CsvSettings.looksLikeTypeOrOptionsDefinition(nameCell)) {
      continue;
    }
    final nameHeader =
        triplet.nameColumn < headerRow.length ? headerRow[triplet.nameColumn] : '';
    final attSlot =
        CsvSettings.attNumberFromHeaderLabel(nameHeader) ?? (i + 1);

    var typeStr = '';
    if (triplet.typeColumn >= 0) {
      typeStr = CsvUtils.safeCellTrimmed(row, triplet.typeColumn);
    }
    var artStr = '';
    if (triplet.artColumn >= 0) {
      artStr = CsvUtils.safeCellTrimmed(row, triplet.artColumn);
    }
    // OPTIONS-Legacy falls vorhanden
    String? legacyOptions;
    if (triplet.optionsColumn >= 0) {
      legacyOptions = CsvUtils.safeCellTrimmed(row, triplet.optionsColumn);
      if (legacyOptions.isEmpty) legacyOptions = null;
    }

    final entry = CsvSettings.schemaFieldFromGewerkeTypeCell(
      nameCell,
      typeStr,
      artStr: artStr,
      legacyOptionsStr: legacyOptions,
    );
    entry['attSlot'] = attSlot;
    final key = (entry['key'] ?? '').toString();
    if (key.isEmpty || seen.contains(key.toLowerCase())) continue;
    seen.add(key.toLowerCase());
    fields.add(entry);
  }
  return fields;
}
