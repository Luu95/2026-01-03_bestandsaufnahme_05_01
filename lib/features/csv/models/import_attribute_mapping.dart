/// Ergebnis der Header-Analyse: Zweier- oder Dreier-Mapping.
///
/// - [pairs] = Anlagen-Format (Name + Wert)
/// - [triplets] = Gewerke-Format (Name + Typ + Wert/Art)
/// - [CsvSettings.resolveImportAttributeMapping] wählt genau einen Dialekt

import 'package:bestandsaufnahme_01/features/csv/models/attribute_column_pair.dart';
import 'package:bestandsaufnahme_01/features/csv/models/attribute_triplet_column.dart';

/// Ergebnis der Header-Analyse: Zweier- oder Dreier-Mapping für einen Import.
class ImportAttributeMapping {
  /// Erkannte bzw. konfigurierte Name/Wert-Paare (Anlagen-Dialekt).
  final List<AttributeColumnPair> pairs;

  /// Erkannte bzw. konfigurierte Dreiergruppen (Gewerke-Dialekt).
  final List<AttributeTripletColumn> triplets;

  const ImportAttributeMapping({
    this.pairs = const [],
    this.triplets = const [],
  });

  /// True, wenn weder Paare noch Triplets gesetzt sind.
  bool get isEmpty => pairs.isEmpty && triplets.isEmpty;

  /// True, wenn der Pair-Dialekt aktiv ist (Vorrang vor Triplets).
  bool get isPair => pairs.isNotEmpty;

  /// True, wenn nur der Triplet-Dialekt aktiv ist.
  bool get isTriplet => triplets.isNotEmpty && pairs.isEmpty;
}
