// lib/providers/csv_settings_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ein explizites Paar: eine Spalte für den Attributnamen, eine für den Attributwert.
/// Beim Import wird pro Zeile gelesen: params[wert(nameSpalte)] = wert(valueSpalte).
class AttributeColumnPair {
  final int nameColumn;
  final int valueColumn;

  const AttributeColumnPair({
    required this.nameColumn,
    required this.valueColumn,
  });

  Map<String, dynamic> toJson() => {
        'nameColumn': nameColumn,
        'valueColumn': valueColumn,
      };

  factory AttributeColumnPair.fromJson(Map<String, dynamic> json) {
    return AttributeColumnPair(
      nameColumn: json['nameColumn'] as int? ?? 0,
      valueColumn: json['valueColumn'] as int? ?? 0,
    );
  }
}

class CsvSettings {
  final int lfdNummerSpalte;
  final int nameSpalte;
  final int gewerkSpalte;
  final int? etageSpalte;
  final int? anlageBauteilSpalte;
  final String delimiterMode;
  final String anlageKuerzel;
  final String bauteilKuerzel;
  final bool useDisciplineGrouping;
  final String labelGewerk;
  final String labelAnlage;
  final String labelBauteil;
  final List<AttributeColumnPair> attributeColumnPairs;
  /// Spalten-Labels für Fotonummern beim Export (1–4). Leer = Spalte nicht verwendet.
  final String? foto1SpalteLabel;
  final String? foto2SpalteLabel;
  final String? foto3SpalteLabel;
  final String? foto4SpalteLabel;
  /// Beim Anlagen-Import aus CSV gespeicherte Header-Zeile; für Export „wie Import“.
  final List<String> importHeaderRow;
  /// Beim Export verwendeter Delimiter (z. B. ';' oder ','). Wird beim Import aus erkanntem Delimiter gesetzt.
  final String exportDelimiter;

  const CsvSettings({
    required this.lfdNummerSpalte,
    required this.nameSpalte,
    required this.gewerkSpalte,
    this.etageSpalte,
    this.anlageBauteilSpalte,
    required this.delimiterMode,
    required this.anlageKuerzel,
    required this.bauteilKuerzel,
    required this.useDisciplineGrouping,
    required this.labelGewerk,
    required this.labelAnlage,
    required this.labelBauteil,
    this.attributeColumnPairs = const [],
    this.foto1SpalteLabel,
    this.foto2SpalteLabel,
    this.foto3SpalteLabel,
    this.foto4SpalteLabel,
    this.importHeaderRow = const [],
    this.exportDelimiter = ';',
  });

  factory CsvSettings.defaults() {
    return const CsvSettings(
      lfdNummerSpalte: 0,
      nameSpalte: 1,
      gewerkSpalte: 2,
      etageSpalte: null,
      anlageBauteilSpalte: null,
      delimiterMode: 'auto',
      anlageKuerzel: 'A,Anlage',
      bauteilKuerzel: 'B,Bauteil',
      useDisciplineGrouping: true,
      labelGewerk: 'Gewerk',
      labelAnlage: 'Anlage',
      labelBauteil: 'Bauteil',
      attributeColumnPairs: [],
      foto1SpalteLabel: null,
      foto2SpalteLabel: null,
      foto3SpalteLabel: null,
      foto4SpalteLabel: null,
      importHeaderRow: const [],
      exportDelimiter: ';',
    );
  }

