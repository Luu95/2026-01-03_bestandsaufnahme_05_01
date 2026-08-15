// Reine Draft-Operationen auf [CsvSettings] (kein Flutter-State).
// Eine Quelle der Wahrheit für Mapping-Änderungen der CSV-Settings-Page.

import 'package:bestandsaufnahme_01/features/csv/models/csv_hierarchy_level.dart';
import 'package:bestandsaufnahme_01/features/csv/providers/csv_settings_provider.dart';

/// Hilfsfunktionen: Header-Sync, Attribut-Range, Konflikte, Labels.
abstract final class CsvSettingsDraftOps {
  /// Übernimmt Header-Labels der Hierarchie-Spalten als Grouping-Keys.
  static CsvSettings withGroupingKeysFromHeaders(CsvSettings settings) {
    final headers = settings.importHeaderRow;
    if (headers.isEmpty) return settings;

    String? labelAt(int col) {
      if (col < 0 || col >= headers.length) return null;
      final label = headers[col].trim();
      return label.isEmpty ? null : label;
    }

    var next = settings;
    if (settings.level1.enabled) {
      final label = labelAt(settings.level1.nameColumn);
      if (label != null) {
        next = next.copyWith(groupingGewerkParamKey: label);
      }
    }
    if (settings.level2.enabled) {
      final label = labelAt(settings.level2.nameColumn);
      if (label != null) {
        next = next.copyWith(groupingAnlageParamKey: label);
      }
    }
    return next;
  }

  /// Erkennt ATT-Paare/Triplets aus dem Import-Header, sofern keine manuelle Range.
  static CsvSettings withAttributeMappingFromHeaders(CsvSettings settings) {
    final headers = settings.importHeaderRow;
    if (headers.isEmpty || settings.hasManualAttributeRange) return settings;

    if (CsvSettings.headerLooksLikeAnlagenWertFormat(headers)) {
      final pairs = CsvSettings.detectAnlagenAttributePairsFromHeader(headers);
      if (pairs.isEmpty) return settings;
      final asTriplets =
          pairs.map(AttributeTripletColumn.fromPair).toList(growable: false);
      if (_tripletsMatch(settings.canonicalAttributeTriplets, asTriplets)) {
        return settings;
      }
      return settings.copyWith(
        attributeColumnPairs: const [],
        attributeTripletColumns: asTriplets,
      );
    }

    if (CsvSettings.headerLooksLikeGewerkeTripletFormat(headers)) {
      final triplets = CsvSettings.detectTripletsFromHeader(headers);
      if (triplets.isEmpty) return settings;
      if (CsvSettings.tripletsMatchHeader(
        settings.attributeTripletColumns,
        headers,
      )) {
        return settings;
      }
      return settings.copyWith(
        attributeColumnPairs: const [],
        attributeTripletColumns: triplets,
      );
    }

    return settings;
  }

  /// Nach Laden: Grouping + ggf. Header-Attribut-Mapping anwenden.
  static CsvSettings normalizeAfterLoad(CsvSettings settings) {
    var next = withGroupingKeysFromHeaders(settings);
    if (!next.hasManualAttributeRange) {
      next = withAttributeMappingFromHeaders(next);
    }
    return next;
  }

  /// Manuelle Attribut-Range (1-basierte Spalten, inklusiv).
  /// Wirft [ArgumentError] bei ungültigem Bereich.
  static CsvSettings applyManualAttributeRange(
    CsvSettings settings, {
    required int firstColumn1Based,
    required int lastColumn1Based,
  }) {
    final groups = CsvSettings.tripletsFromInclusiveRange1Based(
      firstColumn1Based: firstColumn1Based,
      lastColumn1Based: lastColumn1Based,
    );
    final count = groups.length;
    return settings.copyWith(
      attributeStartColumn: firstColumn1Based - 1,
      attributeCount: count,
      attributeTripletColumns: groups,
      attributeColumnPairs: const [],
    );
  }

  /// Entfernt manuelle Range; Header-Erkennung greift beim nächsten Normalize.
  static CsvSettings clearManualAttributeRange(CsvSettings settings) {
    return settings.copyWith(
      clearAttributeRange: true,
      attributeTripletColumns: const [],
    );
  }

  /// Speichern: Disziplin-Gruppierung = Ebene 1 aktiv.
  static CsvSettings prepareForSave(CsvSettings settings) {
    return withGroupingKeysFromHeaders(settings).copyWith(
      useDisciplineGrouping: settings.level1.enabled,
    );
  }

