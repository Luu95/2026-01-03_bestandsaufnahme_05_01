/// Typisiertes Schema-Feld (statt loser `Map<String, dynamic>`).
///
/// Bestehender Code nutzt noch Maps; [SchemaField.fromMap] / [toMap] erlauben
/// schrittweise Migration ohne Big-Bang.

/// Ein Eingabefeld im Disziplin-/Anlagen-Schema.
class SchemaField {
  /// Stabiler Param-Key (meist Feldname aus der CSV-Namenszelle).
  final String key;

  /// Anzeige-Label im Dialog.
  final String label;

  /// Feldtyp: `text`, `number`, `date`, `multiline`, `dropdown`, …
  final String type;

  /// True bei globalen Feldern (nicht ATT-gebunden).
  final bool isGlobal;

  /// Zugeordneter ATT-Slot (1 = ATT1); null bei Legacy ohne Slot.
  final int? attSlot;

  /// Optionale Dialog-Gruppe aus Gewerke-`ART` (nicht der Eingabewert).
  final String? art;

  /// Dropdown-Optionen (leer bei Freitext/Number).
  final List<String> options;

  const SchemaField({
    required this.key,
    required this.label,
    this.type = 'text',
    this.isGlobal = false,
    this.attSlot,
    this.art,
    this.options = const [],
  });

  /// Baut ein [SchemaField] aus der legacy Map-Darstellung.
  factory SchemaField.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    final options = rawOptions is List
        ? rawOptions.map((e) => e.toString()).toList()
        : const <String>[];
    final slotRaw = map['attSlot'];
    int? attSlot;
    if (slotRaw is int) {
      attSlot = slotRaw;
    } else if (slotRaw != null) {
      attSlot = int.tryParse(slotRaw.toString());
    }
    return SchemaField(
      key: (map['key'] ?? '').toString(),
      label: (map['label'] ?? map['key'] ?? '').toString(),
      type: (map['type'] ?? 'text').toString(),
      isGlobal: map['isGlobal'] == true,
      attSlot: attSlot,
      art: map['art']?.toString(),
      options: options,
    );
  }

  /// Map-Darstellung für bestehenden Dialog-/Persistenz-Code.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'key': key,
      'label': label,
      'type': type,
      if (isGlobal) 'isGlobal': true,
      if (attSlot != null) 'attSlot': attSlot,
      if (art != null && art!.isNotEmpty) 'art': art,
      if (options.isNotEmpty) 'options': options,
    };
    return map;
  }

  /// Konvertiert eine Liste von Maps in typisierte Felder.
  static List<SchemaField> listFromMaps(List<Map<String, dynamic>> maps) =>
      maps.map(SchemaField.fromMap).toList();

  /// Konvertiert typisierte Felder zurück in Maps.
  static List<Map<String, dynamic>> listToMaps(List<SchemaField> fields) =>
      fields.map((f) => f.toMap()).toList();
}