  CsvSettings copyWith({
    int? lfdNummerSpalte,
    int? nameSpalte,
    int? gewerkSpalte,
    int? etageSpalte,
    int? anlageBauteilSpalte,
    String? delimiterMode,
    String? anlageKuerzel,
    String? bauteilKuerzel,
    bool? useDisciplineGrouping,
    String? labelGewerk,
    String? labelAnlage,
    String? labelBauteil,
    List<AttributeColumnPair>? attributeColumnPairs,
    String? foto1SpalteLabel,
    String? foto2SpalteLabel,
    String? foto3SpalteLabel,
    String? foto4SpalteLabel,
    List<String>? importHeaderRow,
    String? exportDelimiter,
  }) {
    return CsvSettings(
      lfdNummerSpalte: lfdNummerSpalte ?? this.lfdNummerSpalte,
      nameSpalte: nameSpalte ?? this.nameSpalte,
      gewerkSpalte: gewerkSpalte ?? this.gewerkSpalte,
      etageSpalte: etageSpalte ?? this.etageSpalte,
      anlageBauteilSpalte: anlageBauteilSpalte ?? this.anlageBauteilSpalte,
      delimiterMode: delimiterMode ?? this.delimiterMode,
      anlageKuerzel: anlageKuerzel ?? this.anlageKuerzel,
      bauteilKuerzel: bauteilKuerzel ?? this.bauteilKuerzel,
      useDisciplineGrouping: useDisciplineGrouping ?? this.useDisciplineGrouping,
      labelGewerk: labelGewerk ?? this.labelGewerk,
      labelAnlage: labelAnlage ?? this.labelAnlage,
      labelBauteil: labelBauteil ?? this.labelBauteil,
      attributeColumnPairs: attributeColumnPairs ?? this.attributeColumnPairs,
      foto1SpalteLabel: foto1SpalteLabel ?? this.foto1SpalteLabel,
      foto2SpalteLabel: foto2SpalteLabel ?? this.foto2SpalteLabel,
      foto3SpalteLabel: foto3SpalteLabel ?? this.foto3SpalteLabel,
      foto4SpalteLabel: foto4SpalteLabel ?? this.foto4SpalteLabel,
      importHeaderRow: importHeaderRow ?? this.importHeaderRow,
      exportDelimiter: exportDelimiter ?? this.exportDelimiter,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lfdNummerSpalte': lfdNummerSpalte,
      'nameSpalte': nameSpalte,
      'gewerkSpalte': gewerkSpalte,
      'etageSpalte': etageSpalte,
      'anlageBauteilSpalte': anlageBauteilSpalte,
      'delimiterMode': delimiterMode,
      'anlageKuerzel': anlageKuerzel,
      'bauteilKuerzel': bauteilKuerzel,
      'useDisciplineGrouping': useDisciplineGrouping,
      'labelGewerk': labelGewerk,
      'labelAnlage': labelAnlage,
      'labelBauteil': labelBauteil,
      'attributeColumnPairs': attributeColumnPairs.map((p) => p.toJson()).toList(),
      'foto1SpalteLabel': foto1SpalteLabel,
      'foto2SpalteLabel': foto2SpalteLabel,
      'foto3SpalteLabel': foto3SpalteLabel,
      'foto4SpalteLabel': foto4SpalteLabel,
      'importHeaderRow': importHeaderRow,
      'exportDelimiter': exportDelimiter,
    };
  }

  factory CsvSettings.fromJson(Map<String, dynamic> json) {
    final pairsRaw = json['attributeColumnPairs'];
    final List<AttributeColumnPair> pairs = [];
    if (pairsRaw is List) {
      for (final e in pairsRaw) {
        if (e is Map<String, dynamic>) {
          pairs.add(AttributeColumnPair.fromJson(e));
        } else if (e is Map) {
          pairs.add(AttributeColumnPair.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return CsvSettings(
      lfdNummerSpalte: json['lfdNummerSpalte'] as int? ?? 0,
      nameSpalte: json['nameSpalte'] as int? ?? 1,
      gewerkSpalte: json['gewerkSpalte'] as int? ?? 2,
      etageSpalte: json['etageSpalte'] as int?,
      anlageBauteilSpalte: json['anlageBauteilSpalte'] as int?,
      delimiterMode: json['delimiterMode'] as String? ?? 'auto',
      anlageKuerzel: json['anlageKuerzel'] as String? ?? 'A,Anlage',
      bauteilKuerzel: json['bauteilKuerzel'] as String? ?? 'B,Bauteil',
      useDisciplineGrouping: json['useDisciplineGrouping'] as bool? ?? true,
      labelGewerk: json['labelGewerk'] as String? ?? 'Gewerk',
      labelAnlage: json['labelAnlage'] as String? ?? 'Anlage',
      labelBauteil: json['labelBauteil'] as String? ?? 'Bauteil',
      attributeColumnPairs: pairs,
      foto1SpalteLabel: json['foto1SpalteLabel'] as String?,
      foto2SpalteLabel: json['foto2SpalteLabel'] as String?,
      foto3SpalteLabel: json['foto3SpalteLabel'] as String?,
      foto4SpalteLabel: json['foto4SpalteLabel'] as String?,
      importHeaderRow: _parseStringList(json['importHeaderRow']),
      exportDelimiter: json['exportDelimiter'] as String? ?? ';',
    );
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e.toString()).toList();
  }
}

class CsvSettingsCache {
  static final Map<String, CsvSettings> _cache = {};

  static CsvSettings? get(String projectId) => _cache[projectId];

  static void set(String projectId, CsvSettings settings) {
    _cache[projectId] = settings;
  }
}

class CsvSettingsNotifier extends StateNotifier<CsvSettings> {
  final String projectId;

  CsvSettingsNotifier(this.projectId) : super(CsvSettings.defaults());

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'csv_settings_$projectId';
      final settingsJson = prefs.getString(key);
      if (settingsJson != null) {
        final decoded = json.decode(settingsJson) as Map<String, dynamic>;
        state = CsvSettings.fromJson(decoded);
        CsvSettingsCache.set(projectId, state);
        return;
      }
    } catch (_) {}
    CsvSettingsCache.set(projectId, state);
  }

  Future<void> save(CsvSettings settings) async {
    state = settings;
    CsvSettingsCache.set(projectId, state);
    final prefs = await SharedPreferences.getInstance();
    final key = 'csv_settings_$projectId';
    await prefs.setString(key, json.encode(settings.toJson()));
  }
}

final csvSettingsProvider =
    StateNotifierProviderFamily<CsvSettingsNotifier, CsvSettings, String>(
  (ref, projectId) => CsvSettingsNotifier(projectId),
);




