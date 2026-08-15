/// Ergebnis der Header-Analyse: kanonisch immer Triplets + Dialekt.
///
/// Pair-Dialekt wird als Triplets mit `typeColumn: -1` gespeichert;
/// [pairs] ist nur noch eine abgeleitete Sicht für ältere Aufrufer.

import 'package:bestandsaufnahme_01/features/csv/models/attribute_column_pair.dart';
import 'package:bestandsaufnahme_01/features/csv/models/attribute_triplet_column.dart';

/// Dialekt der Attribut-Spalten.
enum AttributeDialect {
  /// Anlagen: Name + Wert (ATT / ATT_WERT).
  anlagenPair,

  /// Gewerke: Name + Typ + Wert/Art.
  gewerkeTriplet,
}

/// Ergebnis der Header-Analyse für einen Import.
class ImportAttributeMapping {
  /// Kanonische Attributgruppen (Pair-Dialekt: typeColumn = -1).
  final List<AttributeTripletColumn> triplets;

  /// Erkannter bzw. konfigurierter Dialekt.
  final AttributeDialect dialect;

  const ImportAttributeMapping({
    this.triplets = const [],
    this.dialect = AttributeDialect.gewerkeTriplet,
  });

  /// Pair-Liste aus Pair-Dialekt-Triplets (Kompatibilität).
  factory ImportAttributeMapping.fromPairs(List<AttributeColumnPair> pairs) {
    return ImportAttributeMapping(
      triplets: pairs.map(AttributeTripletColumn.fromPair).toList(),
      dialect: AttributeDialect.anlagenPair,
    );
  }

  /// Echte Gewerke-Triplets.
  factory ImportAttributeMapping.fromTriplets(
    List<AttributeTripletColumn> triplets,
  ) {
    return ImportAttributeMapping(
      triplets: triplets,
      dialect: AttributeDialect.gewerkeTriplet,
    );
  }

  /// True, wenn keine Gruppen gesetzt sind.
  bool get isEmpty => triplets.isEmpty;

  /// True, wenn Pair-Dialekt aktiv.
  bool get isPair =>
      dialect == AttributeDialect.anlagenPair && triplets.isNotEmpty;

  /// True, wenn Triplet-Dialekt aktiv.
  bool get isTriplet =>
      dialect == AttributeDialect.gewerkeTriplet && triplets.isNotEmpty;

  /// Abgeleitete Paare (leer bei Triplet-Dialekt).
  List<AttributeColumnPair> get pairs => isPair
      ? triplets.map((t) => t.toPair()).toList(growable: false)
      : const [];
}
