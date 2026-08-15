/// CSV-Dreiergruppe: Name, Typ, Wert/Art (optional Legacy-OPTIONS).

/// Dreiergruppe pro Attribut: Name, Typ (Freitext/number/Opt1|Opt2), Wert/Art.
/// [optionsColumn] nur für Legacy-CSV mit separater OPTIONS-Spalte, sonst -1.
class AttributeTripletColumn {
  /// 0-basierter Index der Namensspalte (z. B. ATT3).
  final int nameColumn;

  /// 0-basierter Index der Typ-Spalte (z. B. ATT3_TYPE).
  final int typeColumn;

  /// Legacy-OPTIONS-Spalte; `-1`, wenn nicht vorhanden.
  final int optionsColumn;

  /// Wert-/Art-Spalte (ATT*_WERT bei Anlagen, ATT*_ART bei Gewerken).
  final int artColumn;

  const AttributeTripletColumn({
    required this.nameColumn,
    required this.typeColumn,
    this.optionsColumn = -1,
    required this.artColumn,
  });

  /// Serialisierung für Persistenz in [CsvSettings].
  Map<String, dynamic> toJson() => {
        'nameColumn': nameColumn,
        'typeColumn': typeColumn,
        if (optionsColumn >= 0) 'optionsColumn': optionsColumn,
        'artColumn': artColumn,
      };

  /// Deserialisierung; fehlende [artColumn] wird aus TYPE/OPTIONS abgeleitet.
  factory AttributeTripletColumn.fromJson(Map<String, dynamic> json) {
    final name = json['nameColumn'] as int? ?? 0;
    final type = json['typeColumn'] as int? ?? 0;
    final options = json['optionsColumn'] as int? ?? -1;
    // Ältere Speicherung ohne artColumn: Wertspalte lag hinter OPTIONS bzw. TYPE.
    final art = json['artColumn'] as int? ??
        (options >= 0 ? options + 1 : type + 1);
    return AttributeTripletColumn(
      nameColumn: name,
      typeColumn: type,
      optionsColumn: options,
      artColumn: art,
    );
  }

  /// Spaltenindizes dieser Gruppe (ohne ungenutzte Legacy-Spalten).
  List<int> get columnIndices {
    final cols = <int>[nameColumn, typeColumn];
    if (optionsColumn >= 0 && optionsColumn != typeColumn) {
      cols.add(optionsColumn);
    }
    if (artColumn >= 0) cols.add(artColumn);
    return cols;
  }

  /// Wert-Spalte für Anlagen-Export (Art/WERT).
  int get valueColumn => artColumn;
}
