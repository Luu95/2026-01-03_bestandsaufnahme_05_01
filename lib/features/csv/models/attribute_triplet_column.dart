/// AttributeTripletColumn beschreibt nur die Spaltenstruktur einer CSV: welche Spalten-Indizes gehören zu einem Attribut.

import 'package:bestandsaufnahme_01/features/csv/models/attribute_column_pair.dart';

/// Eine Attribut-Spaltengruppe (Pair oder Triplet).
class AttributeTripletColumn {
  /// 0-basierter Index der Namensspalte (z. B. ATT3).
  final int nameColumn;

  /// Typ-Spalte (ATT3_TYPE); `-1` = Pair-Dialekt ohne Typ-Spalte.
  final int typeColumn;

  /// Legacy-OPTIONS-Spalte; `-1`, wenn nicht vorhanden.
  final int optionsColumn;

  /// Wert-/Art-Spalte (ATT*_WERT bei Anlagen, ATT*_ART bei Gewerken).
  final int artColumn;

  /// Feste ATT-Nummer (1 = ATT1); nur bei Pair→Triplet-Normalisierung gesetzt.
  final int? attNumber;

  const AttributeTripletColumn({
    required this.nameColumn,
    required this.typeColumn,
    this.optionsColumn = -1,
    required this.artColumn,
    this.attNumber,
  });

  /// True, wenn nur Name+Wert (keine TYPE-Spalte).
  bool get isPairDialect => typeColumn < 0;

  /// Pair → kanonische Triplet-Form (`typeColumn: -1`).
  factory AttributeTripletColumn.fromPair(AttributeColumnPair pair) {
    return AttributeTripletColumn(
      nameColumn: pair.nameColumn,
      typeColumn: -1,
      artColumn: pair.valueColumn,
      attNumber: pair.attNumber,
    );
  }

  /// Zurück zu Pair (nur sinnvoll bei [isPairDialect]).
  AttributeColumnPair toPair() => AttributeColumnPair(
        nameColumn: nameColumn,
        valueColumn: artColumn,
        attNumber: attNumber,
      );

  /// Serialisierung für Persistenz in [CsvSettings].
  Map<String, dynamic> toJson() => {
        'nameColumn': nameColumn,
        'typeColumn': typeColumn,
        if (optionsColumn >= 0) 'optionsColumn': optionsColumn,
        'artColumn': artColumn,
        if (attNumber != null) 'attNumber': attNumber,
      };

  /// Deserialisierung; fehlende [artColumn] wird aus TYPE/OPTIONS abgeleitet.
  factory AttributeTripletColumn.fromJson(Map<String, dynamic> json) {
    final name = json['nameColumn'] as int? ?? 0;
    final type = json['typeColumn'] as int? ?? 0;
    final options = json['optionsColumn'] as int? ?? -1;
    // Ältere Speicherung ohne artColumn: Wertspalte lag hinter OPTIONS bzw. TYPE.
    final art = json['artColumn'] as int? ??
        (type < 0
            ? (json['valueColumn'] as int? ?? -1)
            : (options >= 0 ? options + 1 : type + 1));
    return AttributeTripletColumn(
      nameColumn: name,
      typeColumn: type,
      optionsColumn: options,
      artColumn: art,
      attNumber: json['attNumber'] as int?,
    );
  }

  /// Spaltenindizes dieser Gruppe (ohne ungenutzte Legacy-/Pair-Spalten).
  List<int> get columnIndices {
    final cols = <int>[nameColumn];
    if (typeColumn >= 0) cols.add(typeColumn);
    if (optionsColumn >= 0 && optionsColumn != typeColumn) {
      cols.add(optionsColumn);
    }
    if (artColumn >= 0) cols.add(artColumn);
    return cols;
  }

  /// Wert-Spalte für Anlagen-Export (Art/WERT).
  int get valueColumn => artColumn;
}
