/// Konfiguration einer Hierarchie-Ebene beim CSV-Import.
///
/// Jede Ebene kann ein-/ausgeschaltet werden. Aktive Ebenen bilden eine Kette:
/// oberste Ebene → … → unterste aktive Ebene (= Blatt, eine Zeile pro Datensatz).
class HierarchyLevelConfig {
  final bool enabled;
  final int nameColumn;
  final bool useIdColumn;
  final int? idColumn;

  const HierarchyLevelConfig({
    this.enabled = false,
    this.nameColumn = 0,
    this.useIdColumn = false,
    this.idColumn,
  });

  HierarchyLevelConfig copyWith({
    bool? enabled,
    int? nameColumn,
    bool? useIdColumn,
    int? idColumn,
    bool clearIdColumn = false,
  }) {
    return HierarchyLevelConfig(
      enabled: enabled ?? this.enabled,
      nameColumn: nameColumn ?? this.nameColumn,
      useIdColumn: useIdColumn ?? this.useIdColumn,
      idColumn: clearIdColumn ? null : (idColumn ?? this.idColumn),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'nameColumn': nameColumn,
        'useIdColumn': useIdColumn,
        'idColumn': idColumn,
      };

  factory HierarchyLevelConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const HierarchyLevelConfig();
    }
    return HierarchyLevelConfig(
      enabled: json['enabled'] as bool? ?? false,
      nameColumn: json['nameColumn'] as int? ?? 0,
      useIdColumn: json['useIdColumn'] as bool? ?? false,
      idColumn: json['idColumn'] as int?,
    );
  }
}