  static bool _tripletsMatch(
    List<AttributeTripletColumn> current,
    List<AttributeTripletColumn> detected,
  ) {
    if (detected.length != current.length) return false;
    for (var i = 0; i < current.length; i++) {
      if (current[i].nameColumn != detected[i].nameColumn ||
          current[i].typeColumn != detected[i].typeColumn ||
          current[i].artColumn != detected[i].artColumn) {
        return false;
      }
    }
    return true;
  }

  static int countEnabledLevels(CsvSettings s) {
    var n = 0;
    if (s.level1.enabled) n++;
    if (s.level2.enabled) n++;
    if (s.level3.enabled) n++;
    return n;
  }

  static String hierarchySubtitle(CsvSettings s) {
    final parts = <String>[];
    if (s.level1.enabled) parts.add(s.labelGewerk);
    if (s.level2.enabled) parts.add(s.labelAnlage);
    if (s.level3.enabled) parts.add(s.labelBauteil);
    if (parts.isEmpty) return 'Keine Ebene aktiv';
    return parts.join(' → ');
  }

  /// Anzeige-Label der Schema-Item-Ebene (meist Ebene 2).
  static String schemaItemLevelLabel(CsvSettings s) {
    if (s.level2.enabled && countEnabledLevels(s) >= 2) return s.labelAnlage;
    if (s.level3.enabled) return s.labelBauteil;
    return s.labelAnlage;
  }

  /// Belegte Mapping-Spalten der Hierarchie.
  static List<int> mappingColumnIndices(
    CsvSettings s, {
    int? excludeLevelNum,
  }) {
    final used = <int>[];
    void addLevel(int levelNum, HierarchyLevelConfig level) {
      if (!level.enabled || excludeLevelNum == levelNum) return;
      used.add(level.nameColumn);
      if (level.useIdColumn && level.idColumn != null) {
        used.add(level.idColumn!);
      }
    }

    addLevel(1, s.level1);
    addLevel(2, s.level2);
    addLevel(3, s.level3);
    return used;
  }

  static int nextFreeIndex(Iterable<int> values) {
    final used = values.toSet();
    var candidate = 0;
    while (used.contains(candidate)) {
      candidate++;
    }
    return candidate;
  }

  static int pickFreeMappingColumn(
    CsvSettings s,
    int preferred, {
    int? excludeLevelNum,
  }) {
    final used =
        mappingColumnIndices(s, excludeLevelNum: excludeLevelNum).toSet();
    if (!used.contains(preferred)) return preferred;
    return nextFreeIndex(used);
  }

  /// Konflikte: doppelte Hierarchie-/Attribut-Spalten.
  static List<String> columnConflictMessages(CsvSettings s) {
    final conflicts = <String>[];
    final mappingByCol = <int, List<String>>{};

    void mapCol(int col, String label) {
      mappingByCol.putIfAbsent(col, () => []).add(label);
    }

    if (s.level1.enabled) {
      mapCol(s.level1.nameColumn, 'Ebene 1 (${s.labelGewerk}) Name');
      if (s.level1.useIdColumn && s.level1.idColumn != null) {
        mapCol(s.level1.idColumn!, 'Ebene 1 ID');
      }
    }
    if (s.level2.enabled) {
      mapCol(s.level2.nameColumn, 'Ebene 2 (${s.labelAnlage}) Name');
      if (s.level2.useIdColumn && s.level2.idColumn != null) {
        mapCol(s.level2.idColumn!, 'Ebene 2 ID');
      }
    }
    if (s.level3.enabled) {
      mapCol(s.level3.nameColumn, 'Ebene 3 (${s.labelBauteil}) Name');
      if (s.level3.useIdColumn && s.level3.idColumn != null) {
        mapCol(s.level3.idColumn!, 'Ebene 3 ID');
      }
    }

    for (final e in mappingByCol.entries) {
      if (e.value.length > 1) {
        conflicts.add('Spalte ${e.key + 1}: ${e.value.join(', ')}');
      }
    }

    for (var i = 0; i < s.attributeTripletColumns.length; i++) {
      final g = s.attributeTripletColumns[i];
      final groupLabel = 'Attribut ${i + 1}';
      final cols = g.columnIndices;
      if (cols.toSet().length != cols.length) {
        conflicts
            .add('$groupLabel: Spalten innerhalb der Gruppe doppelt vergeben');
      }
      for (final col in cols) {
        for (final e in mappingByCol.entries) {
          if (e.key == col) {
            conflicts.add(
              'Spalte ${e.key + 1}: ${e.value.join(', ')} und $groupLabel',
            );
          }
        }
      }
    }

    return conflicts;
  }
}
