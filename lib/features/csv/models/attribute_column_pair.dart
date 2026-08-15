/// CSV-Spaltenpaar: Attributname + Attributwert (Anlagen-Zweierformat).

/// Ein explizites Paar: eine Spalte für den Attributnamen, eine für den Attributwert.
class AttributeColumnPair {
  /// 0-basierter Index der Namensspalte (z. B. ATT7).
  final int nameColumn;

  /// 0-basierter Index der Wertspalte (z. B. ATT7_WERT).
  final int valueColumn;

  /// Feste ATT-Nummer (1 = ATT1, 2 = ATT2, …), aus CSV-Header erkannt.
  final int? attNumber;

  const AttributeColumnPair({
    required this.nameColumn,
    required this.valueColumn,
    this.attNumber,
  });

  /// Serialisierung für Persistenz in [CsvSettings].
  Map<String, dynamic> toJson() => {
        'nameColumn': nameColumn,
        'valueColumn': valueColumn,
        if (attNumber != null) 'attNumber': attNumber,
      };

  /// Deserialisierung aus gespeichertem JSON.
  factory AttributeColumnPair.fromJson(Map<String, dynamic> json) {
    return AttributeColumnPair(
      nameColumn: json['nameColumn'] as int? ?? 0,
      valueColumn: json['valueColumn'] as int? ?? 0,
      attNumber: json['attNumber'] as int?,
    );
  }
}
