/// ATT-Slot-Metadaten und Schema-`art`-Gruppe für Dialog/Export.
///
/// Kein Migrate/Repair: frischer CSV-Import schreibt Schema-Keys + Slots bereits
/// in [CsvService]. Hier nur fehlende Slots nachziehen und art als UI-Gruppe lesen.

part of '../csv_settings.dart';

/// Hilfen für ATT-Zuordnung und Schema-art-Gruppen (kein Legacy-Repair).
class AnlageAttSlots {
  /// art nur als echte Gruppen-Kategorie – nicht Label/Typ-Definition.
  static String? effectiveSchemaArtGroup(Map<String, dynamic> fieldDef) {
    final art = CsvSettings.normalizeFieldLabelForDisplay(
      (fieldDef['art'] ?? '').toString(),
    );
    if (art.isEmpty) return null;
    final label = CsvSettings.normalizeFieldLabelForDisplay(
      (fieldDef['label'] ?? fieldDef['key'] ?? '').toString(),
    );
    if (label.isNotEmpty && CsvSettings.paramKeysMatch(art, label)) return null;
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
  static void writeFromSchemaFields(
    Map<String, dynamic> params,
    List<Map<String, dynamic>> schemaFields,
  ) {
    for (final field in schemaFields) {
      if (field['isGlobal'] == true) continue;
      final key = (field['key'] ?? '').toString().trim();
      if (key.isEmpty || CsvSettings.isAnlagenCsvColumnParamKey(key)) continue;
      final slot = CsvSettings.attSlotFromSchemaField(field);
      if (slot == null || slot <= 0) continue;
      CsvSettings.writeAttSlotForParam(params, key, slot);
    }
  }

  /// Ergänzt fehlende ATT-Slots aus Import-Header (kanonisch über Triplets).
  static void writeFromImportHeader({
    required Map<String, dynamic> params,
    required List<String> importHeaders,
    required List<Map<String, dynamic>> schemaFields,
  }) {
    if (importHeaders.isEmpty || schemaFields.isEmpty) return;
    final nonGlobal =
        schemaFields.where((f) => f['isGlobal'] != true).toList();

    final mapping = CsvSettings.resolveImportAttributeMapping(
      headerRow: importHeaders,
      settings: CsvSettings.defaults().copyWith(importHeaderRow: importHeaders),
    );
    final groups = mapping.triplets.isNotEmpty
        ? mapping.triplets
        : CsvSettings.detectAnlagenAttributePairsFromHeader(importHeaders)
            .map(AttributeTripletColumn.fromPair)
            .toList();

    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      final nameCol = g.nameColumn;
      final slot = g.attNumber ??
          ((nameCol >= 0 && nameCol < importHeaders.length)
              ? (CsvSettings.attNumberFromHeaderLabel(importHeaders[nameCol]) ??
                  (i + 1))
              : (i + 1));
      final field = CsvSettings.schemaFieldAtAttSlot(slot, nonGlobal);
      final key = (field?['key'] ?? '').toString().trim();
      if (key.isEmpty) continue;
      if (CsvSettings.attSlotForParam(params, key) == null) {
        CsvSettings.writeAttSlotForParam(params, key, slot);
      }
    }
  }

  /// Stellt sicher, dass ATT-Slots für Dialog/Export gesetzt sind.
  static void ensureForDialog({
    required Map<String, dynamic> params,
    required List<Map<String, dynamic>> schemaFields,
    List<String> importHeaders = const [],
  }) {
    writeFromSchemaFields(params, schemaFields);
    if (importHeaders.isNotEmpty) {
      writeFromImportHeader(
        params: params,
        importHeaders: importHeaders,
        schemaFields: schemaFields,
      );
    }
  }
}
